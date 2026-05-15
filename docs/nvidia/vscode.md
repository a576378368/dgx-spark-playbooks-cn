# VS Code

> 本地或远程安装和使用 VS Code

## 目录

- [概述](#概述)
- [直接安装](#直接安装)
- [通过 NVIDIA Sync 访问](#通过-nvidia-sync-访问)
- [故障排除](#故障排除)

---

## 概述

## 基本原理

本指南将帮助您设置 Visual Studio Code，这是一个功能完整的 IDE，带有扩展、集成终端和 Git 集成，同时利用您的 DGX Spark 设备进行开发和测试。使用 VS Code 有两种不同方法：

* **直接安装**：直接在基于 ARM64 的 Spark 系统上安装 VS Code 开发环境，无需远程开发开销即可在目标硬件上进行本地开发。

* **通过 NVIDIA Sync 访问**：设置 NVIDIA Sync 以通过 SSH 远程连接到 Spark，并将 VS Code 配置为您的开发工具之一。

## 您将完成的工作

您将为 DGX Spark 设备设置 VS Code 进行开发，访问系统的 ARM64 架构和 GPU 资源。此设置支持直接代码开发、调试和执行。

## 开始前需要了解

您应该具备使用 VS Code 界面和功能的基本经验；您选择的方法将需要额外的理解：

* **直接安装**：
  * 熟悉 Linux 系统上的包管理
  * 了解 Linux 上的文件权限和身份验证

* **通过 NVIDIA Sync 访问**：
  * 熟悉 SSH 概念

## 前置条件

您的 DGX Spark [设备已设置](https://docs.nvidia.com/dgx/dgx-spark/first-boot.html)。您还需要以下内容：

* **直接安装**：
  * 已设置具有管理权限的 DGX Spark
  * 活跃的互联网连接，用于下载 VS Code 安装程序

* **通过 NVIDIA Sync 访问**：
  * 在您的笔记本电脑上安装 VS Code，从 https://code.visualstudio.com/download 下载。

## 时间与风险

* **持续时间：** 10-15 分钟
* **风险级别：** 低 - 安装使用官方包，具有标准回滚
* **回滚：** 通过系统包管理器进行标准包移除
* **最后更新：** 2025 年 11 月 21 日
  * 澄清选项和小幅文字修订

## 直接安装

## 步骤 1. 验证系统要求

在安装 VS Code 之前，请确认您的 DGX Spark 系统满足要求并具有 GUI 支持。

```bash
## 验证 ARM64 架构
uname -m
## 预期输出：aarch64

## 检查可用磁盘空间（VS Code 需要约 200MB）
df -h /

## 验证桌面环境正在运行
ps aux | grep -E "(gnome|kde|xfce)"

## 验证 GUI 桌面环境可用
echo $DISPLAY
## 应返回类似 :0 或 :10.0 的显示信息
```

## 步骤 2. 下载 VS Code ARM64 安装程序

导航到 VS Code [下载](https://code.visualstudio.com/download) 页面并下载系统适用的 ARM64 `.deb` 包。

或者，您可以使用此命令下载安装程序：

```bash
wget https://code.visualstudio.com/sha/download?build=stable\&os=linux-deb-arm64 -O vscode-arm64.deb
```

## 步骤 3. 安装 VS Code 包

使用系统包管理器安装下载的包。

您可以直接点击安装程序文件或使用命令行。

```bash
## 安装下载的 .deb 包
sudo dpkg -i vscode-arm64.deb

## 如果出现依赖问题，请修复
sudo apt-get install -f
```

## 步骤 4. 验证安装

确认 VS Code 应用程序安装成功并可以启动。

您可以直接从应用程序列表打开应用程序或使用命令行。

```bash
## 检查是否安装了 VS Code
which code

## 验证版本
code --version

## 测试启动（将打开 VS Code GUI）
code &
```

VS Code 应启动并显示欢迎屏幕。

## 步骤 5. 为 Spark 开发配置

为 DGX Spark 平台设置 VS Code 进行开发。

```bash
## 如果未运行，启动 VS Code
code

## 或创建新项目目录并打开
mkdir ~/spark-dev-workspace
cd ~/spark-dev-workspace
code .
```

在 VS Code 内部：

* 打开 **文件** > **首选项** > **设置**
* 搜索"终端集成 shell"以配置默认终端
* 通过 **扩展** 标签（左侧边栏）安装推荐的扩展

## 步骤 6. 验证设置和测试功能

测试核心 VS Code 功能，确保在 ARM64 上正常运行。

创建测试文件：
```bash
## 创建测试目录和文件
mkdir ~/vscode-test
cd ~/vscode-test
echo 'print("Hello from DGX Spark!")' > test.py
code test.py
```

在 VS Code 中：

* 验证语法高亮是否正常
* 打开集成终端 (**终端** > **新建终端**)
* 运行测试脚本：`python3 test.py`
* 通过在终端中运行 `git status` 测试 Git 集成

## 步骤 8. 卸载 VS Code

> [!WARNING]
> 卸载 VS Code 将移除所有用户设置和扩展。

如果需要，卸载 VS Code：
```bash
## 移除 VS Code 包
sudo apt-get remove code

## 移除配置文件（可选）
rm -rf ~/.config/Code
rm -rf ~/.vscode
```

## 通过 NVIDIA Sync 访问

## 步骤 1. 安装和配置 NVIDIA Sync

按照 [NVIDIA Sync 设置指南](https://build.nvidia.com/spark/connect-to-your-spark/sync) 操作：

* 安装适用于您的操作系统的 NVIDIA Sync
* 配置您想要使用的开发工具（VS Code、Cursor、终端等）
* 添加您的 DGX Spark 设备，提供其主机名/IP 和凭证

NVIDIA Sync 将自动配置基于 SSH 密钥的身份验证，实现安全、无密码的访问。

## 步骤 2. 通过 NVIDIA Sync 启动 VS Code

* 单击系统托盘/任务栏中的 NVIDIA Sync 图标
* 确保设备已连接（如有需要，单击"连接"）
* 单击"VS Code"以使用自动 SSH 连接到您的 DGX Spark 启动它
* 等待远程连接建立（您的本地机器可能要求输入密码或授权连接）
* 成功 SSH 连接后首次进入主目录时，您可能会被提示"信任此文件夹中的文件作者"

## 步骤 3. 验证和后续步骤

* 验证您可以使用 VS Code 作为文本编辑器访问 DGX Spark 的文件系统
* 在 VS Code 中打开集成终端，运行测试命令如 `hostnamectl` 和 `whoami` 以确保您正在远程访问 DGX Spark
* 导航到特定文件路径或目录并开始编辑/编写文件
* 为您的开发工作流安装 VS Code 扩展（Python、Docker、GitLens 等）
* 从 GitHub 或其他版本控制系统克隆存储库
* 如有需要，配置并本地托管 LLM 代码助手

## 故障排除

| 症状 | 原因 | 解决方法 |
|-------|-------|-------|
| 安装期间 `dpkg: 依赖问题` | 缺少依赖 | 运行 `sudo apt-get install -f` |
| VS Code 无法启动并出现 GUI 错误 | 没有显示服务器/X11 | 验证 GUI 桌面正在运行：`echo $DISPLAY` |
| 扩展安装失败 | 网络连接或 ARM64 兼容性 | 检查互联网连接，验证扩展 ARM64 支持 |

有关最新已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。

---

*翻译完成*
