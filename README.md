# sclip（macOS 剪切板历史）

## 运行（开发态）

```bash
cd /Users/bytedance/go/test/mac-clipboard-app
swift run
```

## 打包成 .app（用于签名/权限/开机自启）

```bash
cd /Users/bytedance/go/test/mac-clipboard-app
chmod +x scripts/build_app.sh
./scripts/build_app.sh
open dist/sclip.app
```

可选参数：

```bash
APP_NAME=sclip \
BUNDLE_ID=com.yourcompany.sclip \
VERSION=0.1.0 \
BUILD_NUMBER=1 \
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/build_app.sh
```

## 图标设置 
- 准备 AppIcon.icns （推荐用 1024×1024 PNG 生成：建立 AppIcon.iconset 放入不同尺寸 PNG，然后运行 iconutil -c icns AppIcon.iconset ）。
- 把生成的文件放到：
 Sources/mac-clipboard-app/AppResources/AppIcon.icns
- 重新打包即可（脚本会拷贝图标并重签名）
- 图标键已写入 Info.plist（ CFBundleIconFile = AppIcon ）： Info.plist
- 打包脚本会拷贝 AppIcon.icns 到 Contents/Resources ： build_app.sh

## 权限

- 光标位置弹出、选择后自动粘贴依赖“辅助功能”授权：
  系统设置 → 隐私与安全性 → 辅助功能 → 勾选 sclip（或你打包后的 App 名称）

## 开机自启

- 运行在 .app 形态时，菜单栏提供“开机自启”开关。

