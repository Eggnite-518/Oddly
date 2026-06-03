# Oddly

Flutter 工程目录。完整项目说明、截图与贡献指南见仓库根目录：

**[../README.md](../README.md)**

## 本地开发

```bash
flutter pub get
flutter run
```

Release APK（推荐，自动命名为 `Oddly-v版本号.apk`）：

```bash
chmod +x build_release.sh   # 首次需要
./build_release.sh
```

或手动打包后重命名：

```bash
flutter build apk --release
mv build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/Oddly-v1.0.0.apk
```

环境变量配置见根目录 README 的「快速开始」章节。
