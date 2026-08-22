# RoundedTB Revived - winget manifest drafts

布局遵循 microsoft/winget-pkgs 现行规范(ManifestVersion 1.12.0,三文件拆分:
version / installer / locale)。

## 目录结构

```
winget/
├── README.md
└── 4.1.2/
    ├── linlinger.RoundedTBRevived.yaml                 # version manifest(版本/默认语言)
    ├── linlinger.RoundedTBRevived.installer.yaml       # installer manifest(架构/URL/SHA256/AppId)
    ├── linlinger.RoundedTBRevived.locale.en-US.yaml    # English locale
    └── linlinger.RoundedTBRevived.locale.zh-CN.yaml    # 简体中文 locale
```

## 提交 PR 的步骤(安装器发布后)

1. 计算各安装器的真实 SHA256:
   ```powershell
   Get-FileHash release\RoundedTB-R4.1.2-win-x64-setup.exe -Algorithm SHA256
   # 同理 x86 / arm64
   ```
   替换 `*.installer.yaml` 里的 `<sha256-*>` 占位符。

2. 把 `4.1.2/` 目录内容放到 winget-pkgs 仓库的对应布局并提交 PR:
   ```
   manifests/l/linlinger/RoundedTBRevived/4.1.2/
   ```
   (winget-pkgs 按 publisher 首字母分目录:`l` 下是 linlinger。)

3. 确认 GitHub Release 标签 `R4.1.2` 已发布,且三个 `-setup.exe` 文件名与
   installer manifest 里的 `InstallerUrl` 完全一致。

4. 本地校验(可选,需要 winget 已装):
   ```
   winget validate winget/4.1.2
   ```

## 备注

- **ProductCode** 用 Installer/RoundedTB.iss 里的 AppId GUID,保证 winget 识别
  升级(同一 AppId 的安装器会被视为同一产品的更新)。
- **Scope: user** — 与 iss 的 `PrivilegesRequired=lowest` 一致(每用户安装,无 UAC)。
- **MinimumOSVersion 10.0.14393.0** — Windows 10 1607,与 iss 的 `MinVersion` 一致。
- 每发一个新版本 = 新增一个 `<version>/` 目录,旧版本目录保留。
- 参考: https://github.com/microsoft/winget-pkgs/blob/master/docs/ValidatorRules.md
