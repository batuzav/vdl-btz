; Instalador de vdl-btz para Windows (Inno Setup). Uso: ISCC.exe /DAppVersion=<versión> packaging\windows\vdl-btz.iss
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppName=vdl-btz
AppVersion={#AppVersion}
DefaultDirName={autopf}\vdl-btz
PrivilegesRequired=lowest
OutputDir=..\..\dist
OutputBaseFilename=vdl-btz-windows-x64-setup
ArchitecturesAllowed=x64compatible
Compression=lzma2

[Tasks]
Name: "desktopicon"; Description: "Crear un icono en el escritorio"

[Files]
Source: "..\..\stage-win\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs
Source: "vdl-btz-launcher.vbs"; DestDir: "{app}"

[Icons]
Name: "{autoprograms}\vdl-btz"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\vdl-btz-launcher.vbs"""
Name: "{autodesktop}\vdl-btz"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\vdl-btz-launcher.vbs"""; Tasks: desktopicon
