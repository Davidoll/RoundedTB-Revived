# AGENTS.md — RoundedTB Revived

Guidance for AI coding agents working in this repository.

**Language note**: the repo's comments, `PROGRESS.md` and this file are written in Chinese
(comments) / English (code identifiers, commit subjects, some docs). The maintainer prefers
**Chinese replies**; commit messages use English `fix:` / `feat:` / `docs:` / `chore:` prefixes.

---

## 1. What this project is

RoundedTB Revived — a community continuation of [RoundedTB](https://github.com/torchgm/RoundedTB)
(original author torchgm, GPL v3). It adds **margins, rounded corners and "segments"** (separate
rounded app-list / tray / widgets sections) to the Windows 10 & 11 taskbars.

How it works: it attaches a **window region** (`SetWindowRgn` + `CreateRoundRectRgn`) to the real
taskbar windows **owned by Explorer** — it does not draw anything itself.

- User-visible name: **RoundedTB Revived**
- Internal assembly / namespace / exe: **`RoundedTB`** — do NOT rename these.
- Git root is `RoundedTB/` (this folder).

Read `PROGRESS.md` for the maintenance log (what was fixed when), `ANALYSIS-R3.1-to-HEAD.md` for
the diff against upstream R3.1, `R5-PLAN.md` for the R5 roadmap, `CLAUDE.md` for a parallel
architecture write-up.

## 2. Maintenance goals (in priority order)

1. **Compatibility**: Windows 10 (1607+) through Windows 11 (24H2 / modern Insider builds).
   Win11 22H2+ depends on the UIA geometry in `Taskbar.cs`.
2. **Preserve original behaviour**: align with the R3.1 baseline (e.g. tray icon theme mapping,
   close-button-hides-window). Behaviour regressions are treated as bugs.
3. **Bugs and stability before new features.** Per-segment hiding etc. are deliberately deferred.
4. All changes go through git commits.

## 3. Build & run

Windows-only. No test project, no linter — **do not invent test commands**.

```bash
# normal build (channel defaults to canary)
build.bat
build.bat master
build.bat dev

# equivalent manual build
dotnet build RoundedTB/RoundedTB.csproj -c Release -p:Channel=Master

# multi-arch release zips into .\release\  (6 zips)
build.bat --release --version R4.1.3

# ...plus Inno Setup installers (needs Inno Setup 6/7, ISCC on PATH)
build.bat --release --version R4.1.3 --installer
```

- Requires only the .NET SDK (`dotnet build` works for WPF here; the legacy
  `IWshRuntimeLibrary` COM reference was removed and `EnableStartup()` uses late-bound
  `WScript.Shell` via `dynamic`).
- **Output path (current, net10):**
  `RoundedTB/bin/Release/net10.0-windows10.0.19041/RoundedTB.exe` (launcher) + `RoundedTB.dll`
  (the actual app). ⚠️ `bin/Release/` may also contain a stale `net8.0-...` folder from earlier
  builds — always launch/verify against the **`net10.0-windows10.0.19041`** path.
- The MSIX packaging project (`PackagingProject/RoundedTB.Package.wapproj`) is NOT built by
  `build.bat` — it needs Visual Studio tooling and is only relevant for Store publishing.
- CI (`.github/workflows/ci.yml`) builds on `windows-2022` and uploads `rtb-artifacts`; a second
  `installers` job installs Inno Setup and builds the `.exe` installers.

### Build channels

`-p:Channel=Canary|Dev|Master` (default Canary) selects branding **and logging** via
`ChannelInfo.cs` (`#if CHANNEL_*`):

| Channel | Icon / banner | `Version` | `VerboseLogging` |
|---|---|---|---|
| Canary | RoundedTBCanary.ico | -1 (skips config-reset-on-upgrade) | **true** |
| Dev | RoundedTBDev.ico | -1 | **true** |
| Master | RoundedTB.ico | 3 | **false** (high-frequency diagnostics filtered) |

`Version` gates the "settings schema changed → reset IsNotFirstLaunch" migration in
`MainWindow`. **Do not bump it** unless the config schema actually changes — it resets user configs.

## 4. Architecture

One project (`RoundedTB/`), namespace `RoundedTB`, single main window. The ~100 ms loop:

1. **`MainWindow.xaml.cs`** — the only real window; all orchestration. Startup: reads the OS build
   from the registry (`>= 21996` ⇒ Win11) and branches Win11/Win10 behaviour; single-instance
   (a second launch renames the existing window to `RoundedTB_SettingsRequest` to make it show
   itself, then exits); loads/saves `Types.Settings` through `Interaction.ReadJSON/WriteJSON`;
   calls `Taskbar.GenerateTaskbarInfo()` and applies the initial regions.
   `ApplyButton_Click` is the central "commit settings to taskbars" path.
2. **`Taskbar.cs`** (static) — finds taskbars with `FindWindowExA`: `Shell_TrayWnd` (main) +
   `Shell_SecondaryTrayWnd` (per-monitor), each one's tray (`TrayNotifyWnd`;
   `Windows.UI.Composition.DesktopWindowContentBridge` on Win11) and app-list
   (`MSTaskSwWClass` / `MSTaskListWClass`). `UpdateSimpleTaskbar` / `UpdateDynamicTaskbar` build
   the regions. **All geometry is physical pixels** — margins/radii are multiplied by
   `taskbar.ScaleFactor` (= `GetDpiForWindow(hwnd) / 96`).
   - **Win11 22H2+ (important)**: the taskbar content is rendered by a XAML island and the legacy
     `MSTaskSwWClass` rect no longer tracks the real icon positions, so `UpdateDynamicTaskbar`
     derives the segment span from **UI Automation** (`GetTrueTaskbarContentBounds`), falling back
     to the legacy rect. `Background.DoWork` re-queries every ~1 s and forces a redraw on change.
   - `IsAltTabOverlayOpen` (used by `FillOnTaskSwitch`) uses three conditions (foreground host
     window / enumerated island covering the work area / 200 ms grace) — see §7.
