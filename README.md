[简体中文](README.md) | [English](README.en.md)

# Desktop Sentry（桌面哨兵）

Desktop Sentry 是一款本地优先的 macOS 菜单栏工具，用于管理日历、待办、常用提示词和本地
AI Skill 索引。它使用 Swift 和 SwiftUI 开发，不需要 Xcode 工程。

当前源码版本：**2.0.3 build 23**。

设置页和日历页脚会显示完整版本号、构建号和日历代际；源码构建版还会显示 Git 修订号和预览标记，
方便在反馈问题时确认准确版本。

## 主要功能

这一部分用来说明软件目前能够完成哪些事情。

- 原生 macOS 菜单栏提示词入口和独立日历入口
- 日历与每日待办工作台，支持把待办拖到指定日期
- 待办说明、可选提醒、完成、恢复和删除
- 常用提示词与可自定义的快捷菜单
- 本地 `SKILL.md` 发现、搜索、分类和收藏
- 跟随系统、浅色和深色三种日历外观
- 可选开机启动和 macOS 原生通知
- 本地 JSON 数据存储，无账号、无云服务

## 系统要求

这一部分用来说明构建软件需要的 macOS 版本和开发工具。

- macOS 14 或更高版本
- Xcode Command Line Tools，其中需要包含 `swiftc`
- 用于下载仓库的 Git

如果尚未安装命令行工具，请运行：

```bash
xcode-select --install
```

## 从源码快速安装

这一部分提供从下载源码到打开软件的最短步骤。

```bash
git clone https://github.com/langyougoudaner/desktop-sentry-new.git
cd desktop-sentry-new
bash install-from-source.sh
```

安装脚本会编译 APP、验证临时签名、复制到 `~/Applications/DesktopSentry.app`，然后打开它。
如果目标位置已有同名 APP，脚本会拒绝覆盖。如需安装到其他目录，可先设置
`DESKTOP_SENTRY_INSTALL_DIR`。

因为 APP 会直接在用户的 Mac 上编译，所以不需要 Apple Developer 证书，也不需要下载预编译安装包。

## 只构建，不安装

这一部分供希望只编译和测试、不写入应用目录的开发者使用。

```bash
bash build.sh
open build/DesktopSentry.app
```

`build.sh` 显式列出所有生产 Swift 文件，并直接调用 `swiftc`。项目没有 `.xcodeproj`、
Swift Package 清单或 workspace；新增生产 Swift 文件时，也必须将它加入脚本的 `SOURCES=(...)` 列表。

## 隐私说明

这一部分用来说明哪些数据只留在 Mac 上，以及哪些信息绝对不会上传。

Desktop Sentry 没有账号、分析、遥测或网络服务。待办、提示词、剪贴板历史、设置、提醒和 Skill 元数据
都保留在本机。完整数据边界说明请查看 [PRIVACY.md](PRIVACY.md)。

公开仓库不包含运行数据、截图、本机路径、凭据、备份或已编译 APP。

## 项目结构

这一部分帮助开发者了解顶层目录和文件分别负责什么。

```text
Sources/        应用程序源码
Resources/      可重新生成的应用图标资源
Tests/          独立 Swift 冒烟检查
Tools/          构建和隐私检查工具
Info.plist      macOS 应用元数据
build.sh        可复现的源码构建脚本
```

## 源码安装注意事项

这一部分记录从源码构建时可能让人困惑的运行特征。

- 软件是菜单栏工具（`LSUIElement=true`），因此不会出现在 Dock 栏中。
- 源码构建使用临时签名，适合直接在将要运行它的 Mac 上编译。
- 应用数据保存在仓库之外、当前用户的 Application Support 目录中。
- 构建产物、本地数据、截图、日志、归档和凭据都会被 `.gitignore` 和推送前隐私检查排除。

## 开源许可证

这一部分用来说明其他人可以如何使用、修改和再分发源码。

Desktop Sentry 使用 [MIT License](LICENSE)开源。
