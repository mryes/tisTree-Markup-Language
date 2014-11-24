import xmltree, htmlparser, sequtils, strutils, strtabs

const DIV_STYLE_DEFAULT = "position:absolute;left:$1;top:$2"

proc attrExists(xmlNode: PXmlNode, attribute: string): bool =
  return xmlNode.attr(attribute) != ""

proc makeDivFromLocation(x: string, y: string): PXmlNode =
  let x = if x != "": x else: "0"
  let y = if y != "": y else: "0"
  var tDiv = newElement("div")
  tDiv.attrs = newStringTable({"style": DIV_STYLE_DEFAULT % [x, y]}, modeCaseInsensitive)
  result = tDiv 

proc wrapInTag(child, father: PXmlNode): PXmlNode = 
  ## This is the reverse of xmltree.add, which for some reason does not work
  result = newXmlTree(father.tag, [child], father.attrs)

proc convertTagGif*(tag: PXmlNode): PXmlNode =
  if tag.attrsLen == 0:
    result = <>img()
  else:
    result = (<>img(src=tag.attr("name") & ".gif")) 
  if tag.attrExists("x") or tag.attrExists("y"):
    result = result.wrapInTag(makeDivFromLocation(tag.attr("x"), tag.attr("y")))
