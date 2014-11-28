import unittest, xmltree, strutils, sequtils, strtabs, tml



proc testTmlConversion(tml, html: string; conversion: proc(tag: PXmlNode): PXmlNode): bool = 
  ## Converts string inputs to XML nodes, performs tML-to-HTML, then compares the
  ## inputs as strings again to see if it worked. (Converting the html to an XML node   
  ## is necessary because identical nodes will produce identical string output.) 
  proc withoutNewlines(str: string): string =
    var newStr: string = ""
    for c in str:
      if c notin NewLines: newStr.add(c)
    newStr
  let tmlConverted = parseHtml(tml).conversion()
  let htmlNode = parseHtml(html)
  echo tmlConverted
  echo htmlNode
  ($tmlConverted).withoutNewlines == ($htmlNode).withoutNewlines

template convTest(title: string; conversion: proc(tag: PXmlNode): PXmlNode; 
                  testml: string): expr =
  test title:
    let splitMls = split(testml.unindent(eatAllIndent=true), "\n\n")
    let (tml, html) = (splitMls[0], splitMls[1])
    check testTmlConversion(tml.strip, html.strip, conversion)



convTest "convert empty gif", convertTagGif,
  """
  <gif />

  <img />
  """

convTest "convert gif with name", convertTagGif,
  """
  <gif name="source" />

  <img src="source.gif" />
  """

convTest "convert gif with position", convertTagGif,
  """
  <gif name="source" x="10" y="20" />

  <div style="position:absolute;left:10;top:20;">
    <img src="source.gif" />
  </div>
  """

convTest "convert gif with position and style", convertTagGif,
  """
  <gif name="source" x="10" y="20" style="background-color:white" />

  <div style="position:absolute;left:10;top:20;background-color:white">
    <img src="source.gif" />
  </div>
  """

convTest "convert gif with style and no position", convertTagGif,
  """
  <gif name="source" style="background-color:white" />

  <div style="background-color:white">
    <img src="source.gif" />
  </div>
  """ 

convTest "convert gif with scale", convertTagGif,
  """
  <gif name="source" x="10" y="20" scale="2" />

  <div style="position:absolute;left:10;top:20;">
    <img src="generated/source-scale2.gif" />
  </div>
  """

convTest "convert gif with cropping (size only)", convertTagGif,
  """
  <gif name="source" crop="50 50" />

  <table width="50" height="50" background="source.gif" style="background-repeat:no-repeat;">
  <tr><td></td></tr>
  </table>
  """

convTest "convert gif with cropping (size and offset)", convertTagGif,
  """
  <gif name="source" crop="50 50 10px 10px" />

  <table width="50" height="50" background="source.gif" 
    style="background-repeat:no-repeat;background-position:-10px -10px">
  <tr><td></td></tr>
  </table>
  """

test "convert empty dlg to nothing":
  let dlgHtml = <>dlg(newText(""))
  check ($convertTagDlg(dlgHtml) == "")

convTest "convert dlg with text", convertTagDlg,
  """
  <dlg>Hello!</dlg>
  
  <table border="0" cellpadding="2" bgcolor="white" width="300px">
  <tr><td>
    <center>Hello!</center>
  </td></tr>
  </table>
  """

convTest "convert dlg with position", convertTagDlg,
  """
  <dlg x="100" y="200">Hello!</dlg>

  <div style="position:absolute;left:100;top:200;">
    <table border="0" cellpadding="2" bgcolor="white" width="300px">
    <tr><td>
      <center>Hello!</center>
    </td></tr>
    </table>
  </div> 
  """

convTest "convert dlg with font face", convertTagDlg,
  """
  <dlg font="arial">Hello!</dlg>

  <table border="0" cellpadding="2" bgcolor="white" width="300px">
  <tr><td>
    <center><font face="arial">Hello!</font></center>
  </td></tr></table>
  """

convTest "convert dlg with font face and size", convertTagDlg,
  """
  <dlg font="arial, 3px">Hello!</dlg>

  <table border="0" cellpadding="2" bgcolor="white" width="300px">
  <tr><td>
    <center><font face="arial" size="3px">Hello!</font></center>
  </td></tr></table>
  """

convTest "convert dlg with width", convertTagDlg,
  """
  <dlg w="500px">Hello!</dlg>

  <table border="0" cellpadding="2" bgcolor="white" width="500px">
  <tr><td>
    <center>Hello!</center>
  </td></tr></table>
  """ 

convTest "convert pos to div", convertTagPos,
  """
  <pos x="40" y="140">
    <p>Stuff</p>
    <p>Other stuff</p>
  </pos>

  <div style="position:absolute;left:40;top:140;">
    <p>Stuff</p>
    <p>Other stuff</p>
  </div>
  """

convTest "convert up-pointing isosceles triangle to table", convertTagItri,
  """
  <itri type="up" x="100" size="100" color="blue" />

  <div style="position:absolute;left:100;top:0;">
  <table 
    style="empty-cells:show;border-style:solid;border-color:transparent transparent blue transparent;" 
    bgcolor="transparent" border="100" cellpadding="0" cellspacing="0" height="0" width="0">
  <tbody><tr><td style="border-style:none;"></td></tr></tbody>
  </table>
  </div>
  """

convTest "convert right-pointing isosceles triangle to table", convertTagItri,
  """
  <itri type="right" x="100" size="100" color="blue" />

  <div style="position:absolute;left:100;top:0;">
  <table 
    style="empty-cells:show;border-style:solid;border-color:transparent transparent transparent blue;" 
    bgcolor="transparent" border="100" cellpadding="0" cellspacing="0" height="0" width="0">
  <tbody><tr><td style="border-style:none;"></td></tr></tbody>
  </table>
  </div>
  """

convTest "convert down-pointing right triangle to table", convertTagRtri,
  """
  <rtri type="up right" x="100" y="600" size="75" color="white" />

  <div style="position:absolute;left:100;top:600;">
  <table style="empty-cells:show;border-style:solid;border-color:white white transparent transparent;" 
    bgcolor="transparent" border="75" cellpadding="0" cellspacing="0" height="0" width="0">
  <tbody><tr><td style="border-style:none;"></td></tr></tbody>
  </table>
  </div> 
  """

test "make gif filename when gif has a transformation":
  let tag = <>gif(name="source", x="10", y="10", scale="2")
  check makeGifFilename(tag) == "generated/source-scale2.gif"
