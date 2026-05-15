# 在 Spark 上设置 Tailscale

> 使用 Tailscale 在家庭网络中随时随地连接你的 Spark

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
  - [步骤 1. 验证系统要求](#步骤-1-验证系统要求)
  - [步骤 2. 安装 SSH 服务器（如果需要）](#步骤-2-安装-ssh-服务器如果需要)
  - [步骤 3. 在 NVIDIA DGX Spark 上安装 Tailscale](#步骤-3-在-nvidia-dgx-spark-上安装-tailscale)
  - [步骤 4. 验证 Tailscale 安装](#步骤-4-验证-tailscale-安装)
  - [步骤 5. 将你的 DGX Spark 连接到 Tailscale 网络](#步骤-5-将你的-dgx-spark-连接到-tailscale-网络)
  - [步骤 6. 在客户端设备上安装 Tailscale](#步骤-6-在客户端设备上安装-tailscale)
  - [步骤 7. 将客户端设备连接到 tailnet](#步骤-7-将客户端设备连接到-tailnet)
  - [步骤 8. 验证网络连接](#步骤-8-验证网络连接)
  - [步骤 9. 配置 SSH 身份验证](#步骤-9-配置-ssh-身份验证)
  - [步骤 10. 测试 SSH 连接](#步骤-10-测试-ssh-连接)
  - [步骤 11. 验证安装](#步骤-11-验证安装)
  - [步骤 13. 清理和回滚](#步骤-13-清理和回滚)
  - [步骤 14. 下一步](#步骤-14-下一步)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

Tailscale 创建一个加密的点对点网状网络，允许在没有复杂防火墙配置或端口转发的情况下安全访问你的 NVIDIA DGX Spark 设备。通过在你的 DGX Spark 和客户端设备上安装 Tailscale，你建立了一个私有的"tailnet"，每个设备获得一个稳定的私有 IP 地址和主机名，使你能够无缝进行 SSH 访问，无论你是在家、工作还是在咖啡店。

## 你将实现的目标

你将在你的 DGX Spark 设备和客户端机器上设置 Tailscale，以创建安全的远程访问。完成后，你将能够从任何地方使用简单的命令（如 `ssh user@spark-hostname`）SSH 到你的 DGX Spark，所有流量自动加密，NAT 穿越自动处理。

## 开始前须知

- 使用终端/命令行界面
- 基本的 SSH 概念和使用
- 使用 Ubuntu 上的 `apt` 安装包
- 理解用户账户和身份验证
- 熟悉 systemd 服务管理

## 先决条件

**硬件要求：**
- NVIDIA Grace Blackwell GB10 Superchip 系统

**软件要求：**
- NVIDIA DGX OS
- 用于远程访问的客户端设备（Mac、Windows 或 Linux）
- 客户端设备和 DGX Spark 在测试连接时不在同一网络
- 两台设备上的互联网连接
- 用于 Tailscale 身份验证的有效电子邮件账户（Google、GitHub、Microsoft）
- SSH 服务器可用性检查：`systemctl status ssh`
- 包管理器工作正常：`sudo apt update`
- 你的 DGX Spark 设备上具有 sudo 特权的用户账户

## 时间与风险

* **持续时间**：15-30 分钟用于初始设置，每个额外设备 5 分钟
* **风险**：中等
  * 潜在的 SSH 服务配置冲突
  * 初始设置期间的网络连接问题
  * 身份验证提供程序服务依赖
* **回滚**：可以使用 `sudo apt remove tailscale` 完全删除 Tailscale，并自动将所有网络路由恢复为默认设置。
* **最后更新**：2025年11月7日
  * 小幅文字编辑

---

## 操作说明

### 步骤 1. 验证系统要求

检查你的 NVIDIA DGX Spark 设备是否运行受支持的 Ubuntu 版本并具有互联网连接。此步骤在 DGX Spark 设备上运行以确认先决条件。

```bash
## 检查 Ubuntu 版本（应为 20.04 或更高版本）
lsb_release -a

## 测试互联网连接
ping -c 3 google.com

## 验证你有 sudo 访问权限
sudo whoami
```

### 步骤 2. 安装 SSH 服务器（如果需要）

确保你的 DGX Spark 设备上正在运行 SSH 服务器，因为 Tailscale 提供网络连接，但需要 SSH 进行远程访问。此步骤在 DGX Spark 设备上运行。

```bash
## 检查 SSH 是否正在运行
systemctl status ssh --no-pager
```

**如果 SSH 未安装或未运行：**

```bash
## 安装 OpenSSH 服务器
sudo apt update
sudo apt install -y openssh-server

## 启用并启动 SSH 服务
sudo systemctl enable ssh --now --no-pager

## 验证 SSH 正在运行
systemctl status ssh --no-pager
```

### 步骤 3. 在 NVIDIA DGX Spark 上安装 Tailscale

使用官方 Ubuntu 仓库在你的 DGX Spark 上安装 Tailscale。此步骤添加 Tailscale 包仓库并安装客户端。

```bash
## 更新包列表
sudo apt update

## 安装添加外部仓库所需的工具
sudo apt install -y curl gnupg

## 添加 Tailscale 签名密钥
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | \
  sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null

## 添加 Tailscale 仓库
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | \
  sudo tee /etc/apt/sources.list.d/tailscale.list

## 使用新仓库更新包列表
sudo apt update

## 安装 Tailscale
sudo apt install -y tailscale
```

### 步骤 4. 验证 Tailscale 安装

在继续身份验证之前，请确认 Tailscale 已在你的 DGX Spark 设备上正确安装。

```bash
## 检查 Tailscale 版本
tailscale version

## 检查 Tailscale 服务状态
sudo systemctl status tailscaled --no-pager
```

### 步骤 5. 将你的 DGX Spark 连接到 Tailscale 网络

使用你选择的身份验证提供程序向 Tailscale 身份验证。这将创建你的私有 tailnet 并分配一个稳定的 IP 地址。

```bash
## 启动 Tailscale 并开始身份验证
sudo tailscale up

## 按显示的 URL 在浏览器中完成登录
## 选择：Google、GitHub、Microsoft 或其他支持的提供程序
```

### 步骤 6. 在客户端设备上安装 Tailscale

在你将用于远程连接到 DGX Spark 的设备上安装 Tailscale。

为你的客户端操作系统选择合适的方法：

**在 macOS 上：**
- 选项 1：从 Mac App Store 搜索 "Tailscale"，然后点击获取 → 安装
- 选项 2：从 [Tailscale 网站](https://tailscale.com/download)下载 .pkg 安装程序

**在 Windows 上：**
- 从 [Tailscale 网站](https://tailscale.com/download)下载安装程序
- 运行 .msi 文件并按照安装提示操作
- 从开始菜单或系统托盘启动 Tailscale

**在 Linux 上：**

遵循与 DGX Spark 安装相同的说明。

```bash
## 更新包列表
sudo apt update

## 安装 Tailscale
sudo apt install -y tailscale

## 验证安装
tailscale version
```

### 步骤 7. 将客户端设备连接到 tailnet

在每个客户端设备上启动 Tailscale 并使用与 DGX Spark 相同的身份验证提供程序登录。

```bash
## 启动 Tailscale
tailscale up

## 按照显示的 URL 完成登录
```

### 步骤 8. 验证网络连接

确认你的设备已连接并可以看到彼此。

```bash
## 在 DGX Spark 和客户端设备上运行
tailscale status
```

你应该看到连接的设备列表以及它们的 IP 地址和主机名。

### 步骤 9. 配置 SSH 身份验证

确保你可以在客户端设备上使用 SSH 登录到 DGX Spark。

```bash
## 在客户端设备上测试 SSH 连接
ssh username@spark-hostname.tailscale.net
```

如果使用用户名认证，请确保在 DGX Spark 上设置了 SSH 密钥。

### 步骤 10. 测试 SSH 连接

从客户端设备测试到 DGX Spark 的 SSH 连接。

```bash
## 测试 SSH
ssh nvidia@spark-XXXXXX.tailscale.net
```

### 步骤 11. 验证安装

确认所有组件正常工作。

```bash
## 在 DGX Spark 上
tailscale status
systemctl status ssh

## 在客户端设备上
tailscale status
ssh nvidia@spark-XXXXXX.tailscale.net
```

### 步骤 13. 清理和回滚

如果需要，可以完全删除 Tailscale：

```bash
## 停止 Tailscale
sudo tailscale down

## 卸载 Tailscale
sudo apt remove tailscale

## 可选：清理配置
sudo apt purge tailscale
```

网络路由将自动恢复为默认设置。

### 步骤 14. 下一步

- 配置 Tailscale 的 IP 地址范围
- 设置细粒度的访问控制列表（ACL）
- 使用 Tailscale 代理进行其他网络服务
- 集成到你的家庭网络基础设施中

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 无法连接到 Tailscale 网络 | 网络连接问题或防火墙阻止 | 检查互联网连接和防火墙设置 |
| SSH 连接失败 | SSH 服务器未运行或配置错误 | 验证 `systemctl status ssh` |
| 设备无法互相看到 | Tailscale 服务未运行 | 重启 `sudo systemctl restart tailscaled` |
| 认证失败 | 身份验证提供程序问题 | 尝试使用不同的提供程序 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的动态共享。
> 随着许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，你也可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
