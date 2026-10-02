; Inno Setup script for the NIGOH Family Windows app (built in CI).
; Usage: iscc /DAppVersion=2.16.0 /DSourceDir=..\..\build\windows\x64\runner\Release nigoh_family.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{6B7A3E52-2C1D-4F0E-9A51-7C2E4D8F1A90}
AppName=NIGOH Family
AppVersion={#AppVersion}
AppPublisher=NIGOH Family
AppPublisherURL=https://nigohfamily.qobus.tj
AppSupportURL=https://nigohfamily.qobus.tj/faq
DefaultDirName={autopf}\NIGOH Family
DefaultGroupName=NIGOH Family
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=NIGOH_Family_Windows_Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\nigoh_family.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\NIGOH Family"; Filename: "{app}\nigoh_family.exe"
Name: "{autodesktop}\NIGOH Family"; Filename: "{app}\nigoh_family.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\nigoh_family.exe"; Description: "{cm:LaunchProgram,NIGOH Family}"; Flags: nowait postinstall skipifsilent
