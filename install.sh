#!/bin/bash
# 启用严格模式：管道失败或命令非零返回即刻终止
export SET_CMD="set -eo pipefail"
$SET_CMD

# 动态解析用户沙盒环境
export USER_NAME="${SUDO_USER-$USER}"
export USER_HOME=$(eval echo ~"$USER_NAME")
export MONKEY_NEXT_PATH="$USER_HOME/.MonkeyDev"
export THEOS_PATH="$MONKEY_NEXT_PATH/theos"
export XCODE_TPL_PATH="$USER_HOME/Library/Developer/Xcode/Templates/MonkeyDev"
export SCRIPT_NAME="${0##*/}"
export REMOTE_REPO="https://github.com/kshipeng/MonkeyDev-Next.git"

# 环境标记边界（确保绝对幂等性与精准剥离）
MARKER_START="# >>> MonkeyDev-Next Environment >>>"
MARKER_END="# <<< MonkeyDev-Next Environment <<<"

export PROFILE_FILES=("$USER_HOME/.zshrc" "$USER_HOME/.bash_profile" "$USER_HOME/.bashrc" "$USER_HOME/.profile")

function panic() {
    local exitCode=$1
    shift
    echo "[致命异常] $@" >&2
    exit "$exitCode"
}

function get_target_profile() {
    for f in "${PROFILE_FILES[@]}"; do
        if [[ -f "$f" ]]; then
            echo "$f"
            return
        fi
    done
    touch "$USER_HOME/.zshrc"
    echo "$USER_HOME/.zshrc"
}

function manage_environment() {
    local action=$1
    local target_profile=$(get_target_profile)

    if grep -q "$MARKER_START" "$target_profile" 2>/dev/null; then
        sed -i.bak "/^$MARKER_START/,/^$MARKER_END/d" "$target_profile"
        rm -f "${target_profile}.bak"
    fi

    if [[ "$action" == "inject" ]]; then
        cat <<EOF >> "$target_profile"
$MARKER_START
export MonkeyDevPath="$MONKEY_NEXT_PATH"
export THEOS="\$MonkeyDevPath/theos"
export PATH="\$THEOS/bin:\$MonkeyDevPath/bin:\$PATH"
$MARKER_END
EOF
        echo "[系统状态] 环境变量已挂载至: $target_profile"
    else
        echo "[系统状态] 环境变量挂载已被剥离: $target_profile"
    fi
}

# 核心资产准备器（兼容本地与远程执行）
function prepare_assets_if_needed() {
    if [[ ! -d "bin" ]] || [[ ! -d "Templates" ]]; then
        echo "[执行序列] 检测到远程执行模式，正在拉取 MonkeyDev-Next 核心资源..."
        export STAGING_DIR=$(mktemp -d)
        git clone --depth 1 "$REMOTE_REPO" "$STAGING_DIR" || panic 3 "远程资源拉取失败，请检查网络"
        cd "$STAGING_DIR"
    fi
}

function cleanup_staging() {
    if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
        echo "[执行序列] 清理临时沙盒..."
        rm -rf "$STAGING_DIR"
    fi
}

function action_install() {
    prepare_assets_if_needed
    
    echo "[执行序列] 初始化 MonkeyDev-Next 隔离空间..."
    mkdir -p "$MONKEY_NEXT_PATH" || panic 1 "沙盒目录创建失败"

    for dir in bin Tools include Resource Librarys Frameworks MFrameworks; do
        [[ -d "$dir" ]] && cp -rf "$dir" "$MONKEY_NEXT_PATH/"
    done
    
    chmod +x "$MONKEY_NEXT_PATH"/bin/* 2>/dev/null || true
    chmod +x "$MONKEY_NEXT_PATH"/Tools/* 2>/dev/null || true

    echo "[执行序列] 检测并部署 Theos 编译引擎..."
    if [[ ! -d "$THEOS_PATH" ]]; then
        echo "  -> 触发子模块静默拉取..."
        git clone --recursive https://github.com/theos/theos.git "$THEOS_PATH" || panic 2 "Theos 工具链拉取失败"
    else
        echo "  -> Theos 引擎已就绪"
    fi

    echo "[执行序列] 挂载 Xcode 模板..."
    mkdir -p "$XCODE_TPL_PATH"
    rm -rf "${XCODE_TPL_PATH:?}"/*
    [[ -d "Templates" ]] && cp -rf Templates/* "$XCODE_TPL_PATH/"

    manage_environment "inject"
    cleanup_staging
    echo "[生命周期] 安装完成。请执行 'source $(get_target_profile)' 或重启终端以激活引擎。"
}

function action_uninstall() {
    echo "[执行序列] 启动彻底销毁进程..."
    
    rm -rf "$MONKEY_NEXT_PATH"
    echo "  -> 沙盒核心组件已被抹除"

    if [[ -d "$XCODE_TPL_PATH" ]]; then
        rm -rf "$XCODE_TPL_PATH"
        echo "  -> Xcode 模板已被抹除"
    fi

    manage_environment "remove"
    echo "[生命周期] 卸载完成。系统已恢复纯净状态（已安全保留 Theos 以防重下，如需彻底清除请手动 rm -rf $THEOS_PATH）。"
}

function action_update() {
    echo "[执行序列] 触发核心组件热更新..."
    
    # 强制进入远程拉取模式以确保获取到云端最新版本
    export STAGING_DIR=$(mktemp -d)
    git clone --depth 1 "$REMOTE_REPO" "$STAGING_DIR" || panic 3 "远程更新资源拉取失败"
    cd "$STAGING_DIR"
    
    for dir in bin Tools include Resource Librarys Frameworks MFrameworks; do
        if [[ -d "$dir" ]]; then
            rm -rf "$MONKEY_NEXT_PATH/$dir"
            cp -rf "$dir" "$MONKEY_NEXT_PATH/"
        fi
    done
    chmod +x "$MONKEY_NEXT_PATH"/bin/* 2>/dev/null || true
    chmod +x "$MONKEY_NEXT_PATH"/Tools/* 2>/dev/null || true

    [[ -d "Templates" ]] && {
        rm -rf "${XCODE_TPL_PATH:?}"/*
        cp -rf Templates/* "$XCODE_TPL_PATH/"
    }

    if [[ -d "$THEOS_PATH/.git" ]]; then
        echo "  -> 检测到 Theos 引擎，执行增量更新..."
        git -C "$THEOS_PATH" pull origin master || echo "[警告] Theos 更新失败，跳过"
        git -C "$THEOS_PATH" submodule update --init --recursive
    fi

    manage_environment "inject"
    cleanup_staging
    echo "[生命周期] 核心模块与模板已更新至最新基线。"
}

# 路由分发器（兼容传参处理）
case "$1" in
    install|i|"")
        action_install
        ;;
    uninstall|rm)
        action_uninstall
        ;;
    update|u)
        action_update
        ;;
    *)
        echo "使用方法: bash <(curl -fsSL https://raw.githubusercontent.com/kshipeng/MonkeyDev-Next/master/install.sh) {install | update | uninstall}"
        exit 1
        ;;
esac
exit 0