3. **`Background.cs`** — the heart: a `BackgroundWorker` polling every ~100 ms. Re-checks taskbar
   count/handles (with exponential backoff when Explorer restarts), cursor position (hover-reveal
   of segments, auto-hide), maximised-window fill (`TaskbarShouldBeFilled`), and reapplies regions
   when any rect changed (`TaskbarRefreshRequired`).
4. **`LocalPInvoke.cs`** — all native interop (`user32` / `gdi32` / `shell32` / `dwmapi`):
   `[DllImport]`s, structs (`RECT`, `POINT`, `MONITORINFO`, `WINDOWPLACEMENT`…), constants/enums.
5. **`Interaction.cs`** — JSON settings + log I/O, top-level window enumeration, work-area
   manipulation for auto-hide, and **TranslucentTB compatibility** (posts the registered
   `TTB_ForceRefreshTaskbar` message to `TTB_WorkerWindow`).
6. **`Types.cs`** — `Types.Taskbar` (HWNDs + rects + scale factor + flags), `Types.Settings`
   (persisted as JSON), `Types.SegmentSettings`, `Types.EffectiveRegion`.
7. **`ChannelInfo.cs`** — per-channel branding/version/logging constants (see §3).
8. **`Localization/`** + `Strings/*.json` — hand-editable JSON translations (see §6).
9. **`App.xaml.cs`** — global exception logging, single-instance mutex, language init, theme apply,
   window creation, and a belt-and-braces taskbar reset on exit.

Supporting: `AppBars.cs` (SHAppBarMessage wrappers), `MonitorStuff.cs` (display enumeration),
`AboutWindow.xaml(.cs)`, `Infobox.xaml(.cs)`.

## 5. UI framework & tray (R5 state)

Currently **.NET 10 + WPF-UI 4.3.0 + Hardcodet.NotifyIcon.Wpf 2.0.1** (migrated in R5 from
`net8.0` + WPF-UI 1.2.1 + a hand-rolled `Shell_NotifyIcon` `TrayIcon.cs` which was deleted).

WPF-UI 4.x specifics — these differ from every 1.x tutorial and are easy to get wrong:

- Resource dictionaries in `App.xaml`: `<ui:ThemesDictionary Theme="Dark"/>` +
  `<ui:ControlsDictionary/>`. The 1.x `Styles/Theme/Dark.xaml` + `Styles/WPFUI.xaml` pair is gone.
- XML namespace: `xmlns:ui="http://schemas.lepo.co/wpfui/2022/xaml"`.
- Window root element is **`<ui:FluentWindow>`** (the 1.x `Style="{StaticResource UiWindow}"` no
  longer exists); the code-behind base class must match (`: Wpf.Ui.Controls.FluentWindow`), or you
  get CS0263. Backdrop/corner/extends-content are set via `WindowBackdropType`,
  `WindowCornerPreference`, `ExtendsContentIntoTitleBar`.
- `WPFUI.Theme.Watcher.Start()` → `ApplicationThemeManager.Apply(...)` +
  `SystemThemeWatcher.Watch(window, backdrop, true)`.
