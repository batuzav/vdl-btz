' Lanza vdl-btz sin ventana de consola: estilo de ventana 0 (oculta) y sin esperar.
Set sh = CreateObject("WScript.Shell")
dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
sh.Run """" & dir & "\ruby\bin\ruby.exe"" """ & dir & "\app\bin\vdl-btz"" gui", 0, False
