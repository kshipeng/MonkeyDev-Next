# 🐒 MonkeyDev-Next

> 🚀 **新一代纯净版 iOS 逆向开发环境**
>
> 本项目是对原版 [MonkeyDev](https://github.com/AloneMonkey/MonkeyDev) 的现代化分支重构，主打**用户态非侵入式**的纯净部署体验。

## ✨ 核心特性与变更 (Features)

与原版相比，MonkeyDev-Next 实施了严格的“减法原则”，以保证宿主系统环境的绝对纯净：
* **去冗余化**：默认移除了 `RevealServer.framework` 和 `libcycript.dylib`，大幅降低了框架的初始载荷。开发者后续可根据实际工程需求按需引入。
* **隔离部署**：采用沙盒化脚本管理，不污染系统全局环境。

## 📚 使用文档 (Documentation)

MonkeyDev-Next 的核心编译逻辑与原版保持高度兼容，完整的项目结构说明与开发教程，请直接查阅原版 Wiki：
🔗 [MonkeyDev Official Wiki](https://github.com/AloneMonkey/MonkeyDev/wiki)

⚠️ Xcode 26 会自动将添加进工程目录中的文件纳入 Copy Bundle Resources，因此在 TargetApp 目录添加 App 或 ipa 后，回到 Xcode 取消对应的 Target Membership，否则包体积会倍数增大。

## 🛠 生命周期管理 (Lifecycle Management)

我们提供了基于云端的一键式状态机脚本，用于接管环境的安装、更新与卸载流程。请打开终端（Terminal）执行对应指令：

### 📦 安装 (Install)
初始化并挂载 MonkeyDev-Next 隔离空间：
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kshipeng/MonkeyDev-Next/master/install.sh) install
```

### 🔄 更新 (Update)
同步远端最新工具链与模板资产：
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kshipeng/MonkeyDev-Next/master/install.sh) update
```

### 🗑️ 卸载 (Uninstall)
精准剥离环境依赖，恢复系统至纯净状态：
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kshipeng/MonkeyDev-Next/master/install.sh) uninstall
```

#### 注：执行脚本前，请确保您的网络环境能够正常连接至 GitHub RAW 域名。