- `WPFUI.Background.Manager.Apply(Mica, win)` → `WindowBackgroundManager.UpdateBackground(...)` /
  `WindowBackdropType.Mica`; `WPFUI.Common.Appearance` → `Controls.ControlAppearance`.
- `TitleBar.Icon` takes an `IconElement` → wrap bitmaps in
  `new Wpf.Ui.Controls.ImageIcon { Source = new BitmapImage(...) }`.
- `TitleBar.ApplicationNavigation`, `NotifyIconTooltip` and **`CloseActionOverride`** were removed.
  `CloseClicked` fires but `CloseWindow()` runs unconditionally afterwards, so it cannot veto a
  close. **Close semantics are therefore implemented in `OnClosing`** (§7).

Tray icon: declare `<tb:TaskbarIcon>` in `MainWindow.xaml`
(`xmlns:tb="http://www.hardcodet.net/taskbar"`), set theme icons via `TrayIcon.Icon`, and style the
menu in the `ContextMenu` **`Opened`** handler — Hardcodet shows the menu from its own host window,
so `DynamicResource` may not resolve there; use direct assignment / `TemplateBinding`.

## 6. Localization

`Strings/{en,zh-Hans,zh-Hant}.json`, copied to the output `Strings/` folder, hot-editable at
runtime. `Localization.Init()` (in `App.OnStartup`, before any window) builds a candidate list from
the OS UI culture (full name → underscore → two-letter → script names → `en`). Adding a language is
a new `<lang>.json`, no code change. Invalid JSON ⇒ `HasLanguageError` ⇒ bilingual MessageBox and
English fallback. XAML uses `{l:Loc Key}`; code uses `Localization.Get("Key")`. Missing keys render
as the key itself. **No runtime hot-swap** — changing language needs a restart. JSON must stay
**UTF-8 without BOM**. Key prefixes: `Main_` / `Menu_` / `Help_` / `About_` / `Info_`.

## 7. Behaviour contracts (do not regress)

- **Close button = hide to tray.** Only the tray Exit menu (and genuine external close) exits.
  Because WPF-UI 4.x dropped `CloseActionOverride`, `MainWindow.OnClosing` cancels the close and
  hides unless `shouldReallyDieNoReally` or `externalCloseReceived`; an `HwndSource` hook sets the
  latter for `WM_CLOSE` / `WM_QUERYENDSESSION` / `WM_ENDSESSION` / `WM_SYSCOMMAND(SC_CLOSE)`.
  The explicit `Application.Shutdown()` lives in **`OnClosed`**, not `OnClosing` — putting it in
  `OnClosing` turns "hide" into "exit"; removing it entirely leaves a zombie process
  (`ShutdownMode=OnExplicitShutdown`).
- **Settings file**: `%LocalAppData%\rtb.json` (plain runs) or the app's `RoamingFolder` under
  MSIX (via `DesktopBridge.Helpers` / `IsRunningAsUWP()`). Never move it without a migration that
  copies (not moves) the old file.
- **Log file**: `%LocalAppData%\rtb.log` via `Interaction.AddLog` (body enabled, failures
  swallowed). Diagnostic lines must be `VerboseLogging`-gated **and throttled** (see §8).
- **On clean exit** every taskbar is reset (region removed, layered/transparent styles cleared) so
  the taskbar returns to normal. A killed process leaves the region behind — verify a clean run.
