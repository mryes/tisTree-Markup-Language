import os, xmltree, htmlparser, sequtils, streams, strutils, strtabs, algorithm

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
  <>font(face=tag.attr("font"), newText(tag.innerText)) 

proc makeTable(content: PXmlNode,
               border: string = "0",
               cellpadding: string = "2",
               bgcolor: string = "white",
               width: string = "300px"): PXmlNode =
  <>table(border=border, cellpadding=cellpadding, 
          bgcolor=bgcolor, width=width, content)



proc convertTagGif*(tag: PXmlNode): PXmlNode {.procvar.} =
  if tag.attrsLen == 0:
    result = <>img()
  else:
    result = (<>img(src=tag.attr("name") & ".gif")) 
  if tag.isPositioned(): 
    result.wrapInTag(makeDivFromLocation(tag.attr("x"), tag.attr("y")))

proc convertTagDlg*(tag: PXmlNode): PXmlNode {.procvar.} =
  if tag.innerText == "":
    result = newText("")
  else:
    let centeredTR = [<>center(), <>td(), <>tr()]
    var tableContent : PXmlNode
    if tag.attrExists("font"):
      tableContent = multiWrap(setFont(tag), centeredTR)
    else: 
      tableContent = multiWrap(newText(tag.innerText), centeredTR) 
    var table = makeTable(tableContent)
    if tag.isPositioned(): 
      table.wrapInTag(makeDivFromLocation(tag.attr("x"), tag.attr("y")))
    result = table



when isMainModule:
  # let fileName = paramStr(1)
  # let parsedHtml = loadHtml(fileName)
  