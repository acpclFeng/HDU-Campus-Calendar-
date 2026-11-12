# 课程日历 · 安卓独立版 一键脚本
# 功能：检查 Flutter → 生成 android/ 骨架 → 覆盖清单 → 装依赖 → 打 release APK
# 用法：双击「一键生成并打包.bat」，或在本目录运行
#       powershell -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Write-Step($text) { Write-Host "`n>>> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "    $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "    $text" -ForegroundColor Yellow }

Write-Host "课程日历（安卓独立版）打包助手" -ForegroundColor White
Write-Host "项目目录：$Root" -ForegroundColor DarkGray

# ---- 1. 检查 Flutter ----
Write-Step "1/5 检查 Flutter SDK"
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Host @"

  没有检测到 flutter 命令。请先安装 Flutter SDK（只做一次）：

  1) 下载 Windows 版 Flutter SDK：
       https://docs.flutter.dev/get-started/install/windows
  2) 解压到不含中文和空格的路径，例如 C:\flutter
  3) 把 C:\flutter\bin 加到系统 PATH（设置 → 环境变量 → Path → 新建）
  4) 重开一个 PowerShell 窗口，运行： flutter doctor
  5) 按 doctor 提示装好 Android Studio + Android SDK，再回来双击本脚本

  注意：iOS 版必须在苹果电脑上打包，Windows 做不到，见 iphone/ 目录说明。
"@ -ForegroundColor Yellow
    exit 1
}
& flutter --version
Write-Ok "Flutter 已就绪"

# ---- 2. 生成安卓骨架 ----
Write-Step "2/5 生成安卓工程骨架（不会覆盖已有的 lib/ 与 pubspec.yaml）"
if (-not (Test-Path (Join-Path $Root "android\app\src\main\AndroidManifest.xml"))) {
    & flutter create --platforms=android --org cn.hdu `
        --project-name campus_calendar_android --android-language kotlin .
    if ($LASTEXITCODE -ne 0) { Write-Host "flutter create 失败" -ForegroundColor Red; exit 1 }
    Write-Ok "骨架已生成"
} else {
    Write-Ok "骨架已存在，跳过"
}

# ---- 3. 覆盖清单（加 INTERNET 权限）----
Write-Step "3/5 写入网络权限与 App 名称"
$src = Join-Path $Root "native-config\AndroidManifest.xml"
$dst = Join-Path $Root "android\app\src\main\AndroidManifest.xml"
if ((Test-Path $src) -and (Test-Path (Split-Path -Parent $dst))) {
    Copy-Item -Path $src -Destination $dst -Force
    Write-Ok "AndroidManifest.xml 已覆盖（INTERNET 权限已加上）"
} else {
    Write-Warn "找不到骨架清单，请手动复制 native-config\AndroidManifest.xml"
}

# ---- 4. 图标 ----
Write-Step "4/5 应用图标"
$icon512 = Join-Path $Root "..\pwa\icons\512.png"
$mipmap = Join-Path $Root "android\app\src\main\res\mipmap-xxxhdpi"
if ((Test-Path $icon512) -and (Test-Path $mipmap)) {
    Copy-Item -Path $icon512 -Destination (Join-Path $mipmap "ic_launcher.png") -Force
    Write-Ok "图标已替换"
} else {
    Write-Warn "图标跳过（不影响打包）"
}

# ---- 5. 依赖 + 打包 ----
Write-Step "5/5 安装依赖并打 release APK"
& flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "依赖安装失败" -ForegroundColor Red; exit 1 }
& flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n打包失败。常见原因见 docs\05-打包报错排查.md" -ForegroundColor Red
    exit 1
}

$apk = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
Write-Host "`n============================================" -ForegroundColor Green
Write-Host " 打包完成！APK 在这里：" -ForegroundColor Green
Write-Host " $apk" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Green
Write-Host @"

把 app-release.apk 拷到手机（微信/QQ 传文件、数据线都行），点开安装即可。
首次打开只需粘贴一次杭电助手令牌，之后打开直接用，没有 PIN、不用电脑。

想装到真机测试：手机开「开发者选项 → USB 调试」，数据线连电脑后运行
    flutter install
"@ -ForegroundColor Gray
