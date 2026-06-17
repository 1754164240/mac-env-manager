#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/.build/Mac Env Manager.app"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_DIR="$DIST_DIR/Mac Env Manager"
ZIP_PATH="$DIST_DIR/Mac Env Manager.zip"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null

rm -rf "$PACKAGE_DIR" "$ZIP_PATH"
mkdir -p "$PACKAGE_DIR"

ditto "$APP_PATH" "$PACKAGE_DIR/Mac Env Manager.app"
xattr -cr "$PACKAGE_DIR/Mac Env Manager.app"
codesign --force --deep --sign - "$PACKAGE_DIR/Mac Env Manager.app" >/dev/null
xattr -cr "$PACKAGE_DIR/Mac Env Manager.app"

cat > "$PACKAGE_DIR/README-打开说明.txt" <<'TEXT'
Mac Env Manager 打开说明

如果 macOS 提示“Mac Env Manager.app 已损坏，无法打开”，这是因为这个本地构建版本没有经过 Apple Developer ID 公证。

修复方式：
1. 先把 Mac Env Manager.app 拖到“应用程序”文件夹。
2. 双击同一文件夹里的“Fix Damaged App.command”。
3. 输入开机密码后，再打开 Mac Env Manager。

也可以在终端手动执行：
sudo xattr -rd com.apple.quarantine "/Applications/Mac Env Manager.app"

如果只是提示“无法验证开发者”，可以右键点 App，选择“打开”。
TEXT

cat > "$PACKAGE_DIR/Fix Damaged App.command" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

APP_PATH="/Applications/Mac Env Manager.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "没有找到 $APP_PATH"
  echo "请先把 Mac Env Manager.app 拖到“应用程序”文件夹，然后重新运行这个脚本。"
  read -r -p "按回车退出..."
  exit 1
fi

echo "正在移除 macOS 隔离属性：$APP_PATH"
sudo xattr -rd com.apple.quarantine "$APP_PATH"
echo "修复完成。现在可以重新打开 Mac Env Manager。"
read -r -p "按回车退出..."
SCRIPT

chmod +x "$PACKAGE_DIR/Fix Damaged App.command"

xattr -cr "$PACKAGE_DIR"
(
  cd "$DIST_DIR"
  COPYFILE_DISABLE=1 zip -qry -X "$(basename "$ZIP_PATH")" "$(basename "$PACKAGE_DIR")"
)

echo "$ZIP_PATH"