- **`FillOnTaskSwitch` / `IsAltTabOverlayOpen`**: the Alt+Tab / Task View overlay on modern Win11
  is **work-area sized** (its bottom edge sits on the taskbar's top edge) and therefore does NOT
  cover the taskbar rect. Any check requiring "overlay covers the taskbar" fails and the taskbar
  stays in dynamic mode. Keep the three-condition form (foreground host window — island or visible
  full-screen `Windows.UI.Core.CoreWindow` — covering work area/taskbar; enumerated island; 200 ms
  grace). `Windows.UI.Core.CoreWindow` is a generic UWP host with resident full-screen instances, so
  it must be combined with "is foreground".
- Tray icon theme mapping stays as R3.1: light taskbar → black icon, dark → white, decided from the
  registry `AppsUseLightTheme` (WPF-UI's own theme getter was observed to be inverted).

## 8. Performance / resource rules (hard-won)

Long sessions previously made Explorer sluggish. These rules exist because of measured causes:

- **Release COM objects from UI Automation.** `GetTrueTaskbarContentBounds` calls
  `FindAll(TreeScope.Descendants)`, materialising an `AutomationElement` (RCW) per taskbar
  descendant — hundreds — and it runs on the ~1 s tick and before every dynamic region replay.
  Release the collection and each element in a `finally` (`Marshal.IsComObject`-guarded). Unreleased
  RCWs accumulate for the whole session.
- **Delete GDI regions.** Every temporary region is `DeleteObject`'d; only the region handed to
  `SetWindowRgn` stays owned by the system. Omitting this leaks region handles until
  `OutOfMemoryException` in the WPF render pipeline.
- **Never log per frame.** `AddLog` opens and closes the log file on every call. Gate diagnostics by
  `ChannelInfo.VerboseLogging` **and** throttle them (state-transition-only, or 1-in-N ticks).
  Writing a line per 100 ms tick or per region replay is a real regression.
- **Cache expensive detections.** `IsAltTabOverlayOpen`'s window-enumeration branch is cached for
  250 ms — overlay UIs persist for hundreds of ms, so detection is unaffected while steady-state
  cost drops sharply. Don't call `TaskbarShouldBeFilled` a second time just to log its result.
- Prefer not to enumerate all top-level windows in the hot loop at all (it is done for the
  single-instance "settings request" check, throttled to ~3 s).

## 9. Windows 11 version-specific gotchas

- Use the **registry** build number, never `Environment.OSVersion` — on .NET (Core) it returns the
  compatibility version (9600) and the Win11 checks silently fail.
- `CheckIfCentred` tolerates a missing `TaskbarAl` value (defaults to centred on Win11).
- The tray window's Y rect offset differs on Win11 22H2+; hover detection uses the taskbar's own Y
  range plus the tray's X range.
- Alt+Tab / Task View overlays: see §7. `XamlExplorerHostIslandWindow` is also used by resident
  tray/widgets islands and desktop XAML windows, so a class-name-only check produces false
  positives — combine it with a geometry check.

## 10. Testing & verification (no test suite)

- There is **no** automated test project. Verify by building all three channels:
  ```bash
  for ch in Canary Dev Master; do dotnet build RoundedTB/RoundedTB.csproj -c Release -p:Channel=$ch -v quiet; done
  ```
  All must report 0 errors.
- **The maintainer runs the app and observes the UI himself.** Do not drive the GUI or rely on
  screenshots — instrument the log (`AddLog`, `VerboseLogging`) and hand him a short repro
  checklist instead. He answers multiple-choice questions as compact letter strings.
- **Always launch the `net10.0-windows10.0.19041` build**, and make sure the old process is gone
  first (it locks the exe; build then fails with MSB3021/MSB3027).
- Taskbar state is checkable without a screenshot: `GetWindowRgn(FindWindow("Shell_TrayWnd"))` —
  `0` = no region (RoundedTB not applied / cleanly exited), non-zero = region applied. Useful to
  confirm "is it actually working" and "did it clean up on exit".
- Because a forced kill leaves the taskbar region behind, prefer clean exits when testing.

## 11. Current known gaps / TODO (as of R4.1.3 + R5 migration)

- **CI and `build.bat` still reference `net8.0`** (SDK `8.0.x`, output path in the CI rename step
  and in `build.bat`'s success message) while the project targets `net10.0`. Needs updating.
- **R5 regression triage in progress**: after the WPF-UI 4.3.0 migration, reported issues are
  (a) close button exiting the app instead of hiding, and (b) text/layout scaling problems in the
  settings window and its taskbar-stand-in buttons. Check these first before adding features.
- Winget manifests under `winget/4.1.3/` still carry placeholder SHA256 sums; fill them after the
  release assets are uploaded. Installers are unsigned (SmartScreen warning) — a signing hook is
  left in `Installer/RoundedTB.iss`.
- Rounded corners use a 1-bit region bitmap (no anti-aliasing) — a Windows `SetWindowRgn` limit.
  Real smoothing would need a `WS_EX_LAYERED` self-drawn alpha bitmap (large render rework).
- Deferred features: per-segment hiding, configurable dynamic-mode edge padding, R5 Part 3 cleanup
  (drop `System.Windows.Forms.Application.DoEvents`, event-based single instance, dead code).
- Long-session Explorer sluggishness: the UIA/COM + logging causes found in R5 are fixed, but the
  maintainer wants a long soak test before closing it out.

## 12. Conventions

- Commit prefixes: `fix:` / `feat:` / `docs:` / `chore:`. Keep existing attribution when porting
  code from other forks (e.g. gniang — `Co-Authored-By`).
- Comments in this repo are Chinese; keep that style when editing existing code.
- Ask before large refactors or anything touching taskbar geometry; the maintainer prefers a plan
  confirmed up front (`先规划、确认后再动手`).
- Never push this repo's contents to a public platform without explicit instruction.
