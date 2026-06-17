# Mac Env Manager Pro 功能设计

## 目标

在不处理分发能力的前提下，把 Mac Env Manager 从“环境变量编辑器”扩展为“Mac 开发环境诊断与修复工具”。应用需要覆盖全局 shell 环境、GUI 应用环境、项目级 `.env`、敏感值管理、环境模板向导，以及可确认的一键安装流程。

## 非目标

- 不做 Apple Developer ID 签名、公证、DMG、App Store 沙盒和自动更新。
- 不静默执行安装命令；所有安装和修复操作必须先展示命令、影响和风险。
- 不强行修改用户项目代码；项目级文件写入必须经过预览和确认。
- 不自动刷新已经运行的 Terminal、iTerm、VS Code 或其他 GUI 应用。

## 功能范围

### 环境诊断

新增“诊断”页面，聚合当前 shell 配置、PATH、GUI 环境和项目环境的检查结果。诊断项至少包含：

- PATH 重复项和不存在路径。
- 常见开发工具是否可用：`brew`、`node`、`python3`、`java`、`go`、`rustc`、`adb`。
- shell 环境与 GUI 应用环境的差异。
- 代理变量是否成组存在：`http_proxy`、`https_proxy`、`all_proxy`。
- 疑似敏感变量是否仍明文存放。

诊断项分为信息、警告、错误三类，并提供可执行建议。建议可以跳转到模板向导、变量详情、PATH 详情或工具页。

### GUI 应用环境

新增“GUI 环境”页面，管理 Finder、Dock、VS Code 等 GUI 应用通过 launchd 继承的环境变量。首版支持：

- 读取当前 `launchctl getenv NAME` 的结果。
- 生成并执行 `launchctl setenv NAME value`。
- 生成并执行 `launchctl unsetenv NAME`。
- 展示“需要重启目标应用后生效”的说明。
- 提供可复制命令，不依赖自动刷新。

GUI 环境变量与 shell 托管变量使用同一个变量模型，但来源标记为 GUI 环境，避免误写入 shell 文件。

### 项目级 `.env`

新增“项目”页面，支持选择项目目录并扫描：

- `.env`
- `.env.local`
- `.env.development`
- `.env.production`
- `.envrc`

支持变量列表、文件来源、重复键提示、缺失值提示、变更预览和备份写入。`.envrc` 支持生成 `dotenv .env` 或 `source_env .env` 的 direnv 集成内容。

### Keychain 敏感值

新增 Keychain 服务，用于保存、读取和删除敏感变量。首版支持：

- 以服务名 `Mac Env Manager` 保存变量。
- 对 `KEY`、`TOKEN`、`SECRET`、`PASSWORD` 命名的变量提供“迁移到 Keychain”建议。
- 保留用户选择明文存储的能力。
- 生成 shell 读取示例：`security find-generic-password -s ... -a ... -w`。

如果 Keychain 操作失败，应用展示错误并保留原始明文值，不破坏现有配置。

### 模板与向导

新增“向导”页面，提供常见开发环境模板。每个模板包含：

- 需要检查的命令。
- 建议设置的变量。
- 建议添加的 PATH。
- 可选的一键安装命令。
- 应用前预览。

首版模板：

- Homebrew：检测 `/opt/homebrew/bin/brew` 和 `/usr/local/bin/brew`，缺失时提供官方安装脚本命令。
- Node：检测 `node`、`npm`、`corepack`，提供 `brew install node` 和 `corepack enable`。
- Python：检测 `python3`、`pip3`，提供 `brew install python`。
- Java：检测 `java` 和 `/usr/libexec/java_home`，提供 `brew install --cask temurin` 和 `JAVA_HOME` 设置。
- Android：检测 `adb`、`ANDROID_HOME`，提供 Android SDK PATH 模板和 `brew install --cask android-platform-tools`。
- Go：检测 `go`，提供 `brew install go` 和 `GOPATH` 模板。
- Rust：检测 `rustc`、`cargo`，提供 `curl https://sh.rustup.rs -sSf | sh`。
- 代理：生成 `http_proxy`、`https_proxy`、`all_proxy` 变量模板。

一键安装执行策略：

- 默认只生成命令预览。
- 用户确认后通过 `/bin/zsh -lc` 执行命令。
- 记录 stdout、stderr、退出码和开始/结束时间。
- 安装失败时保留输出并给出复制命令。
- 需要 sudo 的命令只展示，不自动输入密码。

## 架构

新增核心服务，保持 UI 与执行逻辑分离：

- `EnvironmentDiagnosticsService`：从快照、GUI 环境、模板检测结果生成诊断项。
- `GUIEnvironmentService`：封装 launchctl 读取、设置、删除和命令生成。
- `ProjectEnvScanner` / `ProjectEnvWriter`：扫描和写入项目环境文件。
- `KeychainSecretStore`：封装 macOS `security` 命令访问 Keychain。
- `EnvironmentTemplateCatalog`：提供模板定义和安装计划。
- `CommandRunner`：执行安装命令并记录结果。
- `ProEnvironmentViewModel`：承载新页面状态，避免现有 `EnvironmentViewModel` 继续膨胀。

新 UI 分区：

- 变量
- PATH
- 诊断
- GUI 环境
- 项目
- 向导
- 密钥
- 备份
- 工具

## 数据安全

- 所有文件写入继续使用备份和原子替换。
- 项目文件写入备份到项目内 `.mac-env-manager/backups/`。
- 安装命令必须可见、可复制，并需要用户按钮确认。
- Keychain 迁移不会删除原值，直到用户确认写入新 shell 代码。
- 敏感值默认仍可明文显示，符合现有产品选择。

## 测试要求

- 模板目录测试：每个模板都有检测命令、安装命令或变量/PATH 计划。
- 命令执行测试：使用 `/bin/sh -c` 的安全 fixture，不运行真实安装命令。
- GUI 环境测试：使用可注入 runner，验证 launchctl 命令生成和解析。
- 项目 `.env` 测试：解析注释、空值、重复键、引号和 `.envrc`。
- Keychain 测试：使用 fake runner 验证 `security` 命令，不访问真实 Keychain。
- 诊断测试：验证 PATH、工具缺失、代理变量、敏感变量和 GUI 差异诊断。
- ViewModel 测试：验证加载、模板选择、安装计划、命令输出和错误状态。

