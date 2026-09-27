; ============================================================
;  RoundedTB Revived - Inno Setup script
;
;  Build (via ISCC):
;    ISCC.exe /DPubDir="C:\path\to\published\files" \
;             /DVersion="R4.1.3" \
;             /DArch="x64" \
;             /DFrameworkDependent="false" \
;             Installer\RoundedTB.iss
;
;  /D parameters:
;    PubDir             - folder containing the dotnet publish output (required)
;    Version            - release version string, e.g. R4.1.3 (required)
;    Arch               - x86 | x64 | arm64 (required)
;    FrameworkDependent - true|false; false = self-contained (default false)
;    SetupIconFile      - installer window icon (default ..\RoundedTB\RoundedTB.ico)
;
;  Output (Installer\output\):
;    RoundedTB-<Version>-win-<Arch>[-framework-dependent]-setup.exe
;
;  API notes (Inno Setup 7.1):
;    - The uninstaller reuses the global WizardForm variable (TWizardForm);
;      there is no separate TUninstallForm type in 7.x.
;    - TNewCheckBox has no AutoSize property.
;    - The per-user LocalAppData constant is {localappdata} (not {userlocalappdata}).
; ============================================================

#ifndef PubDir
  #define PubDir "RoundedTB\bin\Release\net8.0-windows10.0.19041\win-x64-sc"
#endif
#ifndef Version
  #define Version "R4.1.3"
#endif
#ifndef Arch
  #define Arch "x64"
#endif
#ifndef FrameworkDependent
  #define FrameworkDependent "false"
#endif
#ifndef SetupIconFile
  #define SetupIconFile "..\RoundedTB\RoundedTB.ico"
#endif

; Derived values (ISPP: substring is Copy(str, start, len); == for comparison)
#ifdef Version
  #if Copy(Version, 1, 1) == 'R'
    #define InstallVersion Copy(Version, 2, 999)
  #else
    #define InstallVersion Version
  #endif
#endif
#if FrameworkDependent == 'true'
  #define Suffix '-framework-dependent'
#else
  #define Suffix ''
#endif
#define SetupName 'RoundedTB-' + Version + '-win-' + Arch + Suffix + '-setup'

