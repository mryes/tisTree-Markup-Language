import os, times, tmlc

when isMainModule:
  let filename = paramStr(1)
  var lastCompileTime = getTime()
  echo "Hello! Waiting for you to do something..."
  while true:
    if lastCompileTime < getLastModificationTime(filename):
      generateOutputFromFile(filename)
      lastCompileTime = getLastModificationTime(filename)
    sleep(500)