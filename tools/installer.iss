; Установщик Dota Draft для Windows (Inno Setup 6). Ставится без прав администратора в профиль пользователя.
#define BuildNo GetEnv("BUILD_NO")
#if BuildNo == ""
  #define BuildNo "0"
#endif

[Setup]
AppId={{8F3C2A51-5D7B-4E1A-9C64-2B7D1E9A0F11}
AppName=Dota Draft
AppVersion=1.0.{#BuildNo}
AppPublisher=Dota Draft
DefaultDirName={localappdata}\Programs\Dota Draft
DefaultGroupName=Dota Draft
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=Dota-Draft-Setup
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\dota_draft.exe
CloseApplications=force
RestartApplications=no
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Dota Draft"; Filename: "{app}\dota_draft.exe"
Name: "{group}\{cm:UninstallProgram,Dota Draft}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Dota Draft"; Filename: "{app}\dota_draft.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\dota_draft.exe"; Description: "{cm:LaunchProgram,Dota Draft}"; Flags: nowait postinstall skipifsilent
; После тихого автообновления — снова запустить приложение.
Filename: "{app}\dota_draft.exe"; Flags: nowait; Check: WizardSilent
