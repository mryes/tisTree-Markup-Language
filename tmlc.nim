include tml

proc generateOutput*(filename, htmlOutput: string): void = 
  let fileExtension = filename.splitFile.ext
  let outputFilename = if fileExtension == ".html": filename & ".result" 
                       else: filename.split('.')[0] & ".html" 
  writeFile(outputFilename, htmlOutput) 

when isMainModule:
  let filename = paramStr(1)
  let html = compileTml(readFile(filename), filename.splitPath.head) 
  generateOutput(filename, html)
