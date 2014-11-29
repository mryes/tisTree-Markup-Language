import os, osproc, sequtils, streams, strutils, strtabs, algorithm, parseutils, 
       times, tables, future, lib.htmlparser, lib.xmltree


 
proc parseHtml*(s: string): PXmlNode =
  parseHtml(newStringStream(s))

proc attrExists(xmlNode: PXmlNode, attribute: string): bool =
  xmlNode.attr(attribute) != ""

proc attr(tag: PXmlNode, attribute: string, default=""): string =
  if tag.attrExists(attribute): xmltree.attr(tag, attribute) else: default

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
  let firstTag = children.wrapInTag(tags[0])
  result = multiWrap(firstTag, (@tags)[1..high(tags)])

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

proc wrapInDiv(tag: var PXmlNode, madeFrom: PXmlNode): void =
  let tDiv = makeDivFromTag(madeFrom)
  if tDiv.tag != "": tag.wrapInTag(tDiv) 

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
  result = ""
  if getGifTransformationAttrs(gifTag).len > 0:
    result.add(generatedGifFolder & DirSep)
  result.add(gifTag.attr("name"))
  for a in getGifTransformationAttrs(gifTag).pairs:
    result.add("-" & a.key & a.val.replace("%", "pct"))
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

const commonShapeTableStyle = "empty-cells:show;border-style:solid;"

proc makeColorStyleInstance(config, color: string): any =
  result = config.replace("tr", "transparent") % color

proc makeSimpleShapeTable(tag: PXmlNode, configurations): PXmlNode =
  ## Make an initial table for displaying shapes. 
  ## "configurations" maps type attributes to border-color attributes.
  proc makeShapeColorStyle(tag: PXmlNode, configurations): string = 
    let shapeType = tag.attr("type")
    if not configurations.hasKey(shapeType):
      configurations[shapeType] = "tr tr tr tr" 
    let shapeColor = tag.attr("color", default="white")
    let colorStyle = configurations[shapeType].makeColorStyleInstance(shapeColor)
    result = commonShapeTableStyle & "border-color:" & colorStyle & ";"
  <>table(<>tbody(<>tr(<>td(style="border-style:none;"))), 
          border=tag.attr("size", default="100"),
          style=makeShapeColorStyle(tag, configurations),
          bgcolor="transparent", cellpadding="0", cellspacing="0", 
          height="0", width="0")

proc makeComplexShapeTable(tag: PXmlNode, configurations): PXmlNode =
  var shapeType = tag.attr("type")
  if shapeType == "": shapeType = "none"
  if not configurations.hasKey(shapeType):
    configurations[shapeType] = "tr tr tr tr, tr tr tr tr"
  let shapeColor = tag.attr("color", default="white")
  let colorStyles = configurations[shapeType].makeColorStyleInstance(shapeColor).split(", ")
  let shapeSize = tag.attr("size", default="100") 
  let fullStyleTemplate = commonShapeTableStyle & "border-color:$1;border-width:$2;"
  let fullStyles = (fullStyleTemplate % [colorStyles[0], shapeSize], 
                    fullStyleTemplate % [colorStyles[1], shapeSize])  
  <>table(bgcolor="transparent", border="0", cellpadding="0", cellspacing="0",
          <>tbody(<>tr(<>td(style=fullStyles[0]), <>td(style=fullStyles[1]))))



proc convertTagGif*(tag: PXmlNode): PXmlNode {.procvar.} =
  if tag.attrsLen == 0: return <>img()
  if not tag.attrExists("crop"):
    result = <>img(src=makeGifFilename(tag))
  else: result = makeCropTable(tag)
  result.wrapInDiv(madeFrom=tag)

proc convertTagDlg*(tag: PXmlNode): PXmlNode {.procvar.} =
  if tag.innerText == "": return newText("")
  let centeredTR = [<>center(), <>td(), <>tr()]
  let children = tag.children
  let content = if tag.attrExists("font"): 
                  multiWrap(setFont(tag.attr("font"), children), centeredTR)
                else: multiWrap(children, centeredTR)
  result = <>table(content, border="0", cellpadding="2", bgcolor="white", 
                   width=tag.attr("w", default="300px"))
  result.wrapInDiv(madeFrom=tag)

proc convertTagPos*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeDivFromTag(tag)
  if result.tag == "": return newText("")
  for i in tag.items: result.add(i)

proc convertTagRect*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = <>table(<>tr(<>td()), border="0", 
                   bgcolor=tag.attr("color", default="white"),
                   width=tag.attr("w", default="0"),
                   height=tag.attr("h", default="0"))
  result.wrapInDiv(madeFrom=tag)

proc convertTagItri*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeSimpleShapeTable(tag, configurations=newTable({
    "up":    "tr tr $1 tr",
    "down":  "$1 tr tr tr",
    "left":  "tr $1 tr tr",
    "right": "tr tr tr $1"}))
  result.wrapInDiv(madeFrom=tag)

proc convertTagRtri*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeSimpleShapeTable(tag, configurations=newTable({
    "up left":    "$1 tr tr $1",
    "up right":   "$1 $1 tr tr",
    "down left":  "tr tr $1 $1",
    "down right": "tr $1 $1 tr"}))
  result.wrapInDiv(madeFrom=tag) 

