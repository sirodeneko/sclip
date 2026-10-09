# sclip（macOS 剪切板历史）

## 运行（开发态）

```bash
cd mac-clipboard-app
swift run
```

## 打包成 .app（用于签名/权限/开机自启）

```bash
cd mac-clipboard-app
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

架构（Intel/amd64 = x86_64）：

```bash
# 只打 Intel(x86_64) 包（在 Apple Silicon 上也可用）
ARCHS=x86_64 ./scripts/build_app.sh

# 打 universal2（同时支持 arm64 + x86_64，推荐对外分发）
ARCHS=universal2 ./scripts/build_app.sh
```

## 图标设置 
- 准备 AppIcon.icns （推荐用 1024×1024 PNG 生成：建立 AppIcon.iconset 放入不同尺寸 PNG，然后运行 iconutil -c icns AppIcon.iconset ）。
- 把生成的文件放到：
 Sources/mac-clipboard-app/AppResources/AppIcon.icns
- 重新打包即可（脚本会拷贝图标并重签名）
- 图标键已写入 Info.plist（ CFBundleIconFile = AppIcon ）： Info.plist
- 打包脚本会拷贝 AppIcon.icns 到 Contents/Resources ： build_app.sh

## 键盘水平滚动（全局）

在**任意应用**（浏览器宽网页/宽表格、表格软件等）里，无需去窗口底部找横向滚动条：

1. 把鼠标指针悬停在想要滚动的内容上；
2. 按 `⇧←` / `⇧→`：左右滚动，按住可连续滚动。App 会在 HID 层合成与触控板两指横滑**完全相同**的系统级滚动事件（`scrollWheel`，像素级 continuous），发给鼠标悬停的前台应用，所以行为和触控板横滑一致。
3. 加按 `⌥`：快速滚动。

防冲突设计：

- 焦点位于文本输入框/搜索框/文本域时，按键自动放行，保留选词、光标移动等原行为。
- 快捷键可在「设置 → 全局水平滚动」中自定义（录入时按下新的组合键即可，`⎋` 取消）。若与某个应用的快捷键冲突，换一个组合即可。

说明：该功能依赖**辅助功能权限**（用于安装全局事件拦截）；授权后即刻生效，无需重启。

## 权限

- 光标位置弹出、选择后自动粘贴依赖“辅助功能”授权：
  系统设置 → 隐私与安全性 → 辅助功能 → 勾选 sclip（或你打包后的 App 名称）

## 开机自启

- 运行在 .app 形态时，菜单栏提供“开机自启”开关。
