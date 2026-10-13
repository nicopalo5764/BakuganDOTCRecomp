; Build from the candidate folder produced by scripts/Package.ps1.
; ISCC.exe /DPackageDir="D:\candidate" installer\BakuganDOTC_Setup.iss
#ifndef PackageDir
  #error Define PackageDir as the output directory of scripts/Package.ps1
#endif
#define MyAppName "Bakugan DOTC Recompiled"
#define MyAppVersion "0.1.0-preview"
[Setup]
AppId={{74E81A38-2920-49BF-B87E-2CB3F09A85E8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=BakuganDOTCRecomp contributors
DefaultDirName={localappdata}\Programs\BakuganDOTCRecomp
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=output
OutputBaseFilename=BakuganDOTCRecomp-{#MyAppVersion}-win64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\BakuganLauncher.exe
CloseApplications=yes
[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
[CustomMessages]
spanish.PlayShortcut=Jugar
english.PlayShortcut=Play
spanish.ConfigureShortcut=Configurar
english.ConfigureShortcut=Configure
spanish.UninstallShortcut=Desinstalar
english.UninstallShortcut=Uninstall
spanish.ConfigureNow=Configurar mi copia del juego
english.ConfigureNow=Set up my copy of the game
spanish.LauncherLang=--lang=es
english.LauncherLang=--lang=en
[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
[Files]
; Explicit allowlist: never include a whole development/build folder.
Source: "{#PackageDir}\BakuganLauncher.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\bakugandotc.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\rexruntime.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\rexgpu-xenos.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\gamecontrollerdb.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\compatibility.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\dependencies.lock.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\build-info.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\README.es.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PackageDir}\licenses\*"; DestDir: "{app}\licenses"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\{cm:PlayShortcut}"; Filename: "{app}\BakuganLauncher.exe"; Parameters: "{cm:LauncherLang}"; WorkingDir: "{app}"
Name: "{group}\{cm:ConfigureShortcut}"; Filename: "{app}\BakuganLauncher.exe"; Parameters: "--configure {cm:LauncherLang}"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallShortcut}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\BakuganLauncher.exe"; Parameters: "{cm:LauncherLang}"; Tasks: desktopicon; WorkingDir: "{app}"
[Run]
Filename: "{app}\BakuganLauncher.exe"; Parameters: "--configure {cm:LauncherLang}"; Description: "{cm:ConfigureNow}"; Flags: nowait postinstall skipifsilent
; No game files or user settings are removed during uninstall.
