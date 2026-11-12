# 课程日历 · 安卓 APK 云端编译

这个仓库用来**在云端自动编译「课程日历」安卓安装包**，你的电脑上一个工具都不用装。

## 怎么拿 APK

1. 打开本仓库右侧的 **Releases** 页面
2. 找到最新一条（标题形如「课程日历 APK · 自动编译 #1」）
3. 下载 `app-release.apk`
4. 传到手机（微信 / QQ 传文件、数据线都行）→ 点开安装 → 首次允许「未知来源」
5. 首次打开粘贴一次杭电助手个人访问令牌，之后打开即用，没有 PIN、不用电脑

> 推送代码后 Actions 会自动编译一次，约 8～15 分钟。
> **编译完成才会出现 Release**；如果 Releases 是空的，去 Actions 页看进度。

## 想重新编译

Actions → 左侧「编译课程日历 APK」→ **Run workflow** → 等新的 Release。

## 仓库里有什么

| 路径 | 作用 |
|---|---|
| `lib/` | Flutter / Dart 源码：月历·周历·日详情、校历换算、接口直连、令牌加密保存 |
| `pubspec.yaml` | 依赖（http / flutter_secure_storage / shared_preferences） |
| `native-config/AndroidManifest.xml` | 覆盖官方清单，补上 release 包必需的 `INTERNET` 权限 |
| `.github/workflows/build-apk.yml` | 云端流水线：装 Flutter → 生成 Android 骨架 → 编译 → 发 Release |

**不包含**任何令牌、PIN、密钥或课表数据。令牌只由每位使用者在自己的手机里输入并加密保存，互不可见。

## 本机自己打包（可选，需要 Flutter SDK + Android Studio）

Windows 下双击 `一键生成并打包.bat`；详细说明见 `setup.ps1` 与 `native-config/README.md`。
iOS 版必须在 Mac + Xcode 上打包，Windows 做不到。
