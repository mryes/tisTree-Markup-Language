import os, osproc, xmltree, htmlparser, sequtils, streams, strutils, 
       strtabs, algorithm, parseutils, times


 
proc parseHtml*(s: string): PXmlNode =
  parseHtml(newStringStream(s))

proc attrExists(xmlNode: PXmlNode, attribute: string): bool =
  xmlNode.attr(attribute) != ""

proc children(xmlNode: PXmlNode): seq[PXmlNode] =
  ## Odd that xmltree doesn't already have this.
  result = @[]
  for i in xmlNode.items: result.add(i)

proc wrapInTag(child: var PXmlNode, father: PXmlNode): void = 
  ## This is the reverse of xmltree.add, which for some reason does not work in
  ## a certain context.
  child = newXmlTree(father.tag, [child], father.attrs)

proc wrapInTag(children: seq[PXmlNode], father: PXmlNode): PXmlNode =
  newXmlTree(father.tag, children, father.attrs)

proc multiWrap(child: PXmlNode, tags: varargs[PXmlNode]): PXmlNode =
  var varChild = child
  for t in tags:
    varChild.wrapInTag(t)
  result = varchild

proc multiWrap(children: seq[PXmlNode], tags: varargs[PXmlNode]): PXmlNode =
  let firstChild = children.wrapInTag(tags[0])
  result = multiWrap(firstChild, (@tags)[1..high(tags)])



proc isPositioned(tag: PXmlNode): bool =
  tag.attrExists("x") or tag.attrExists("y")

proc makeDivFromLocation(x: string, y: string): PXmlNode =
  const divStyleDefault = "position:absolute;left:$1;top:$2;"
  let x = if x != "": x else: "0"
  let y = if y != "": y else: "0"
  var tDiv = newElement("div")
  tDiv.attrs = newStringTable({"style": DIV_STYLE_DEFAULT % [x, y]})
  result = tDiv 

proc makeTable(content: PXmlNode, 
               border: string = "", cellpadding: string = "", 
               bgcolor: string = "", width: string = ""): PXmlNode =
  proc default(s, default: string): string =
    # This is here so you can pass in an empty string and it will
    # just ignore that parameter. Makes things simpler on the other end.
    if s == "": default else: s 
  <>table(border = border.default("0"),
          cellpadding = cellpadding.default("2"), 
          bgcolor = bgcolor.default("white"), 
          width = width.default("300px"), 
          content)

proc setFont(font: string, items: seq[PXmlNode]): PXmlNode =
  let fontAttr = font.split(',')
  var fontTag = newElement("font")
  fontTag.attrs = newStringTable()
  fontTag.attrs["face"] = fontAttr[0]
  if fontAttr.len > 1: fontTag.attrs["size"] = fontAttr[1].strip
  for i in items: fontTag.add(i)
  result = fontTag

proc getGifTransformationAttrs*(tag: PXmlNode): seq[tuple[key, value: string]] =
  const transformationAttrs = ["scale", "flip", "rotate", 
                               "hue", "saturation", "brightness",
                               "delay"]
  result = @[] 
  for k, v in tag.attrs.pairs:
    if k in transformationAttrs: result.add((k, v)) 

const generatedGifFolder = "generated"

proc makeGifFilename*(gifTag: PXmlNode): string = 
  proc cleanPercents(s: string): string = 
    result = ""
    for c in s:
      if c != '%': result.add(c)
      else: result.add("pct")
  result = ""
  if getGifTransformationAttrs(gifTag).len > 0:
    if not existsDir(generatedGifFolder): createDir(generatedGifFolder)
    result.add(generatedGifFolder & "/")
  result.add(gifTag.attr("name"))
  for a in getGifTransformationAttrs(gifTag):
    result.add("-" & a.key & a.value.cleanPercents)
  result.add(".gif")

proc makeCropTable(gifTag: PXmlNode): PXmlNode =
  proc getCropDimensions(crop: string): tuple[x, y, w, h: string] =
    var dimStrs = crop.split
    var elementsMissing = 4 - dimStrs.len
    while elementsMissing > 0:
      dimStrs.add("0")
      dec(elementsMissing)    
    result = (dimStrs[2], dimStrs[3], dimStrs[0], dimStrs[1])
    if result.x != "0": result.x = "-" & result.x 
    if result.y != "0": result.y = "-" & result.y 
  let dims = getCropDimensions(gifTag.attr("crop"))
  let positionStyle = if dims.x != "0" or dims.y != "0": 
                        "background-position:" & dims.x & " " & dims.y 
                      else: "" 
  result = <>table(width=dims.w, height=dims.h, background=makeGifFilename(gifTag),
                   style="background-repeat:no-repeat;" & positionStyle, 
                   <>tr(<>td())) 



proc convertTagGif*(tag: PXmlNode): PXmlNode {.procvar.} =
  if tag.attrsLen == 0: return <>img()
  if not tag.attrExists("crop"):
    result = <>img(src=makeGifFilename(tag))
  else: result = makeCropTable(tag)
  if tag.isPositioned(): 
    result.wrapInTag(makeDivFromLocation(tag.attr("x"), tag.attr("y")))

