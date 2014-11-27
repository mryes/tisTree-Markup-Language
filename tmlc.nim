include tml

proc generateOutputFromFile*(filename: string): void = 
  let htmlOutput = compileTml(readFile(filename))
  let fileExtension = filename.splitFile.ext
  let outputFilename = if fileExtension == ".html": filename & ".result" 
                       else: filename.split('.')[0] & ".html" 
  writeFile(outputFilename, htmlOutput) 

when isMainModule:
  let filename = paramStr(1)
  generateOutputFromFile(filename)