[Setup]
; NOTE: AppId is stable across releases so Inno detects previous installs on
;       upgrade. Do not change once shipped.
AppId={{9C8A6E42-5B31-4F0D-8A7C-2E1D4B6F0A33}
AppName=RoundedTB Revived
AppVersion={#InstallVersion}
AppVerName=RoundedTB Revived {#InstallVersion}
AppPublisher=RoundedTB Revived
AppPublisherURL=https://github.com/linlinger/RoundedTB-Revived
AppSupportURL=https://github.com/linlinger/RoundedTB-Revived/issues
AppComments=Add margins, rounded corners and segments to your taskbars!
DefaultDirName={localappdata}\RoundedTB
DefaultGroupName=RoundedTB Revived
; Per-user install (no UAC): the app's config/log already live in %LOCALAPPDATA%,
; and it writes no HKLM state. Users may still override to "all users" if they wish.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Each installer is built per-arch (see build.bat), so we don't hard-restrict
; which OS archs can run it. On x64/arm64 systems use 64-bit install mode
; (correct modern default for .NET). Inno 7.x syntax: "x64compatible or arm64".
ArchitecturesInstallIn64BitMode=x64compatible or arm64
; Min OS: Windows 10 1607 (build 14393) - the Win32 taskbar structure we rely on.
MinVersion=10.0.14393
; Uninstall entry (control-panel version comes from AppVersion above)
UninstallDisplayName=RoundedTB Revived
UninstallDisplayIcon={app}\RoundedTB.exe
; Setup exe properties
SetupIconFile={#SetupIconFile}
ShowLanguageDialog=auto
; Output
OutputDir=output
OutputBaseFilename={#SetupName}
Compression=lzma2/max
SolidCompression=yes
; Code signing (uncomment once a certificate is available):
; SignFiles=
; SignedUninstaller=yes
; Version info embedded in the setup exe
VersionInfoVersion={#InstallVersion}.0
VersionInfoCompany=RoundedTB Revived
VersionInfoDescription=RoundedTB Revived setup
VersionInfoProductName=RoundedTB Revived

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "Languages\ChineseSimplified.isl"

[CustomMessages]
english.CreateStartupTaskDesc=Start RoundedTB Revived at log on
english.CreateDesktopIcon=Create a desktop shortcut
english.LaunchAfterInstall=Launch RoundedTB Revived after installation
chinesesimplified.CreateStartupTaskDesc=登录时自动启动 RoundedTB Revived
chinesesimplified.CreateDesktopIcon=创建桌面快捷方式
chinesesimplified.LaunchAfterInstall=安装完成后立即运行 RoundedTB Revived

[Tasks]
Name: "startup"; Description: "{cm:CreateStartupTaskDesc}"; Flags: checkedonce
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: checkedonce
Name: "run"; Description: "{cm:LaunchAfterInstall}"; Flags: checkedonce

[Files]
Source: "{#PubDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\RoundedTB Revived"; Filename: "{app}\RoundedTB.exe"
Name: "{group}\{cm:UninstallProgram,RoundedTB Revived}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\RoundedTB Revived"; Filename: "{app}\RoundedTB.exe"; WorkingDir: "{app}"; Tasks: desktopicon
; Startup-folder shortcut: the app's own "run on startup" checkbox looks for
; exactly this filename and reports it as checked (MainWindow.Startup_Clicked),
; so creating it here keeps installer and app state in sync.
Name: "{userappdata}\Microsoft\Windows\Start Menu\Programs\Startup\RoundedTB Revived.lnk"; Filename: "{app}\RoundedTB.exe"; WorkingDir: "{app}"; Tasks: startup

[Run]
Filename: "{app}\RoundedTB.exe"; Description: "{cm:LaunchAfterInstall}"; Tasks: run; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Remove the startup shortcut(s) so uninstalling leaves no orphan .lnk pointing
; at a deleted exe. The app's checkbox logic treats a missing shortcut as "off".
Filename: cmd.exe; Parameters: "/c if exist ""{userappdata}\Microsoft\Windows\Start Menu\Programs\Startup\RoundedTB Revived.lnk"" del /q ""{userappdata}\Microsoft\Windows\Start Menu\Programs\Startup\RoundedTB Revived.lnk"" & if exist ""{userappdata}\Microsoft\Windows\Start Menu\Programs\Startup\RoundedTB.lnk"" del /q ""{userappdata}\Microsoft\Windows\Start Menu\Programs\Startup\RoundedTB.lnk"""; Flags: runhidden; RunOnceId: DeleteStartupLinks

[UninstallDelete]
; rtb.json / rtb.log are kept by default (green-app convention); the
; "delete settings" checkbox on the uninstall Ready page removes them when
; checked (handled in [Code] via CurUninstallStepChanged).
; The filesdir entry below is a harmless fallback that only runs when the
; checkbox is selected, so a partially-deleted folder still gets cleaned.
Name: "{localappdata}\rtb.json"; Type: files; Check: DeleteSettingsSelected
Name: "{localappdata}\rtb.log"; Type: files; Check: DeleteSettingsSelected

[Code]
var
  DeleteSettingsCheck: TNewCheckBox;

function DeleteSettingsSelected: Boolean;
begin
  Result := (DeleteSettingsCheck <> nil) and DeleteSettingsCheck.Checked;
end;

// Add a "delete settings" checkbox to the uninstaller's Ready page.
// Inno 7.x: the uninstaller shares the global WizardForm (TWizardForm).
procedure InitializeUninstallDialog;
begin
  if WizardForm.ReadyPage <> nil then
  begin
    DeleteSettingsCheck := TNewCheckBox.Create(WizardForm);
    DeleteSettingsCheck.Parent := WizardForm.ReadyPage;
    DeleteSettingsCheck.Top := 40;
    DeleteSettingsCheck.Left := 26;
    DeleteSettingsCheck.Width := 320;
    DeleteSettingsCheck.Caption := 'Delete settings (rtb.json / rtb.log)';
    DeleteSettingsCheck.Checked := False;
  end;
end;
