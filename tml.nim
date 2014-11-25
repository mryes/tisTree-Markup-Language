import os, xmltree, htmlparser, sequtils, streams, strutils, 
       strtabs, algorithm, parseutils, times



const DIV_STYLE_DEFAULT = "position:absolute;left:$1;top:$2;"

proc parseHtml*(s: string): PXmlNode =
  parseHtml(newStringStream(s))

proc attrExists(xmlNode: PXmlNode, attribute: string): bool =
  xmlNode.attr(attribute) != ""

proc makeDivFromLocation(x: string, y: string): PXmlNode =
  let x = if x != "": x else: "0"
  let y = if y != "": y else: "0"
  var tDiv = newElement("div")
  tDiv.attrs = newStringTable({"style": DIV_STYLE_DEFAULT % [x, y]})
  result = tDiv 

proc wrapInTag(child: var PXmlNode, father: PXmlNode): void = 
  ## This is the reverse of xmltree.add, which for some reason does not work in
  ## a certain context.
  child = newXmlTree(father.tag, [child], father.attrs)

proc multiWrap(child: PXmlNode, tags: varargs[PXmlNode]): PXmlNode =
  var varChild = child
  for t in tags:
    varChild.wrapInTag(t)
  result = varChild

proc isPositioned(tag: PXmlNode): bool =
  tag.attrExists("x") or tag.attrExists("y")

proc setFont(tag: PXmlNode): PXmlNode =
  if not tag.attrExists("font"): return newText(tag.innerText)
  let fontAttr = tag.attr("font").split(' ')
  var font = newElement("font")
  font.attrs = newStringTable()
  font.attrs["face"] = fontAttr[0]
  if fontAttr.len > 1: font.attrs["size"] = fontAttr[1]
  font.add(newText(tag.innerText))
  result = font

proc makeTable(content: PXmlNode,
               border: string = "0",
               cellpadding: string = "2",
               bgcolor: string = "white",
               width: string = "300px"): PXmlNode =
  <>table(border=border, cellpadding=cellpadding, 
          bgcolor=bgcolor, width=width, content)

proc getGifTransformationAttrs*(tag: PXmlNode): seq[tuple[key, value: string]] =
  const transformationAttrs = ["scale", "crop", "flip"]
  result = @[] 
  for k, v in tag.attrs.pairs:
    if k in transformationAttrs: result.add((k, v)) 

proc makeGifFilename*(gifTag: PXmlNode): string = 
  proc cleanPercents(s: string): string = 
    result = ""
    for c in s:
      if c != '%': result.add(c)
      else: result.add("pct")
  result = ""
  result.add(gifTag.attr("name"))
  for a in getGifTransformationAttrs(gifTag):
    result.add("-" & a.key & a.value.cleanPercents)
  result.add(".gif")

proc generateTransformedGif(gifTag: PXmlNode): void =
  proc hasOffset(geomString: string): bool =
    geomString.count({'+', '-'}) > 0
  proc fileNewerThan(f1, f2: string): bool =
    f1.getLastModificationTime() > f2.getLastModificationTime()
  let filename = makeGifFilename(gifTag)
  let filenameNoTrs = gifTag.attr("name") & ".gif"
  if existsFile(filename) and fileNewerThan(filename, filenameNoTrs):
    return
  let trsAttrs = getGifTransformationAttrs(gifTag)
  var trsArgs = "" 
  for a in trsAttrs:
    case a.key
    of "scale": 
      trsArgs.add(" -filter point -resize " & a.value)
    of "crop":
      let cropValue = if not a.value.hasOffset(): a.value & "+0+0" else: a.value
      trsArgs.add(" -crop " & cropValue & " +repage")
    of "flip":
      if 'x' in a.value: trsArgs.add(" -flop")
      if 'y' in a.value: trsArgs.add(" -flip")
  let command = "convert $1 $2 $3" % [filenameNoTrs, trsArgs, filename]
  discard execShellCmd(command)



proc convertTagGif*(tag: PXmlNode): PXmlNode {.procvar.} =
  if tag.attrsLen == 0: return <>img()
  result = <>img(src=makeGifFilename(tag))
  if tag.isPositioned(): 
    result.wrapInTag(makeDivFromLocation(tag.attr("x"), tag.attr("y")))

proc convertTagDlg*(tag: PXmlNode): PXmlNode {.procvar.} =
  if tag.innerText == "": return newText("")
  let centeredTR = [<>center(), <>td(), <>tr()]
  result = makeTable(multiWrap(setFont(tag), centeredTR))
  if tag.isPositioned(): 
    result.wrapInTag(makeDivFromLocation(tag.attr("x"), tag.attr("y")))

proc dummyConvert(tag: PXmlNode): PXmlNode {.procvar.} = tag

const CONVERSION_FUNCTIONS = {
  "gif": convertTagGif,
  "dlg": convertTagDlg
}  

proc conversionFunction(tag: string): proc(tag: PXmlNode): PXmlNode =
  for c in CONVERSION_FUNCTIONS:
    if c[0] == tag: return c[1] 
  return dummyConvert

proc tmlToHtml(tmlHead: PXmlNode): PXmlNode =
  proc buildHtmlTree(tmlTree: PXmlNode): PXmlNode =
    if tmlTree.kind != xnElement: return tmlTree
    result = newXmlTree(tmlTree.tag, [], tmlTree.attrs)
    for i in tmlTree.items:
      result.add(buildHtmlTree(i))
    result = conversionFunction(result.tag)(result)
  # Ignore root tag and go straight to its children.
  # (This means you can use a <tml> tag instead of an <html> tag)
  result = newElement("html")
  for i in tmlHead.items:
    result.add(buildHtmlTree(i))



when isMainModule:
  let tmlInput = parseHtml(readFile(paramStr(1)))
  writeFile(paramStr(1) & ".result", $tmlToHtml(tmlInput))