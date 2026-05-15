# 连接两个 Spark 设备

> 连接两个 Spark 设备并为其设置推理和微调环境

## 目录

- [概述](#概述)
- [在两个 Spark 上运行](#在两个-spark-上运行)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

使用 200GbE 直连 QSFP 连接配置两个 DGX Spark 系统进行高速节点间通信。此设置通过建立网络连接和配置 SSH 身份验证，实现跨多个 DGX Spark 节点的分布式工作负载。

## 您将实现的目标

您将使用 QSFP 线缆物理连接两个 DGX Spark 设备，为集群通信配置网络接口，并在节点之间建立无密码 SSH，以创建一个功能性的分布式计算环境。

## 开始前须知

- 基本的分布式计算概念理解
- 使用网络接口配置和 netplan
- 具备 SSH 密钥管理经验

## 先决条件

- 两个 DGX Spark 系统
- 一根 QSFP 线缆，用于两个设备之间的直接 200GbE 连接
- 两个系统上均可访问 SSH
- 两个系统上的 root 或 sudo 访问权限：`sudo whoami`
- 两个系统上使用相同的用户名

## 辅助文件

此操作指南所需的所有文件都可以在 [GitHub 上找到](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/connect-two-sparks/)

- [**discover-sparks.sh**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/connect-two-sparks/assets/discover-sparks) 脚本用于自动节点发现和 SSH 密钥分发

## 时间与风险

- **持续时间：** 1 小时，包括验证

- **风险等级：** 中等 - 涉及网络重新配置

- **回滚方案：** 可以通过移除 netplan 配置或 IP 分配来逆转网络更改

- **最后更新：** 2025年11月24日
  * 少量文字编辑

---

## 在两个 Spark 上运行

## 步骤 1. 确保两个系统使用相同的用户名

在两个系统上检查用户名并确保它们相同：

```bash
## 检查当前用户名
whoami
```

如果用户名不匹配，请在两个系统上创建一个新用户（例如 nvidia）并使用新用户登录：

```bash
## 创建 nvidia 用户并添加到 sudo 组
sudo useradd -m nvidia
sudo usermod -aG sudo nvidia

## 为 nvidia 用户设置密码
sudo passwd nvidia

## 切换到 nvidia 用户
su - nvidia
```

## 步骤 2. 物理硬件连接

使用每个设备上的任何 QSFP 接口，通过 QSFP 线缆连接两个 DGX Spark 系统。这建立了高速节点间通信所需的 200GbE 直连连接。两个节点连接后，您将看到如下输出：在此示例中，显示为"Up"的接口是 **enp1s0f1np1** / **enP2p1s0f1np1**（每个物理端口有两个名称）。

示例输出：
```bash
## 检查两个节点上的 QSFP 接口可用性
nvidia@dxg-spark-1:~$ ibdev2netdev
roceP2p1s0f0 port 1 ==> enP2p1s0f0np0 (Down)
roceP2p1s0f1 port 1 ==> enP2p1s0f1np1 (Up)
rocep1s0f0 port 1 ==> enp1s0f0np0 (Down)
rocep1s0f1 port 1 ==> enp1s0f1np1 (Up)
```

> [!NOTE] 
> 如果没有任何接口显示为"Up"，请检查 QSFP 线缆连接，重新启动系统后重试。
> 显示为"Up"的接口取决于您用于连接两个节点的端口。每个物理端口有两个名称，例如 enp1s0f1np1 和 enP2p1s0f1np1 指的是同一个物理端口。请忽略 enP2p1s0f0np0 和 enP2p1s0f1np1，仅使用 enp1s0f0np0 和 enp1s0f1np1。

## 步骤 3. 网络接口配置

选择以下选项之一来设置网络接口。选项 1 和 2 是互斥的。

> [!NOTE] 
> 仅使用一根 QSFP 线缆即可实现全带宽。
> 当连接两根 QSFP 线缆时，必须为所有四个接口分配 IP 地址以获得全带宽。
> 下面的选项 1 仅在连接一根 QSFP 线缆时可用。

**选项 1：自动 IP 分配（仅在连接一根 QSFP 线缆时可用）**

在两个 DGX Spark 节点上使用 netplan 配置网络接口，以进行自动链路本地地址分配：

```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f0np0:
      link-local: [ ipv4 ]
    enp1s0f1np1:
      link-local: [ ipv4 ]
EOF

## 设置适当权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```

**选项 2：使用 netplan 配置文件手动 IP 分配**

节点 1：
```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f0np0:
      addresses:
        - 192.168.100.10/24
      dhcp4: no
    enp1s0f1np1:
      addresses:
        - 192.168.200.12/24
      dhcp4: no
    enP2p1s0f0np0:
      addresses:
        - 192.168.100.14/24
      dhcp4: no
    enP2p1s0f1np1:
      addresses:
        - 192.168.200.16/24
      dhcp4: no
EOF

## 设置适当权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```

节点 2：
```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f0np0:
      addresses:
        - 192.168.100.11/24
      dhcp4: no
    enp1s0f1np1:
      addresses:
        - 192.168.200.13/24
      dhcp4: no
    enP2p1s0f0np0:
      addresses:
        - 192.168.100.15/24
      dhcp4: no
    enP2p1s0f1np1:
      addresses:
        - 192.168.200.17/24
      dhcp4: no
EOF

## 设置适当权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```


**选项 3：使用命令行手动 IP 分配**

> [!NOTE]
> 使用此选项，分配给接口的 IP 地址将在系统重启时更改。

首先，识别哪些网络端口可用且已启用：

```bash
## 检查网络端口状态
ibdev2netdev
```

示例输出：
```
roceP2p1s0f0 port 1 ==> enP2p1s0f0np0 (Down)
roceP2p1s0f1 port 1 ==> enP2p1s0f1np1 (Up)
rocep1s0f0 port 1 ==> enp1s0f0np0 (Down)
rocep1s0f1 port 1 ==> enp1s0f1np1 (Up)
```

使用输出中显示为"(Up)"的接口。在此示例中，我们将使用 **enp1s0f1np1**。您可以忽略以 `enP2p<...>` 为前缀的接口，而仅使用以 `enp1<...>` 为前缀的接口。

在节点 1 上：
```bash
## 分配静态 IP 并启用接口。
sudo ip addr add 192.168.100.10/24 dev enp1s0f1np1
sudo ip link set enp1s0f1np1 up
```

在节点 2 上重复相同的过程，但使用 IP **192.168.100.11/24**。确保使用 `ibdev2netdev` 命令使用正确的接口名称。
```bash
## 分配静态 IP 并启用接口。
sudo ip addr add 192.168.100.11/24 dev enp1s0f1np1
sudo ip link set enp1s0f1np1 up
```

您可以通过在每个节点上运行以下命令来验证两个节点上的 IP 分配：
```bash
## 将 enp1s0f1np1 替换为输出中显示为"(Up)"的接口，enp1s0f0np0 或 enp1s0f1np1
ip addr show enp1s0f1np1
```

## 步骤 4. 设置无密码 SSH 身份验证

#### 选项 1：自动配置 SSH

从其中一个节点运行 DGX Spark [**discover-sparks.sh**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/connect-two-sparks/assets/discover-sparks) 脚本，自动发现和配置 SSH：

```bash
bash ./discover-sparks
```

预期输出类似于以下内容，IP 和节点名称不同。第一次运行脚本时，您将被提示输入每个节点的密码。
```
Found: 169.254.35.62 (dgx-spark-1.local)
Found: 169.254.35.63 (dgx-spark-2.local)

Setting up bidirectional SSH access (local <-> remote nodes)...
You may be prompted for your password for each node.

SSH setup complete! Both local and remote nodes can now SSH to each other without passwords.
```

> [!NOTE]
> 如果遇到任何错误，请按照下面的选项 2 手动配置 SSH 并调试问题。

#### 选项 2：手动发现和配置 SSH

您需要找到 CX-7 接口已启用的 IP 地址。在两个节点上，运行以下命令以找到 IP 地址，并在下一步中记录下来。
```bash
  ip addr show enp1s0f0np0
  ip addr show enp1s0f1np1
```

示例输出：
```
## 在此示例中，我们使用接口 enp1s0f1np1。
nvidia@dgx-spark-1:~$ ip addr show enp1s0f1np1
    4: enp1s0f1np1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
        link/ether 3c:6d:66:cc:b3:b7 brd ff:ff:ff:ff:ff:ff
        inet **169.254.35.62**/16 brd 169.254.255.255 scope link noprefixroute enp1s0f1np1
          valid_lft forever preferred_lft forever
        inet6 fe80::3e6d:66ff:fecc:b3b7/64 scope link
          valid_lft forever preferred_lft forever
```

在此示例中，节点 1 的 IP 地址为 **169.254.35.62**。为节点 2 重复相同的过程。

在两个节点上，运行以下命令以启用无密码 SSH：
```bash
## 将您的 SSH 公钥复制到两个节点。请将 IP 地址替换为您在上一步中找到的地址。
ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@<IP for Node 1>
ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@<IP for Node 2>
```

## 步骤 5. 验证多节点通信

测试基本的多节点功能：

```bash
## 测试节点间的主机名解析
ssh <IP for Node 1> hostname
ssh <IP for Node 2> hostname
```

## 步骤 6. 清理和回滚

> [!WARNING]
> 这些步骤将重置网络配置。

```bash
## 回滚网络配置（如果使用选项 1）
sudo rm /etc/netplan/40-cx7.yaml
sudo netplan apply

## 回滚网络配置（如果使用选项 2）
sudo ip addr del 192.168.100.10/24 dev enp1s0f0np0  # 将接口名称调整为您在步骤 3 中使用的接口。
sudo ip addr del 192.168.100.11/24 dev enp1s0f0np0  # 将接口名称调整为您在步骤 3 中使用的接口。
```

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| "Network unreachable" 错误 | 网络接口未配置 | 验证 netplan 配置和 `sudo netplan apply` |
| SSH 身份验证失败 | SSH 密钥未正确分发 | 重新运行 `./discover-sparks` 并输入密码 |
| 节点 2 在集群中不可见 | 网络连接问题 | 验证 QSFP 线缆连接，检查 IP 配置 |
