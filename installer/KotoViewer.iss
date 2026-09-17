; KotoViewer Inno Setup Installer
; Generated for Flutter Windows Release build

#define MyAppName "KotoViewer"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "KoTo"
#define MyAppExeName "koto_viewer.exe"
#define ReleaseDir "C:\Flutter\Koto_Viewer-main\build\windows\x64\runner\Release"
#define InstallerDir "C:\Flutter\Koto_Viewer-main\installer"

[Setup]
AppId={{A7B0E9E8-6B55-4D8D-9C4A-7B7B6B1C2026}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir={#InstallerDir}\Output
OutputBaseFilename=KotoViewer_Setup_{#MyAppVersion}
SetupIconFile={#InstallerDir}\KotoViewer.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
DisableProgramGroupPage=yes

LicenseFile={#InstallerDir}\LICENSE.txt

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"
Name: "fileassoc"; Description: "Associate supported files with KotoViewer"; GroupDescription: "File associations:"

[Files]
; Copy the complete Flutter Release directory, including DLLs and data/
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; File associations are installed only when the user selects the option.
Root: HKCR; Subkey: ".dxf"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.dxf"; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dxf"; ValueType: string; ValueName: ""; ValueData: "DXF Drawing"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dxf\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dxf\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: fileassoc

Root: HKCR; Subkey: ".dwg"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.dwg"; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dwg"; ValueType: string; ValueName: ""; ValueData: "DWG Drawing"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dwg\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dwg\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: fileassoc

Root: HKCR; Subkey: ".pdf"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.pdf"; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.pdf"; ValueType: string; ValueName: ""; ValueData: "PDF Document"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.pdf\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.pdf\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: fileassoc

Root: HKCR; Subkey: ".dcm"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.dcm"; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dcm"; ValueType: string; ValueName: ""; ValueData: "DICOM Image"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dcm\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dcm\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: fileassoc

Root: HKCR; Subkey: ".dicom"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.dicom"; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dicom"; ValueType: string; ValueName: ""; ValueData: "DICOM Image"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dicom\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: fileassoc
Root: HKCR; Subkey: "KotoViewer.dicom\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: fileassoc

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
