import os, xmltree, htmlparser, sequtils, streams, strutils, strtabs, algorithm, parseutils



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
  const transformationAttrs = ["scale", "crop"]
  result = @[] 
  for k, v in tag.attrs.pairs:
    if k in transformationAttrs: result.add((k, v)) 

proc makeGifFilename*(gifTag: PXmlNode): string = 
  proc stripPercent(s: string): string = 
    s.split("%")[0]
  result = ""
  result.add(gifTag.attr("name"))
  for a in getGifTransformationAttrs(gifTag):
    result.add("-" & a.key & a.value.stripPercent)
  result.add(".gif")

proc generateTransformedGif(gifTag: PXmlNode): void =
  let filename = makeGifFilename(gifTag)
  if existsFile(fileName): return
  let attrs = getGifTransformationAttrs(gifTag)
  var transArgs = "" 
  for a in attrs:
    case a.key
    of "scale": 
      transArgs.add(" -filter point -resize " & a.value)
    of "crop":
      transArgs.add(" -crop " & a.value & " +repage")
  let command = "convert $1 $2 $3" % [gifTag.attr("name") & ".gif", transArgs, filename]
  echo command
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



when isMainModule:
  let gifTag1 = <>gif(name="compuser", crop="100x100+0+0", scale="200%")  
  let gifTag2 = <>gif(name="compuser", crop="100x100+0+0")  
  let gifTag3 = <>gif(name="compuser", scale="200%")  
  generateTransformedGif(gifTag1)
  generateTransformedGif(gifTag2)
  generateTransformedGif(gifTag3)