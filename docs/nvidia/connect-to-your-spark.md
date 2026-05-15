# 设置本地网络访问

> NVIDIA Sync 可帮助设置和配置 SSH 访问

## 目录

- [概述](#概述)
- [使用 NVIDIA Sync 连接](#使用-nvidia-sync-连接)
- [使用手动 SSH 连接](#使用手动-ssh-连接)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

如果您主要在另一台系统（例如笔记本电脑）上工作，并希望将 DGX Spark 作为远程资源使用，本指南将向您展示如何通过 SSH 连接和工作。通过 SSH，您可以安全地打开终端会话或进行端口转发，以从本地计算机访问 DGX Spark 上的 Web 应用和 API。

有两种方法：**NVIDIA Sync（推荐）** 用于简化设备管理，或**手动 SSH** 用于直接命令行控制。

开始之前，需要了解一些重要概念：

**安全外壳协议（SSH）** 是一种加密协议，用于通过不可信网络安全地连接到远程计算机。它允许您在 DGX Spark 上打开终端，就像您坐在设备前一样，运行命令、传输文件和管理服务——所有操作都进行端到端加密。

**SSH 隧道**（也称为端口转发）可以安全地将笔记本电脑上的端口（例如 localhost:8888）映射到 DGX Spark 上的应用监听端口（例如 JupyterLab 的 8888 端口）。您的浏览器连接到 localhost，SSH 会通过加密连接将流量转发到远程服务，而不会在更广泛的网络上暴露该端口。

**mDNS（组播 DNS）** 允许设备在本地网络上通过名称相互发现，而无需中央 DNS 服务器。您的 DGX Spark 通过 mDNS 公布其主机名，因此您可以使用 `spark-abcd.local`（注意 `.local` 后缀）这样的名称连接，而无需查找其 IP 地址。

## 您将实现的目标

您将使用 NVIDIA Sync 或手动 SSH 配置建立到 DGX Spark 设备的安全 SSH 访问。NVIDIA Sync 提供了集成应用程序启动功能的图形化设备管理界面，而手动 SSH 提供了端口转发功能的直接命令行控制。两种方法都使您能够从笔记本电脑远程运行终端命令、访问 Web 应用程序和管理 DGX Spark。

## 开始前须知

- 基本的终端/命令行使用经验
- 了解 SSH 概念和基于密钥的身份验证
- 熟悉网络概念，如主机名、IP 地址和端口转发

## 先决条件

- 您的 DGX Spark [设备已设置](https://docs.nvidia.com/dgx/dgx-spark/first-boot.html)，并且您已创建本地用户账户
- 您的笔记本电脑和 DGX Spark 在同一网络上
- 您拥有 DGX Spark 的用户名和密码
- 您拥有设备的 mDNS 主机名（印在快速入门指南上）或 IP 地址

## 时间与风险

- **时间估算：** 5-10 分钟
- **风险等级：** 低 - SSH 设置涉及凭据配置，但不会对 DGX Spark 设备进行系统级更改
- **回滚方案：** 可以通过编辑 DGX Spark 上的 `~/.ssh/authorized_keys` 来移除 SSH 密钥
- **最后更新：** 2025年10月28日
  * 少量文字编辑

---

## 使用 NVIDIA Sync 连接

## 步骤 1. 安装 NVIDIA Sync

NVIDIA Sync 是一个桌面应用程序，可通过本地网络将您的计算机连接到 DGX Spark。它为您提供了一个统一界面，用于管理 SSH 访问和在 DGX Spark 上启动开发工具。

下载并安装 NVIDIA Sync 以开始使用。

**对于 macOS**

- 下载后，打开 `nvidia-sync.dmg`
- 将应用程序拖放到 Applications 文件夹中
- 从 Applications 文件夹中打开 `NVIDIA Sync`

**对于 Windows**

- 下载后，运行安装程序 .exe
- 安装完成后，NVIDIA Sync 将自动启动

**对于 Debian/Ubuntu**

* 配置软件包仓库：

  ```
  curl -fsSL  https://workbench.download.nvidia.com/stable/linux/gpgkey  |  sudo tee -a /etc/apt/trusted.gpg.d/ai-workbench-desktop-key.asc
  echo "deb https://workbench.download.nvidia.com/stable/linux/debian default proprietary" | sudo tee -a /etc/apt/sources.list
  ```
* 更新软件包列表：

  ```
  sudo apt update
  ```
* 安装 NVIDIA Sync：

  ```
  sudo apt install nvidia-sync
  ```

## 步骤 2. 配置应用程序

应用程序是安装在您笔记本电脑上的桌面程序，NVIDIA Sync 可以配置并启动这些程序，自动连接到您的 Spark。

您随时可以在设置窗口中更改应用程序选择。标记为"不可用"的应用程序必须先安装才能使用。

**默认应用程序：**
- **DGX Dashboard**：DGX Spark 上预装的 Web 应用程序，用于系统管理和集成的 JupyterLab 访问
- **Terminal**：带有自动 SSH 连接的系统内置终端

**可选应用程序（需要单独安装）：**
- **VS Code**：从 https://code.visualstudio.com/download 下载
- **Cursor**：从 https://cursor.com/downloads 下载
- **NVIDIA AI Workbench**：从 https://www.nvidia.com/workbench 下载

## 步骤 3. 添加 DGX Spark 设备

> [!NOTE]
> 您必须知道主机名或 IP 地址才能连接。
>
> - 默认主机名可以在随附的快速入门指南中找到。例如，`spark-abcd.local`
> - 如果您的设备已连接显示器，您可以在 [DGX Dashboard](http://localhost:11000) 的设置页面找到主机名。
> - 如果网络上 `.local`（mDNS）主机名不起作用，则必须使用 IP 地址。这可以在 Ubuntu 的网络设置中找到，或通过登录路由器的管理控制台获取。

最后，填写表格连接您的 DGX Spark：

- **名称**：一个描述性名称（例如，"My DGX Spark"）
- **主机名或 IP**：Spark 的 mDNS 主机名（例如 `spark-abcd.local`）或 IP 地址
- **用户名**：您的 DGX Spark 用户账户名称
- **密码**：您的 DGX Spark 用户账户密码

> [!NOTE]
> 您的密码仅在此初始设置期间用于配置 SSH 密钥身份验证。设置完成后，密码将不被存储或传输。NVIDIA Sync 将 SSH 到您的设备并配置其本地提供的 SSH 密钥对。

点击"添加"按钮，NVIDIA Sync 将自动：

1. 在您的笔记本电脑上生成 SSH 密钥对
2. 使用您提供的用户名和密码连接到 DGX Spark
3. 将公钥添加到设备上的 `~/.ssh/authorized_keys`
4. 在本地创建 SSH 别名以供将来连接
5. 丢弃您的用户名和密码信息

> [!IMPORTANT]
> 第一次完成系统设置后，您的设备可能需要几分钟时间更新并在网络上可用。如果 NVIDIA Sync 连接失败，请等待 3-4 分钟后再试。

## 步骤 4. 访问您的 DGX Spark

连接后，NVIDIA Sync 显示为系统托盘/任务栏应用程序。点击 NVIDIA Sync 图标打开设备管理界面。

- **SSH 连接**：点击大型的"连接"和"断开连接"按钮可控制到设备的总体 SSH 连接。
- **设置工作目录**（可选）：选择通过 NVIDIA Sync 启动时应用程序将打开的默认目录。默认为远程设备上的主目录。
- **启动应用程序**：点击任何配置的应用程序以通过自动 SSH 连接到 DGX Spark 打开它。
- **自定义端口**（可选）："自定义端口"在设置屏幕中配置，以提供对设备上运行的自定义 Web 应用或 API 的访问。

## 步骤 5. 验证 SSH 设置

NVIDIA Sync 为您的设备创建 SSH 别名，以便从其他 SSH 启用的应用程序手动或轻松访问。

通过使用 SSH 别名验证您的本地 SSH 配置是否正确。使用别名时，系统不应提示您输入密码：

```bash
## 如果您使用 mDNS 主机名进行配置
ssh <SPARK_HOSTNAME>.local
```

或

```bash
## 如果您使用 IP 地址进行配置
ssh <IP>
```

在 DGX Spark 上，验证您已连接：

```bash
hostname
whoami
```

退出 SSH 会话：

```bash
exit
```

## 步骤 6. 后续步骤

通过启动开发工具测试您的设置：
- 点击 NVIDIA Sync 系统托盘图标。
- 选择 "Terminal" 在 DGX Spark 上打开终端会话。
- 选择 "DGX Dashboard" 使用 JupyterLab 和管理更新。
- 尝试 [使用 Open WebUI 的自定义端口示例](/spark/open-webui/sync)。

---

## 使用手动 SSH 连接

## 步骤 1. 验证 SSH 客户端可用性

确认您的系统上已安装 SSH 客户端。大多数现代操作系统默认包含 SSH。在终端中运行以下命令：

```bash
## 检查 SSH 客户端版本
ssh -V
```

预期输出应显示 OpenSSH 版本信息。

## 步骤 2. 收集连接信息

收集 DGX Spark 所需的连接详细信息：

- **用户名**：您的 DGX Spark 用户账户名称
- **密码**：您的 DGX Spark 账户密码
- **主机名**：您设备的 mDNS 主机名（来自快速入门指南，例如 `spark-abcd.local`）
- **IP 地址**：仅在 mDNS 在您的网络上不起作用时才需要的替代方案（如下所述）

在某些网络配置中，例如复杂的公司环境，mDNS 可能无法按预期工作，您将必须直接使用设备的 IP 地址进行连接。您会知道您处于这种情况，当您尝试 SSH 时，命令无限期挂起或您得到如下错误：

```
ssh: Could not resolve hostname spark-abcd.local: Name or service not known
```

**测试 mDNS 解析**

要测试 mDNS 是否正常工作，请使用 `ping` 工具：

```bash
ping spark-abcd.local
```

如果 mDNS 正常工作并且您可以使用主机名进行 SSH，您应该看到类似以下内容：

```
$ ping -c 3 spark-abcd.local
PING spark-abcd.local (10.9.1.9): 56 data bytes
64 bytes from 10.9.1.9: icmp_seq=0 ttl=64 time=6.902 ms
64 bytes from 10.9.1.9: icmp_seq=1 ttl=64 time=116.335 ms
64 bytes from 10.9.1.9: icmp_seq=2 ttl=64 time=33.301 ms
```

如果 mDNS **不**正常工作，表明您必须直接使用 IP 地址，您将看到类似以下内容：

```
$ ping -c 3 spark-abcd.local
ping: cannot resolve spark-abcd.local: Unknown host
```

如果以上方法均不起作用，您需要：
- 登录路由器的管理面板查找 IP 地址
- 连接显示器、键盘和鼠标以从 Ubuntu 桌面检查

## 步骤 3. 测试初始连接

首次连接到您的 DGX Spark 以验证基本连接性：

```bash
## 使用 mDNS 主机名连接（推荐）
ssh <YOUR_USERNAME>@<SPARK_HOSTNAME>.local
```

或

```bash
## 替代方案：使用 IP 地址连接
ssh <YOUR_USERNAME>@<DEVICE_IP_ADDRESS>
```

将占位符替换为您的实际值：
- `<YOUR_USERNAME>`：您的 DGX Spark 账户名称
- `<SPARK_HOSTNAME>`：不带 `.local` 后缀的设备主机名
- `<DEVICE_IP_ADDRESS>`：您的设备 IP 地址

首次连接时，您会看到主机指纹警告。输入 `yes` 并按回车，然后在提示时输入密码。

## 步骤 4. 验证远程连接

连接后，确认您在 DGX Spark 设备上：

```bash
## 检查主机名
hostname
## 检查系统信息
uname -a
## 退出会话
exit
```

## 步骤 5. 使用 SSH 隧道访问 Web 应用程序

要访问 DGX Spark 上运行的 Web 应用程序，请使用 SSH 端口转发。在此示例中，我们将访问 DGX Dashboard Web 应用程序。

> [!NOTE]
> DGX Dashboard 运行在 localhost，端口 11000。

打开隧道：

```bash
## 本地端口 11000 → 远程端口 11000
ssh -L 11000:localhost:11000 <YOUR_USERNAME>@<SPARK_HOSTNAME>.local
```

建立隧道后，在浏览器中访问转发的 Web 应用：[http://localhost:11000](http://localhost:11000)

## 步骤 6. 后续步骤

配置 SSH 访问后，您可以：
- 打开持久终端会话：`ssh <YOUR_USERNAME>@<SPARK_HOSTNAME>.local`
- 转发 Web 应用端口：`ssh -L <local_port>:localhost:<remote_port> <YOUR_USERNAME>@<SPARK_HOSTNAME>.local`

---

## 故障排除

## 通过 NVIDIA Sync 连接的可能问题

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 设备名称无法解析 | 网络上阻止 mDNS | 使用 IP 地址而不是 hostname.local |
| 连接被拒绝/超时 | DGX Spark 未启动或 SSH 未就绪 | 等待设备启动完成；更新完成后 SSH 可用 |
| 身份验证失败 | SSH 密钥设置不完整 | 重新运行 NVIDIA Sync 中的设备设置；检查凭据 |

## 通过手动 SSH 连接的可能问题

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 设备名称无法解析 | 网络上阻止 mDNS | 使用 IP 地址而不是 hostname.local |
| 连接被拒绝/超时 | DGX Spark 未启动或 SSH 未就绪 | 等待设备启动完成；更新完成后 SSH 可用 |
| 端口转发失败 | 服务未运行或端口冲突 | 验证远程服务是否激活；尝试不同的本地端口 |
