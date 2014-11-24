import unittest, xmltree, strtabs, tml

test "convert empty gif to empty img":
  let gifHtml = <>gif()
  let imgHtml = "<img />" 
  check ($convertTagGif(gifHtml) == imgHtml) 

test "convert gif with source to equivalent img":
  let gifHtml = <>gif(name="source")
  let imgHtml = """<img src="source.gif" />"""
  check ($convertTagGif(gifHtml) == imgHtml) 

test "convert gif with source and position to equivalent img":
  let gifHtml = <>gif(name="source", x="10", y="20")
  let imgHtml = """<div style="position:absolute;left:10;top:20"><img src="source.gif" /></div>""" 
  check ($convertTagGif(gifHtml) == imgHtml) 