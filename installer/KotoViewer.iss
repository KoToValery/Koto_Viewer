; KoToViewer Inno Setup Installer
; Generated for Flutter Windows Release build

#define MyAppName "KoToViewer"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "KoTo"
#define MyAppURL "https://github.com/KoToValery/Koto_Viewer"
#define MyAppExeName "koto_viewer.exe"
#define ReleaseDir "C:\Flutter\Koto_Viewer-main\build\windows\x64\runner\Release"
#define InstallerDir "C:\Flutter\Koto_Viewer-main\installer"

[Setup]
AppId={{A7B0E9E8-6B55-4D8D-9C4A-7B7B6B1C2026}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir={#InstallerDir}\Output
OutputBaseFilename=KotoViewer_Setup_{#MyAppVersion}
SetupIconFile={#InstallerDir}\KotoViewer.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
DisableProgramGroupPage=yes
ChangesAssociations=yes
CloseApplications=yes
RestartApplications=no

; Modern Wizard Graphics
WizardImageFile={#InstallerDir}\wizard_sidebar.png
WizardSmallImageFile={#InstallerDir}\wizard_small.png

; License File
LicenseFile={#InstallerDir}\LICENSE.txt

; Version Information for Setup.exe
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCopyright=Copyright (C) 2026 {#MyAppPublisher}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel1=Welcome to the {#MyAppName} Setup Wizard
WelcomeLabel2=This wizard will install {#MyAppName} on your computer.%n%nAn all-in-one powerful and lightweight viewer supporting 70+ file formats including CAD drawings, 3D models, PDF documents, and medical DICOM images.%n%n• View multiple formats: DWG, DXF, PDF, DICOM, STEP, IGES & 70+ more%n• Fast & lightweight: Smooth hardware acceleration, fast startup%n• Your files, your control: 100%% private, no ads, no telemetry%n• Modern Windows native desktop experience%n%nClick Next to continue, or Cancel to exit Setup.

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"
Name: "assoc_dwg"; Description: "AutoCAD &DWG Drawing (*.dwg)"; GroupDescription: "File associations (select formats to associate):"; Flags: unchecked
Name: "assoc_dxf"; Description: "AutoCAD &DXF Drawing (*.dxf)"; GroupDescription: "File associations (select formats to associate):"; Flags: unchecked
Name: "assoc_pdf"; Description: "PDF &Document (*.pdf)"; GroupDescription: "File associations (select formats to associate):"; Flags: unchecked
Name: "assoc_dicom"; Description: "DICOM &Medical Image (*.dcm, *.dicom)"; GroupDescription: "File associations (select formats to associate):"; Flags: unchecked

[Files]
; Copy the complete Flutter Release directory, including DLLs and data/
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; WorkingDir: "{app}"

[Registry]
; File associations - each format is associated only if selected by the user.
; DXF
Root: HKCR; Subkey: ".dxf"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.dxf"; Flags: uninsdeletevalue; Tasks: assoc_dxf
Root: HKCR; Subkey: "KotoViewer.dxf"; ValueType: string; ValueName: ""; ValueData: "DXF Drawing"; Flags: uninsdeletekey; Tasks: assoc_dxf
Root: HKCR; Subkey: "KotoViewer.dxf\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: assoc_dxf
Root: HKCR; Subkey: "KotoViewer.dxf\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: assoc_dxf

; DWG
Root: HKCR; Subkey: ".dwg"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.dwg"; Flags: uninsdeletevalue; Tasks: assoc_dwg
Root: HKCR; Subkey: "KotoViewer.dwg"; ValueType: string; ValueName: ""; ValueData: "DWG Drawing"; Flags: uninsdeletekey; Tasks: assoc_dwg
Root: HKCR; Subkey: "KotoViewer.dwg\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: assoc_dwg
Root: HKCR; Subkey: "KotoViewer.dwg\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: assoc_dwg

; PDF
Root: HKCR; Subkey: ".pdf"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.pdf"; Flags: uninsdeletevalue; Tasks: assoc_pdf
Root: HKCR; Subkey: "KotoViewer.pdf"; ValueType: string; ValueName: ""; ValueData: "PDF Document"; Flags: uninsdeletekey; Tasks: assoc_pdf
Root: HKCR; Subkey: "KotoViewer.pdf\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: assoc_pdf
Root: HKCR; Subkey: "KotoViewer.pdf\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: assoc_pdf

; DICOM (.dcm and .dicom)
Root: HKCR; Subkey: ".dcm"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.dcm"; Flags: uninsdeletevalue; Tasks: assoc_dicom
Root: HKCR; Subkey: "KotoViewer.dcm"; ValueType: string; ValueName: ""; ValueData: "DICOM Image"; Flags: uninsdeletekey; Tasks: assoc_dicom
Root: HKCR; Subkey: "KotoViewer.dcm\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: assoc_dicom
Root: HKCR; Subkey: "KotoViewer.dcm\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: assoc_dicom

Root: HKCR; Subkey: ".dicom"; ValueType: string; ValueName: ""; ValueData: "KotoViewer.dicom"; Flags: uninsdeletevalue; Tasks: assoc_dicom
Root: HKCR; Subkey: "KotoViewer.dicom"; ValueType: string; ValueName: ""; ValueData: "DICOM Image"; Flags: uninsdeletekey; Tasks: assoc_dicom
Root: HKCR; Subkey: "KotoViewer.dicom\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: assoc_dicom
Root: HKCR; Subkey: "KotoViewer.dicom\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: assoc_dicom

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent; WorkingDir: "{app}"

[Code]
var
  SubtitleLabel: TLabel;
  TaglineLabel: TLabel;
  VersionLabel: TLabel;
  CopyrightLabel: TLabel;

procedure InitializeWizard;
begin
  // Stylize the Welcome title
  WizardForm.WelcomeLabel1.Font.Size := 13;
  WizardForm.WelcomeLabel1.Font.Style := [fsBold];

  // Subtitle: KoToViewer - Free All in One Viewer
  SubtitleLabel := TLabel.Create(WizardForm);
  SubtitleLabel.Parent := WizardForm.WelcomePage;
  SubtitleLabel.Left := WizardForm.WelcomeLabel2.Left;
  SubtitleLabel.Top := WizardForm.WelcomeLabel1.Top + WizardForm.WelcomeLabel1.Height + ScaleY(2);
  SubtitleLabel.Caption := 'KoToViewer – Free All in One Viewer';
  SubtitleLabel.Font.Style := [fsBold];
  SubtitleLabel.Font.Size := 10;
  SubtitleLabel.Font.Color := $C05000; // Modern vibrant blue accent ($BBGGRR)

  // Tagline: View your files. Anytime. Anywhere.
  TaglineLabel := TLabel.Create(WizardForm);
  TaglineLabel.Parent := WizardForm.WelcomePage;
  TaglineLabel.Left := WizardForm.WelcomeLabel2.Left;
  TaglineLabel.Top := SubtitleLabel.Top + SubtitleLabel.Height + ScaleY(3);
  TaglineLabel.Caption := 'View your files. Anytime. Anywhere.';
  TaglineLabel.Font.Style := [fsItalic];
  TaglineLabel.Font.Color := clGrayText;

  // Reposition Welcome body text below tagline
  WizardForm.WelcomeLabel2.Top := TaglineLabel.Top + TaglineLabel.Height + ScaleY(8);
  WizardForm.WelcomeLabel2.Height := ScaleY(180);

  // Version indicator at the bottom of the Welcome page
  VersionLabel := TLabel.Create(WizardForm);
  VersionLabel.Parent := WizardForm.WelcomePage;
  VersionLabel.Left := WizardForm.WelcomeLabel2.Left;
  VersionLabel.Top := WizardForm.WelcomePage.Height - ScaleY(32);
  VersionLabel.Caption := 'Version: ' + '{#MyAppVersion}' + ' (64-bit)';
  VersionLabel.Font.Style := [fsBold];
  VersionLabel.Font.Color := clGrayText;

  // Copyright text
  CopyrightLabel := TLabel.Create(WizardForm);
  CopyrightLabel.Parent := WizardForm.WelcomePage;
  CopyrightLabel.Left := WizardForm.WelcomeLabel2.Left;
  CopyrightLabel.Top := VersionLabel.Top + VersionLabel.Height + ScaleY(1);
  CopyrightLabel.Caption := '© 2026 {#MyAppPublisher}. All rights reserved.';
  CopyrightLabel.Font.Size := 8;
  CopyrightLabel.Font.Color := clGrayText;
end;

