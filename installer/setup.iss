; Inno Setup Script for HaloStory AI
; Usage: iscc /dAppVersion=1.10.0 installer\setup.iss

#define AppName "HaloStory AI"
#define AppPublisher "R8KStudio"
#define AppURL "https://hsai.rafiq8k.my.id"
#define AppExe "bluetalk_frontend.exe"

#ifndef AppVersion
  #define AppVersion "1.13.1"
#endif

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
VersionInfoVersion={#AppVersion}.0
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName}
VersionInfoCopyright=Copyright (C) 2026 {#AppPublisher}. All rights reserved.
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir=..\build\installer
OutputBaseFilename=HaloStory_AI_V{#AppVersion}_Installer
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
DisableProgramGroupPage=yes
DisableDirPage=auto
WizardStyle=modern
InfoBeforeFile=Readme.txt

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "id"; MessagesFile: "Languages\Indonesian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "Readme.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Comment: "{#AppName}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Comment: "{#AppName}"; Tasks: desktopicon
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent unchecked
