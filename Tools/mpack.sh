#!/bin/bash
# 严格获取沙盒环境变量
MONKEYDEV_PATH="${MonkeyDevPath:-$HOME/.MonkeyDev}"

function panic() # args: exitCode, message...
{
	local exitCode=$1
	set +e
	
	shift
	[[ "$@" == "" ]] || \
		echo "$@" >&2

	exit $exitCode
}

echo "packing..."
# environment
monkeyparser="$MONKEYDEV_PATH/bin/monkeyparser"
substrate="$MONKEYDEV_PATH/MFrameworks/libsubstitute.dylib"

#exename
TARGET_APP_PATH=$(find "$SRCROOT/$TARGET_NAME/TargetApp" -type d | grep ".app$" | head -n 1)

if [[ "$TARGET_APP_PATH" == "" ]]; then
	panic 1 "cannot find target app"
fi

APP_BINARY_NAME=`plutil -convert xml1 -o - "$TARGET_APP_PATH/Contents/Info.plist" | grep -A1 CFBundleExecutable | tail -n1 | cut -f2 -d\> | cut -f1 -d\<`
APP_BINARY_PATH="$TARGET_APP_PATH/Contents/MacOS/$APP_BINARY_NAME"

# restoresymbol
if [[ ! -f "$APP_BINARY_PATH".symbol ]]; then
    # 直接调用独立的 restoresymbol 工具
    # 假设 restoresymbol 位于环境变量 PATH 中或 ~/.MonkeyDev/bin/ 下
    RESTORE_BIN=$(which restore-symbol || echo "$MONKEYDEV_PATH/bin/restore-symbol")
    if [[ -x "$RESTORE_BIN" ]]; then
        "$RESTORE_BIN" "$APP_BINARY_PATH" -o "$APP_BINARY_PATH"_with_symbol
        mv "$APP_BINARY_PATH"_with_symbol "$APP_BINARY_PATH"
        echo "restore-symbol" >> "$APP_BINARY_PATH".symbol
    else
        echo "⚠️ 警告: 未找到 restore-symbol 工具，跳过符号还原。"
    fi
fi

# unsign: 剥离签名
if [[ ! -f "$APP_BINARY_PATH".unsigned ]]; then
    codesign --remove-signature "$APP_BINARY_PATH"
    echo "unsigned" >> "$APP_BINARY_PATH".unsigned
fi

#insert dylib
BUILD_DYLIB_PATH="$BUILT_PRODUCTS_DIR/lib$TARGET_NAME.dylib"

if [[ ! -f "$APP_BINARY_PATH".insert ]]; then
	cp -rf "$substrate" "$TARGET_APP_PATH/Contents/MacOS/"
	"$monkeyparser" install -c load -p "@executable_path/lib$TARGET_NAME.dylib" -t "$APP_BINARY_PATH"
	echo "insert" >> "$APP_BINARY_PATH".insert
fi

cp -rf "$BUILD_DYLIB_PATH" "$TARGET_APP_PATH/Contents/MacOS/"

chmod +x "$APP_BINARY_PATH"

"$APP_BINARY_PATH"
