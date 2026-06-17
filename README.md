# Mac Env Manager

Mac Env Manager 是一个原生 SwiftUI macOS 工具，用来管理 zsh/bash 的 shell 环境变量和 PATH。应用默认使用中文界面，变量名、文件路径和 shell 命令保持原样显示。

## 功能

- 通过 `~/.mac-env-manager/env.sh` 管理环境变量。
- 在 zsh/bash 配置文件中安装工具自有的 source block。
- 支持接管简单的 `export NAME=value` 或 `NAME=value` 行。
- 提供结构化 PATH 编辑、重复项检测、缺失路径提示和来源行显示。
- 写入前显示变更预览，并在 `~/.mac-env-manager/backups/` 创建时间戳备份。
- 默认明文显示变量值，可标记疑似敏感变量。
- 内置“修复已损坏应用”工具，可移除 macOS quarantine 隔离属性。

暂不支持：`launchctl` 图形应用环境、项目级 `.env`、多配置档切换、App Store 沙盒、自动刷新 Terminal/iTerm 会话。

## 安装

从 GitHub Releases 下载 `Mac.Env.Manager.zip`，解压后把 `Mac Env Manager.app` 拖到“应用程序”文件夹。

当前发布包是本地 ad-hoc 签名，未做 Apple Developer ID 公证。如果 macOS 提示“已损坏”或“无法验证开发者”，可以：

1. 打开应用内“工具”页，选择需要修复的 `.app` 并执行修复。
2. 或运行压缩包中的 `Fix Damaged App.command`。
3. 或在终端手动执行：

```sh
sudo xattr -rd com.apple.quarantine "/Applications/Mac Env Manager.app"
```

## 使用说明

1. 打开应用后，先查看“变量”和“PATH”页面。
2. 修改变量或 PATH 后，底部会出现待写入提示。
3. 点击“查看变更”确认将修改的文件。
4. 点击“写入文件”应用更改。
5. 写入后按提示在 shell 中运行 `source ...`，让当前会话生效。

## 构建

```sh
swift test
swift build
swift run MacEnvManager
```

生成本地 `.app`：

```sh
chmod +x scripts/build-app.sh
scripts/build-app.sh
open ".build/Mac Env Manager.app"
```

生成可分发 zip：

```sh
chmod +x scripts/package-app.sh
scripts/package-app.sh
```

安装包会输出到：

```text
dist/Mac Env Manager.zip
```

## 测试

核心测试使用临时 fake home 目录，不会写入真实用户目录。

```sh
swift test
```