proc convertTagTrap*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeSimpleShapeTable(tag, configurations=newTable({
    "up":    "tr tr $1 tr",
    "down":  "$1 tr tr tr",
    "left":  "tr $1 tr tr",
    "right": "tr tr tr $1"}))
  if tag.attr("type") in ["up", "down"]:
    result.attrs["width"]  = tag.attr("w")
    result.attrs["border"] = tag.attr("h")
  elif tag.attr("type") in ["left", "right"]: 
    result.attrs["border"] = tag.attr("w")
    result.attrs["height"] = tag.attr("h")
  result.wrapInDiv(madeFrom=tag)  

proc convertTagBowtie*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeSimpleShapeTable(tag, configurations=newTable({
    "vertical":   "$1 tr $1 tr",
    "horizontal": "tr $1 tr $1"}))
  result.wrapInDiv(madeFrom=tag)

proc convertTagPac*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeSimpleShapeTable(tag, configurations=newTable({
    "up":    "tr $1 $1 $1",
    "down":  "$1 $1 tr $1",
    "left":  "$1 $1 $1 tr",
    "right": "$1 tr $1 $1"}))
  result.wrapInDiv(madeFrom=tag)

proc convertTagPgm*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeComplexShapeTable(tag, configurations=newTable({
    "left":  ("$1 $1 tr tr, tr tr $1 $1"),
    "right": ("tr $1 $1 tr, $1 tr tr $1")}))
  result.wrapInDiv(madeFrom=tag)

proc convertTagRhom*(tag: PXmlNode): PXmlNode {.procvar.} =
  result = makeComplexShapeTable(tag, configurations=newTable({
    "none": ("tr $1 tr tr, tr tr tr $1")}))
  result.wrapInDiv(madeFrom=tag)

proc dummyConvert(tag: PXmlNode): PXmlNode {.procvar.} = tag

const conversionFunctions = {
  "gif":     convertTagGif,
  "dlg":     convertTagDlg,
  "pos":     convertTagPos,
  "rect":    convertTagRect,
  "itri":    convertTagItri,
  "rtri":    convertTagRtri,
  "trap":    convertTagTrap,
  "bowtie":  convertTagBowtie,
  "pac":     convertTagPac,
  "pgm":     convertTagPgm,
  "rhom":    convertTagRhom
}

proc conversionFunction(tag): (PXmlNode) -> PXmlNode =
  for c in conversionFunctions:
    if c[0] == tag: return c[1] 
  return dummyConvert

proc tmlToHtml(tml: string): tuple[html: string, gifsToTransform: seq[PXmlNode]] =
  let tmlHead = parseHtml(tml)
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
  result = ($html.toUpper, gifsToTransform)



proc generateGifTransformCommand(gifTag: PXmlNode, projPath: string): string =
  ## Create the ImageMagick commands to generate gif transformations.
  proc fileNewerThan(f1, f2: string): bool =
    f1.getLastModificationTime() > f2.getLastModificationTime()
  let filename = projPath / makeGifFilename(gifTag)
  let filenameNoTrs = projPath / gifTag.attr("name") & ".gif"
  if existsFile(filename) and fileNewerThan(filename, filenameNoTrs): 
    return ""
  let trsAttrs = getGifTransformationAttrs(gifTag)
  var trsArgs = " -filter point -background \"rgba(0,0,0,0)\" "
  if trsAttrs.hasKey("prescale"):
   trsArgs.add(" -resize " & trsAttrs["prescale"] & " +repage")
  if trsAttrs.hasKey("flip"):
    if 'x' in trsAttrs["flip"]: trsArgs.add(" -flop")
    if 'y' in trsAttrs["flip"]: trsArgs.add(" -flip") 
  if trsAttrs.hasKey("delay"):
    trsArgs.add(" -set delay " & trsAttrs["delay"])
  if trsAttrs.hasKey("rotate"):
    trsArgs.add(" -rotate " & trsAttrs["rotate"])
  trsArgs.add(" -modulate ")
  for k in ["brightness", "saturation", "hue"]:
    if trsAttrs.hasKey(k): trsArgs.add(trsAttrs[k]) else: trsArgs.add("100")
    if k != "hue": trsArgs.add(',')
  if trsAttrs.hasKey("scale"):
    trsArgs.add(" -resize " & trsAttrs["scale"] & " +repage")
  result = findExe("convert") & " $1 $2 $3" % [filenameNoTrs, trsArgs, filename]

proc transformAndOutputGifs(gifs: seq[PXmlNode], projPath: string): void =
  if not existsDir(projPath / generatedGifFolder): 
    createDir(projPath / generatedGifFolder)
  var trsCommands : seq[string] = @[]
  for g in gifs: 
    let command = g.generateGifTransformCommand(projPath)
    if command != "": 
      echo ("Generating " & (projPath / g.makeGifFilename()))
      trsCommands.add(command)
  discard execProcesses(trsCommands)

proc deleteUnusedGeneratedGifs(gifsUsed: seq[PXmlNode], projPath: string): void = 
  let usedGifFilenames = gifsUsed.mapIt(string, projPath / it.makeGifFilename())
  for f in walkFiles(projPath / generatedGifFolder & "/*.gif"):
    if f notin usedGifFilenames:
       removeFile(f)



proc compileTml*(source, projPath: string): string =
  let (htmlOutput, gifsToTransform) = tmlToHtml(source)
  result = htmlOutput
  transformAndOutputGifs(gifsToTransform, projPath)
  deleteUnusedGeneratedGifs(gifsToTransform, projPath)