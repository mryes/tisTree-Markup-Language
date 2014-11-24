import os, xmltree, htmlparser, sequtils, streams, strutils, strtabs


const DIV_STYLE_DEFAULT = "position:absolute;left:$1;top:$2;"


proc parseHtml*(s: string): PXmlNode =
  parseHtml(newStringStream(s))

proc attrExists(xmlNode: PXmlNode, attribute: string): bool =
  return xmlNode.attr(attribute) != ""

proc makeDivFromLocation(x: string, y: string): PXmlNode =
  let x = if x != "": x else: "0"
  let y = if y != "": y else: "0"
  var tDiv = newElement("div")
  tDiv.attrs = newStringTable({"style": DIV_STYLE_DEFAULT % [x, y]}, modeCaseInsensitive)
  result = tDiv 

proc wrapInTag(child, father: PXmlNode): PXmlNode = 
  ## This is the reverse of xmltree.add, which for some reason does not work in
  ## a certain context.
  result = newXmlTree(father.tag, [child], father.attrs)

proc convertTagGif*(tag: PXmlNode): PXmlNode =
  if tag.attrsLen == 0:
    result = <>img()
  else:
    result = (<>img(src=tag.attr("name") & ".gif")) 
  if tag.attrExists("x") or tag.attrExists("y"):
    result = result.wrapInTag(makeDivFromLocation(tag.attr("x"), tag.attr("y")))

proc convertTagDlg*(tag: PXmlNode): PXmlNode =
  if tag.innerText == "":
    result = newText("")
  else:
    let tableRow = parseHtml("""
      <tr><td>
      <center>$1</center>
      </td></tr>""".unindent % [tag.innerText])
    var table = newElement("table")
    table.attrs = newStringTable({"border": "0", "cellpadding": "2", 
                                  "bgcolor": "white", "width": "300px"})
    table.add(tableRow)
    if tag.attrExists("x") or tag.attrExists("y"):
      table = table.wrapInTag(makeDivFromLocation(tag.attr("x"), tag.attr("y")))
    result = table


when isMainModule:
  # let fileName = paramStr(1)
  # let parsedHtml = loadHtml(fileName)
  