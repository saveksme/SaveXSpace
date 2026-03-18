[Setup]
AppId={{728B3532-C74B-4870-9068-BE70FE12A3E6}
AppVersion=1.0.0
AppName=SaveX Space
AppPublisher=SaveX
AppPublisherURL=https://t.me/savexchannel
AppSupportURL=https://t.me/savexchannel
AppUpdatesURL=https://t.me/savexchannel
DefaultDirName={autopf}\SaveX Space
DisableProgramGroupPage=yes
OutputDir=..\..\..\build\installer
OutputBaseFilename=SaveXSpace-Setup
Compression=lzma
SolidCompression=yes
SetupIconFile=..\..\runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64 arm64
ArchitecturesInstallIn64BitMode=x64 arm64

[Code]
procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Processes := ['SaveXSpace.exe', 'SaveXSpaceCore.exe', 'SaveXSpaceHelperService.exe'];

  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

function InitializeSetup(): Boolean;
begin
  KillProcesses;
  Result := True;
end;

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "..\..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\SaveX Space"; Filename: "{app}\SaveXSpace.exe"
Name: "{autodesktop}\SaveX Space"; Filename: "{app}\SaveXSpace.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\SaveXSpace.exe"; Description: "{cm:LaunchProgram,SaveX Space}"; Flags: runascurrentuser nowait postinstall skipifsilent
