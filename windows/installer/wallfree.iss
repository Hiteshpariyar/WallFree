#define AppName "Wallfree"

#ifndef AppVersion
  #error AppVersion must be supplied by the build workflow.
#endif

#ifndef SourceDir
  #error SourceDir must be supplied by the build workflow.
#endif

[Setup]
AppId={{E20500BA-23E2-4DA8-BF79-28E81C56E186}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Wallfree
DefaultDirName={localappdata}\Programs\Wallfree
DefaultGroupName=Wallfree
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputBaseFilename=Wallfree-Windows-Setup-{#AppVersion}
ArchitecturesInstallIn64BitMode=x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Wallfree"; Filename: "{app}\wallfree.exe"
Name: "{autodesktop}\Wallfree"; Filename: "{app}\wallfree.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\wallfree.exe"; Description: "Launch Wallfree"; Flags: postinstall nowait skipifsilent
