# Mac Env Manager

Mac Env Manager 是一个原生 SwiftUI macOS 工具，用来管理和诊断 Mac 开发环境。它覆盖 zsh/bash 的 shell 环境变量、PATH、GUI 应用环境、项目级 `.env`、Keychain 密钥和常见开发环境模板。应用默认使用中文界面，变量名、文件路径和 shell 命令保持原样显示。

当前版本：`0.3.0`

## 功能

- 通过 `~/.mac-env-manager/env.sh` 管理环境变量。
- 在 zsh/bash 配置文件中安装工具自有的 source block。
- 支持接管简单的 `export NAME=value` 或 `NAME=value` 行。
- 提供结构化 PATH 编辑、重复项检测、缺失路径提示和来源行显示。
- 提供环境诊断，聚合 PATH、代理变量、敏感变量、开发工具缺失和 GUI 环境差异提示。
- 支持 GUI 应用环境命令生成和执行：`launchctl getenv`、`launchctl setenv`、`launchctl unsetenv`。
- 支持选择项目目录并扫描 `.env`、`.env.local`、`.env.development`、`.env.production`、`.envrc`。
- 支持 Keychain 密钥保存、读取、删除命令生成，并提供 shell 读取示例。
- 提供环境模板和向导：Homebrew、Node.js、Python、Java、Android、Go、Rust、代理变量。
- 模板与向导支持把变量和 PATH 加入待写入，也支持经过确认后执行一键安装命令。
- 写入前显示变更预览，并在 `~/.mac-env-manager/backups/` 创建时间戳备份。
- 默认明文显示变量值，可标记疑似敏感变量。
- 内置“修复已损坏应用”工具，可移除 macOS quarantine 隔离属性。

暂不支持：Apple Developer ID 签名、公证、DMG 安装器、App Store 沙盒、自动更新、自动刷新 Terminal/iTerm/VS Code 会话、多配置档切换。

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

## 诊断

“诊断”页面会显示当前环境中的常见问题：

- PATH 重复项。
- PATH 指向不存在的目录。
- 代理变量只配置了一部分。
- 疑似敏感变量仍在明文环境文件中。
- shell 环境和 GUI 应用环境不一致。
- 常见开发工具缺失。

诊断会通过 `command -v` 检查常见开发工具是否存在，也会纳入已读取的 GUI 环境值和已扫描项目中的重复键/空值，但不会直接修改文件。需要修复时，可以跳转到对应页面或使用模板向导加入待写入。

## GUI 应用环境

“GUI 环境”页面用于生成和执行 launchd 环境变量命令：

```sh
launchctl getenv NAME
launchctl setenv NAME value
launchctl unsetenv NAME
```

这些变量会影响从 Finder、Dock 等 GUI 入口启动的应用。修改后通常需要重启目标应用才会生效。

读取到的 GUI 环境变量会暂存在当前应用会话中，并参与“诊断”页面的 shell/GUI 差异检查。

## 项目级 `.env`

“项目”页面可以选择一个项目目录并扫描：

```text
.env
.env.local
.env.development
.env.production
.envrc
```

应用会展示变量来源、重复键和空值。`.envrc` 可使用 direnv 示例：

```sh
dotenv .env
```

项目变量可以在应用内新增或编辑。点击“生成预览”会显示 `.env` diff，点击“写入 .env”会先创建项目内备份，再原子替换目标文件。项目备份目录：

```text
<project>/.mac-env-manager/backups/
```

## Keychain 密钥

“密钥”页面可以为敏感变量生成 Keychain 命令：

```sh
security add-generic-password -U -s 'Mac Env Manager' -a 'OPENAI_API_KEY' -w 'secret'
security find-generic-password -s 'Mac Env Manager' -a 'OPENAI_API_KEY' -w
security delete-generic-password -s 'Mac Env Manager' -a 'OPENAI_API_KEY'
```

应用也会生成 shell 读取示例：

```sh
export OPENAI_API_KEY=$(security find-generic-password -s 'Mac Env Manager' -a 'OPENAI_API_KEY' -w)
```

点击密钥页的“加入待写入”会把读取示例写入托管 shell 计划。应用会保留命令替换表达式，不会把 `$(security ...)` 错误地单引号包成普通字符串。

## 模板与一键安装

“向导”页面提供常见开发环境模板：

- Homebrew
- Node.js
- Python
- Java
- Android
- Go
- Rust
- 代理变量

模板会展示将写入的变量、PATH 和安装命令。点击“加入待写入”会把模板变量和 PATH 加入现有 shell 写入计划；点击安装命令旁的“执行”才会运行命令。

安装命令通过 `/bin/zsh -lc` 或系统工具执行，执行前会显示完整命令。需要 sudo 或交互输入的命令不会静默输入密码。

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
