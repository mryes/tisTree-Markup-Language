import os, osproc, xmltree, htmlparser, sequtils, streams, strutils, 
       strtabs, algorithm, parseutils, times, tables


 
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

proc toUpper(xml: PXmlNode): PXmlNode =
  if xml.kind != xnElement: return xml 
  var attrs = newStringTable()
  if xml.attrsLen > 0:
    for k in xml.attrs.keys:
      attrs[k.toUpper] = xml.attrs[k]
  result = newXmlTree(xml.tag.toUpper, [], attrs)
  for i in xml.items:
    result.add(i.toUpper)



proc isPositioned(tag: PXmlNode): bool =
  tag.attrExists("x") or tag.attrExists("y")

proc makeDivFromTag(tag: PXmlNode): PXmlNode =
  ## Construct a div to style a tag.
  ## Returns an empty tag if there are no styles to apply.
  var style = ""
  if tag.isPositioned():
    const positionStyleTemplate = "position:absolute;left:$1;top:$2;" 
    var (x, y) = (tag.attr("x"), tag.attr("y"))
    if x == "": x = "0"
    if y == "": y = "0"
    style.add(positionStyleTemplate % [x, y])
  if tag.attrExists("style"):
    style.add(tag.attr("style"))
  if style == "": return newElement("")
  result = newElement("div")
  result.attrs = newStringTable({"style": style})

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

proc getGifTransformationAttrs*(tag: PXmlNode): TTable[string, string] =
  const transformationAttrs = ["scale", "prescale", "flip", "rotate", 
                               "hue", "saturation", "brightness",
                               "delay"]
  result = initTable[string, string]() 
  for k, v in tag.attrs.pairs:
    if k in transformationAttrs: result[k] = v 

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
  for a in getGifTransformationAttrs(gifTag).pairs:
    result.add("-" & a.key & a.val.cleanPercents)
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
  let tDiv = makeDivFromTag(tag)
  if tDiv.tag != "": result.wrapInTag(tDiv)

proc convertTagDlg*(tag: PXmlNode): PXmlNode {.procvar.} =
  if tag.innerText == "": return newText("")
  let centeredTR = [<>center(), <>td(), <>tr()]
  let children = tag.children
  let content = if tag.attrExists("font"): 
                  multiWrap(setFont(tag.attr("font"), children), centeredTR)
                else: multiWrap(children, centeredTR)
  result = makeTable(content, width=tag.attr("w"))
  let tDiv = makeDivFromTag(tag)
  if tDiv.tag != "": result.wrapInTag(tDiv)

proc convertTagPos*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeDivFromTag(tag)
  if result.tag == "": return newText("")
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
  ## Create the ImageMagick commands to generate gif transformations.
  ## (Note: currently relies on the order the attributes end up taking
  ## inside string tables. By chance this is a good order, for now.)
  proc fileNewerThan(f1, f2: string): bool =
    f1.getLastModificationTime() > f2.getLastModificationTime()
  let filename = makeGifFilename(gifTag)
  let filenameNoTrs = gifTag.attr("name") & ".gif"
  if existsFile(filename) and fileNewerThan(filename, filenameNoTrs): return ""
  let trsAttrs = getGifTransformationAttrs(gifTag)
  var trsArgs = " -filter point -background \"rgba(0,0,0,0)\""
  if trsAttrs.hasKey("prescale"):
    trsArgs.add(" -resize " & trsAttrs["prescale"] & " +repage")
  for a in trsAttrs.pairs:
    case a.key
    of "scale": 
      trsArgs.add(" -resize " & a.val & " +repage")
    of "flip":
      if 'x' in a.val: trsArgs.add(" -flop")
      if 'y' in a.val: trsArgs.add(" -flip")
    of "rotate":
      trsArgs.add(" -rotate " & a.val)
    of "hue", "saturation", "brightness":
      trsArgs.add(" -colorspace HSL -modulate ")
      trsArgs.add(if a.key == "brightness": a.val else: "100")
      trsArgs.add("," & (if a.key == "saturation": a.val else: "100"))
      trsArgs.add("," & (if a.key == "hue": a.val else: "100"))
      trsArgs = trsArgs.replace("%", "")
    of "delay":
      trsArgs.add(" -set delay " & a.val) 
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



proc compileTml(source: string): string =
  let tmlInput = parseHtml(source)
  let (htmlOutput, gifsToTransform) = tmlToHtml(tmlInput)
  transformGifs(gifsToTransform)
  deleteUnusedGeneratedGifs(gifsToTransform)
  result = $htmlOutput.toUpper
