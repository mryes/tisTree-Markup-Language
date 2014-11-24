import unittest, xmltree, strutils, sequtils, strtabs, tml


proc htmlEqual(a, b: string): bool = 
  proc withoutNewlines(str: string): string =
    var newStr: string = ""
    for c in str:
      if c notin NewLines: newStr.add(c)
    result = newStr
  result = a.withoutNewlines == b.withoutNewlines


test "convert empty gif to empty img":
  let gifHtml = <>gif()
  let imgHtml = "<img />" 
  check htmlEqual($convertTagGif(gifHtml), imgHtml) 

test "convert gif with source to equivalent img":
  let gifHtml = <>gif(name="source")
  let imgHtml = """<img src="source.gif" />"""
  check htmlEqual($convertTagGif(gifHtml), imgHtml) 

test "convert gif with source and position to equivalent img":
  let gifHtml = <>gif(name="source", x="10", y="20")
  let imgHtml = """<div style="position:absolute;left:10;top:20;"><img src="source.gif" /></div>""" 
  check htmlEqual($convertTagGif(gifHtml), imgHtml) 

test "convert empty dlg to nothing":
  let dlgHtml = <>dlg(newText(""))
  check ($convertTagDlg(dlgHtml) == "")

test "convert dlg with text":
  let dlgHtml = <>dlg(newText("Hello!"))
  let resultHtml = parseHtml("""
    <table border="0" cellpadding="2" bgcolor="white" width="300px"><tr><td>
    <center>Hello!</center>
    </td></tr></table>""".unindent)
  check htmlEqual($convertTagDlg(dlgHtml), $resultHtml)

test "convert dlg with position":
  let dlgHtml = <>dlg(x="100", y="200", newText("Hello!"))
  let resultHtml = parseHtml("""
    <div style="position:absolute;left:100;top:200;">
    <table border="0" cellpadding="2" bgcolor="white" width="300px"><tr><td>
    <center>Hello!</center>
    </td></tr></table></div>""".unindent)
  check htmlEqual($convertTagDlg(dlgHtml), $resultHtml)