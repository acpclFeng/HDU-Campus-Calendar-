# 安卓原生配置说明（打包前照做一次）

Flutter 工程骨架由 `flutter create` 生成，本目录是**需要覆盖 / 补充**的原生配置文件。
建议直接双击项目根目录的 `一键生成并打包.bat`，脚本会自动完成下面 1–4 步。

## 1. 生成安卓工程骨架

在 `campus-calendar-mobile/android/` 目录打开 PowerShell：

```powershell
flutter create --platforms=android --org cn.hdu --project-name campus_calendar_android --android-language kotlin .
```

> `flutter create` 不会覆盖已经存在的 `lib/`、`pubspec.yaml`，只会补齐 `android/` 目录。

## 2. 覆盖清单文件

把本目录的 `AndroidManifest.xml` 复制到 `android/app/src/main/AndroidManifest.xml`。
这一步必须做：release 包默认没有 `INTERNET` 权限，不复制会导致「日历一直加载失败」。

## 3. 调整最小 SDK 与签名

打开 `android/app/build.gradle`（新版 Flutter 可能是 `build.gradle.kts`），找到
`defaultConfig` 把 `minSdk` 设为 21，`applicationId` 保持 `cn.hdu.campus_calendar_android`：

```groovy
defaultConfig {
    applicationId "cn.hdu.campus_calendar_android"
    minSdkVersion 21
    targetSdkVersion flutter.targetSdkVersion
    versionCode flutter.versionCode
    versionName flutter.versionName
}
```

正式签名（可选，但换手机/升级时更稳妥）：

```powershell
keytool -genkey -v -keystore $HOME\campus-calendar.jks -keyalg RSA -keysize 2048 -validity 10000 -alias campus
```

在 `android/key.properties` 写入（这个文件不要提交到任何仓库）：

```properties
storePassword=你的keystore密码
keyPassword=你的key密码
keyAlias=campus
storeFile=C:/Users/你的用户名/campus-calendar.jks
```

再在 `android/app/build.gradle` 的 `android {` 之前加：

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

并把 `buildTypes { release { signingConfig signingConfigs.debug } }` 换成：

```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release { signingConfig signingConfigs.release }
}
```

> 只想快点装到手机上？跳过第 3 步的签名部分即可，`flutter build apk --release` 会用默认签名生成一个能直接安装的 APK。

## 4. 图标

把 `../pwa/icons/512.png` 复制成 `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
（或用 Android Studio 的 Image Asset 生成各尺寸）。不换也能打包，只是图标是 Flutter 默认小绿人。

## 5. 打包

```powershell
flutter pub get
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`，拷到手机点一下就能装。