proc convertTagDlg*(tag: PXmlNode): PXmlNode {.procvar.} =
  if tag.innerText == "": return newText("")
  let centeredTR = [<>center(), <>td(), <>tr()]
  let children = tag.children
  let content = if tag.attrExists("font"): 
                  multiWrap(setFont(tag.attr("font"), children), centeredTR)
                else: multiWrap(children, centeredTR)
  result = makeTable(content, width=tag.attr("w"))
  if tag.isPositioned(): 
    result.wrapInTag(makeDivFromLocation(tag.attr("x"), tag.attr("y")))

proc convertTagPos*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeDivFromLocation(tag.attr("x"), tag.attr("y")) 
  for i in tag.items: result.add(i)

proc dummyConvert(tag: PXmlNode): PXmlNode {.procvar.} = tag

const CONVERSION_FUNCTIONS = {
  "gif": convertTagGif,
  "dlg": convertTagDlg,
  "pos": convertTagPos
}

proc conversionFunction(tag: string): proc(tag: PXmlNode): PXmlNode =
  for c in CONVERSION_FUNCTIONS:
    if c[0] == tag: return c[1] 
  return dummyConvert

proc tmlToHtml(tmlHead: PXmlNode): tuple[html: PXmlNode, gifsToTransform: seq[PXmlNode]] =
  echo "Translating..."
  var gifsToTransform: seq[PXmlNode] = @[]
  proc buildHtmlTree(tmlTree: PXmlNode): PXmlNode =
    if tmlTree.kind != xnElement: return tmlTree
    result = newXmlTree(tmlTree.tag, [], tmlTree.attrs)
    for i in tmlTree.items:
      result.add(buildHtmlTree(i))
    result = conversionFunction(result.tag)(result)
    if tmlTree.tag == "gif" and tmlTree.getGifTransformationAttrs.len > 0:
      gifsToTransform.add(tmlTree)
  # Ignore root tag and go straight to its children.
  # (This means you can use a <tml> tag instead of an <html> tag)
  var html = newElement("html")
  for i in tmlHead.items:
    html.add(buildHtmlTree(i))
  result = (html, gifsToTransform)



proc generateGifTransformCommand(gifTag: PXmlNode): string =
  proc hasOffset(geomString: string): bool =
    geomString.count({'+', '-'}) > 0
  proc fileNewerThan(f1, f2: string): bool =
    f1.getLastModificationTime() > f2.getLastModificationTime()
  let filename = makeGifFilename(gifTag)
  let filenameNoTrs = gifTag.attr("name") & ".gif"
  if existsFile(filename) and fileNewerThan(filename, filenameNoTrs): return ""
  let trsAttrs = getGifTransformationAttrs(gifTag)
  var trsArgs = " -filter point -background \"rgba(0,0,0,0)\""
  for a in trsAttrs:
    case a.key
    of "scale": 
      trsArgs.add(" -resize " & a.value & " +repage")
    of "flip":
      if 'x' in a.value: trsArgs.add(" -flop")
      if 'y' in a.value: trsArgs.add(" -flip")
    of "rotate":
      trsArgs.add(" -rotate " & a.value)
    of "hue", "saturation", "brightness":
      trsArgs.add(" -colorspace HSL -modulate ")
      trsArgs.add(if a.key == "brightness": a.value else: "100")
      trsArgs.add("," & (if a.key == "saturation": a.value else: "100"))
      trsArgs.add("," & (if a.key == "hue": a.value else: "100"))
      trsArgs = trsArgs.replace("%", "")
    of "delay":
      trsArgs.add(" -set delay " & a.value) 
  result = "convert $1 $2 $3" % [filenameNoTrs, trsArgs, filename]

proc transformGifs(gifs: seq[PXmlNode]): void =
  var trsCommands : seq[string] = @[]
  for g in gifs: 
    let command = g.generateGifTransformCommand()
    if command != "": 
      echo "Generating " & g.makeGifFilename()
      trsCommands.add(command)
  discard execProcesses(trsCommands)

proc deleteUnusedGeneratedGifs(gifsUsed: seq[PXmlNode]): void = 
  let usedGifFilenames = gifsUsed.mapIt(string, it.makeGifFilename())
  for f in walkFiles(generatedGifFolder & "/*.gif"):
    if f notin usedGifFilenames:
       removeFile(f)



when isMainModule:
  let filename = paramStr(1)
  let tmlInput = parseHtml(readFile(filename))
  let (htmlOutput, gifsToTransform) = tmlToHtml(tmlInput)
  transformGifs(gifsToTransform)
  deleteUnusedGeneratedGifs(gifsToTransform)
  let fileExtension = filename.splitFile.ext
  let outputFilename = if fileExtension == ".html": filename & ".result" 
                       else: filename.split('.')[0] & ".html" 
  writeFile(outputFilename, $htmlOutput)
  echo "Done!"