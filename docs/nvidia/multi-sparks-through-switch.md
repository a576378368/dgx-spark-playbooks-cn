# 通过交换机连接多个 DGX Spark

> 设置通过交换机连接的 DGX Spark 设备集群

## 目录

- [概述](#概述)
- [在四个 Spark 上运行](#在四个-spark-上运行)
  - [步骤 3.1. 验证协商的链路速度](#步骤-31-验证协商的链路速度)
  - [4.1 集群网络配置脚本](#41-集群网络配置脚本)
  - [4.2 手动集群网络配置](#42-手动集群网络配置)
  - [选项 1：自动配置 SSH](#选项-1自动配置-ssh)
  - [选项 2：手动发现和配置 SSH](#选项-2手动发现和配置-ssh)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

配置四个 DGX Spark 系统，使用通过 QSFP 交换机的 200Gbps QSFP 连接进行高速节点间通信。
此设置通过建立网络连接和配置 SSH 身份验证，在多个 DGX Spark 节点之间实现分布式工作负载。

## 您将实现的目标

在此操作指南中，您将物理连接四个 DGX Spark 设备（使用 QSFP 线缆和 QSFP 交换机），
配置网络接口用于集群通信，并建立节点之间的无密码 SSH，以创建功能性分布式计算环境。
相同的设置可以扩展到更多通过同一交换机连接的 DGX Spark 设备。

## 开始前须知

- 基本了解分布式计算概念
- 使用网络接口配置和 netplan
- 具有 SSH 密钥管理经验
- 基本了解和经验配置您计划使用的托管 QSFP 网络交换机。参考说明书以：
  - 了解如何连接到交换机以管理端口和功能
  - 了解如何启用/禁用 QSFP 端口并在交换机上创建软件桥
  - 了解如何在端口上手动配置链路速度并根据需要禁用自动协商

## 先决条件

- 四个 DGX Spark 系统（这些说明适用于通过交换机连接的任意数量的 DGX Spark 设备）
- 至少 4 个 QSFP56-DD 端口的 QSFP 交换机（每个至少 200Gbps）
- QSFP 线缆，用于从交换机到设备的 200Gbps 连接。使用[推荐线缆](https://marketplace.nvidia.com/en-us/enterprise/personal-ai-supercomputers/qsfp-cable-0-4m-for-dgx-spark/)或类似产品。
  - 每个 spark 一个线缆
  - 如果交换机有 400Gbps 端口，则还可以使用分线电缆将它们拆分为两个 200Gbps 端口
- SSH 访问可用于所有系统
- 所有系统上的 root 或 sudo 访问权限：`sudo whoami`
- 所有系统上使用相同的用户名
- 将所有系统更新到最新的 OS 和固件。参考 DGX Spark 文档 https://docs.nvidia.com/dgx/dgx-spark/os-and-component-update.html

## 辅助文件

此操作指南的所有必需文件可以在 [GitHub 上找到](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/multi-sparks-through-switch/)

- [**discover-sparks.sh**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/connect-two-sparks/assets/discover-sparks) 用于自动节点发现和 SSH 密钥分发的脚本
- [**集群设置脚本**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/multi-sparks-through-switch/assets/spark_cluster_setup) 用于自动网络配置、验证和运行 NCCL 健全性测试

## 时间与风险

- **持续时间：** 2 小时，包括验证

- **风险级别：** 中等 - 涉及网络重新配置

- **回滚方案：** 可以通过删除 netplan 配置或 IP 分配来逆转网络更改

- **最后更新：** 2026年3月19日
  * 首次发布

---

## 在四个 Spark 上运行

## 步骤 1. 确保所有四个系统上使用相同的用户名

在所有四个系统上检查并确保用户名相同：

```bash
## 检查当前用户名
whoami
```

如果用户名不匹配，在所有四个系统上创建一个新用户（例如 nvidia）并使用新用户登录：

```bash
## 创建 nvidia 用户并添加到 sudo 组
sudo useradd -m nvidia
sudo usermod -aG sudo nvidia

## 为 nvidia 用户设置密码
sudo passwd nvidia

## 切换到 nvidia 用户
su - nvidia
```

## 步骤 2. 交换机管理

大多数 QSFP 交换机提供某种形式的管理界面，无论是通过 CLI 还是 UI。参考文档并连接到管理界面。
确保交换机上的端口已启用。对于连接四个 spark，您需要确保交换机配置为为每个 DGX Spark 提供 200Gbps 连接。
如果尚未完成，请参考本操作指南的 [概述](https://build.nvidia.com/spark/multi-sparks-through-switch/overview) 了解先决条件和先决知识。

## 步骤 3. 物理硬件连接

使用每个 Spark 系统上的一个 CX7 端口在 DGX Spark 系统和交换机（QSFP56-DD/QSFP56 端口）之间连接 QSFP 线缆。
推荐在所有 Spark 系统上使用相同的 CX7 端口，以便于网络配置并避免 NCCL 测试失败。
在此操作指南中使用第二个端口（远离以太网端口的一个）。这应该建立高速节点间通信所需的 200Gbps 连接。
您将在所有四个 spark 上看到类似下面的输出。在此示例中显示为"Up"的接口是 **enp1s0f1np1** 和 **enP2p1s0f1np1**（每个物理端口有两个逻辑接口）。

示例输出：
```bash
## 在所有节点上检查 QSFP 接口可用性
nvidia@dxg-spark-1:~$ ibdev2netdev
rocep1s0f0 port 1 ==> enp1s0f0np0 (Down)
rocep1s0f1 port 1 ==> enp1s0f1np1 (Up)
roceP2p1s0f0 port 1 ==> enP2p1s0f0np0 (Down)
roceP2p1s0f1 port 1 ==> enP2p1s0f1np1 (Up)
```

> [!NOTE]
> 如果没有接口显示为"Up"，请检查 QSFP 线缆连接，重新启动系统并重试。
> 显示为"Up"的接口取决于您用于将节点连接到交换机的端口。每个物理端口有两个逻辑接口，例如，Port 1 有两个接口 - enp1s0f1np1 和 enP2p1s0f1np1。请忽略 enp1s0f0np0 和 enP2p1s0f0np0，仅使用 enp1s0f1np1 和 enP2p1s0f1np1。

### 步骤 3.1. 验证协商的链路速度

链路速度可能不会默认为 200Gbps 进行自动协商。要确认，请在所有 spark 上运行以下命令并检查速度是否显示为 200000Mb/s。
如果显示的值小于该值，则需要在交换机端口配置中手动将链路速度设置为 200Gbps 并禁用自动协商。
参考交换机的手册/文档以禁用自动协商并将链路速度手动设置为 200Gbps（例如 200G-baseCR4）

示例输出：
```bash
nvidia@dxg-spark-1:~$ sudo ethtool enp1s0f1np1 | grep Speed
	Speed: 100000Mb/s

nvidia@dxg-spark-1:~$ sudo ethtool enP2p1s0f1np1 | grep Speed
	Speed: 100000Mb/s
```

在交换机端口上设置正确的速度后，在所有 DGX Sparks 上再次验证链路速度。

示例输出：
```bash
nvidia@dxg-spark-1:~$ sudo ethtool enp1s0f1np1 | grep Speed
	Speed: 200000Mb/s

nvidia@dxg-spark-1:~$ sudo ethtool enP2p1s0f1np1 | grep Speed
	Speed: 200000Mb/s
```

## 步骤 4. 网络接口配置

> [!NOTE]
> 仅使用一个 QSFP 线缆即可实现全带宽。

对于集群设置，所有 DGX sparks：
1. 应可进行管理（例如 SSH 和运行命令）
2. 应能访问互联网（例如下载模型/工具）
3. 应能使用 CX7 上的 TCP/IP 相互通信。以下步骤有助于配置这一点。

推荐使用以太网/WiFi 网络进行管理和互联网流量，并使其与 CX7 网络分开，以避免 CX7 带宽被非工作负载流量使用。

支持的通过交换机配置集群的方法需要在交换机上配置桥（或使用默认桥）并通过交换机管理界面将所有相关端口（连接到 DGX sparks 的端口）添加到其中。
1. 这样，所有端口都是单个二层域的一部分，这是集群网络配置所需的
2. 一些交换机有限制，即硬件卸载只能在一个桥上启用，因此将所有端口保持在单个桥中是必需的

完成创建/将端口添加到桥后，您应该准备好在 DGX Spark 端配置网络。

### 4.1 集群网络配置脚本

我们创建了一个 [GitHub 上的脚本](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/multi-sparks-through-switch/assets/spark_cluster_setup)，它自动化了以下内容：
1. 所有 DGX Sparks 的接口网络 IP 配置
2. 在 DGX Sparks 之间设置无密码身份验证
3. 验证多节点通信
4. 运行 NCCL 带宽测试

> [!NOTE]
> 您可以使用脚本或继续进行以下部分的手动配置。如果您使用脚本，则可以跳过本操作指南中的其余设置部分。

使用以下步骤运行脚本：

```bash
## 克隆存储库
git clone https://github.com/NVIDIA/dgx-spark-playbooks

## 进入脚本目录
cd dgx-spark-playbooks/nvidia/multi-sparks-through-switch/assets/spark_cluster_setup

## 检查脚本目录中的 README.md 以获取运行脚本和配置集群网络的步骤，使用 "--run-setup" 参数
```

### 4.2 手动集群网络配置

在这种情况下，您可以选择以下选项之一为 CX7 逻辑接口分配 IP。选项 1、2 和 3 是互斥的。
1. 交换机上的 DHCP 服务器（推荐，如果支持）
2. 链路本地 IP 寻址（netplan 在所有节点上相同）
3. 手动 IP 寻址（netplan 在每个节点上不同，但提供更多的控制和确定的 IP）

#### 选项 1：在交换机上配置 DHCP 服务器

1. 在交换机上配置 DHCP 服务器，子网足够大以分配 IP 给所有 sparks。/24 子网应该适用于配置和任何未来扩展。
2. 在 DGX sparks 中配置"UP" CX7 接口以使用 DHCP 获取 IP。例如，如果逻辑接口 **enp1s0f1np1** / **enP2p1s0f1np1** 是"UP"，则在所有 sparks 上创建如下 netplan。

```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f1np1:
      dhcp4: true
    enP2p1s0f1np1:
      dhcp4: true
EOF

## 设置适当的权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```

3. 确认接口获得 IP 分配

```bash
## 在此示例中，我们使用接口 enp1s0f1np1。类似地检查 enP2p1s0f1np1。
nvidia@dgx-spark-1:~$ ip addr show enp1s0f1np1 | grep -w inet
    inet 100.100.100.4/24 brd 100.100.100.255 scope global noprefixroute enp1s0f1np1
```

#### 选项 2：自动链路本地 IP 分配

在所有 DGX Spark 节点上使用 netplan 配置网络接口以自动链路本地寻址：

```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f1np1:
      link-local: [ ipv4 ]
    enP2p1s0f1np1:
      link-local: [ ipv4 ]
EOF

## 设置适当的权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```

#### 选项 3：使用 netplan 配置文件手动 IP 分配

在节点 1 上：
```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f1np1:
      addresses:
        - 192.168.100.10/24
      dhcp4: no
    enP2p1s0f1np1:
      addresses:
        - 192.168.100.11/24
      dhcp4: no
EOF

## 设置适当的权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```

在节点 2 上：
```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f1np1:
      addresses:
        - 192.168.100.12/24
      dhcp4: no
    enP2p1s0f1np1:
      addresses:
        - 192.168.100.13/24
      dhcp4: no
EOF

## 设置适当的权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```

在节点 3 上：
```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f1np1:
      addresses:
        - 192.168.100.14/24
      dhcp4: no
    enP2p1s0f1np1:
      addresses:
        - 192.168.100.15/24
      dhcp4: no
EOF

## 设置适当的权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```

在节点 4 上：
```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f1np1:
      addresses:
        - 192.168.100.16/24
      dhcp4: no
    enP2p1s0f1np1:
      addresses:
        - 192.168.100.17/24
      dhcp4: no
EOF

## 设置适当的权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```

## 步骤 5. 设置无密码 SSH 身份验证

### 选项 1：自动配置 SSH

从其中一个节点运行 DGX Spark [**discover-sparks.sh**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/connect-two-sparks/assets/discover-sparks) 脚本以自动发现和配置 SSH：

```bash
curl -O https://raw.githubusercontent.com/NVIDIA/dgx-spark-playbooks/refs/heads/main/nvidia/connect-two-sparks/assets/discover-sparks
bash ./discover-sparks
```

预期输出类似于下面的内容，IP 地址和节点名称不同。您可能会看到每个节点最多两个 IP，因为两个接口（例如 **enp1s0f1np1** 和 **enP2p1s0f1np1**）已分配 IP 地址。这是预期的，不会引起任何问题。第一次运行脚本时，系统会提示您输入每个节点的密码。
```
Found: 169.254.35.62 (dgx-spark-1.local)
Found: 169.254.35.63 (dgx-spark-2.local)
Found: 169.254.35.64 (dgx-spark-3.local)
Found: 169.254.35.65 (dgx-spark-4.local)

Setting up bidirectional SSH access (local <-> remote nodes)...
You may be prompted for your password for each node.

SSH setup complete! All local and remote nodes can now SSH to each other without passwords.
```

> [!NOTE]
> 如果遇到任何错误，请按照下面的选项 2 手动配置 SSH 并调试问题。

### 选项 2：手动发现和配置 SSH

您需要找到已启动的 CX-7 接口的 IP 地址。在所有节点上，运行以下命令以查找 IP 地址并注意它们用于下一步。
```bash
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

在此示例中，节点 1 的 IP 地址为 **169.254.35.62**。对其他节点重复此过程。

在所有节点上，运行以下命令以启用无密码 SSH：
```bash
## 将您的 SSH 公钥复制到所有节点。将 IP 地址替换为您在上一步中找到的地址。
ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@<Node 1 的 IP>
ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@<Node 2 的 IP>
ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@<Node 3 的 IP>
ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@<Node 4 的 IP>
```

## 步骤 6. 验证多节点通信

从主节点测试基本多节点功能：

```bash
## 在节点之间测试主机名解析
ssh <Node 1 的 IP> hostname
ssh <Node 2 的 IP> hostname
ssh <Node 3 的 IP> hostname
ssh <Node 4 的 IP> hostname
```

## 步骤 7. 运行测试和工作负载

现在您的集群已设置好以在四个节点之间运行分布式工作负载。尝试运行 [NCCL 操作指南](https://build.nvidia.com/spark/nccl/stacked-sparks)。

> [!NOTE]
> 操作指南要求在**两个节点**上运行命令时，只需在**所有四个节点**上运行。
> 确保调整您在**主节点**上运行的 *mpirun* NCCL 命令以适应**四个节点**

NCCL 的示例 mpirun 命令：
```bash
## 设置网络接口环境变量（使用您上一步中的 Up 接口）
export UCX_NET_DEVICES=enp1s0f1np1
export NCCL_SOCKET_IFNAME=enp1s0f1np1
export OMPI_MCA_btl_tcp_if_include=enp1s0f1np1

## 在四个节点上运行 all_gather 性能测试（将 IP 地址替换为您在上一步中找到的地址）
mpirun -np 4 -H <Node 1 的 IP>:1,<Node 2 的 IP>:1,<Node 3 的 IP>:1,<Node 4 的 IP>:1 \
  --mca plm_rsh_agent "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
  $HOME/nccl-tests/build/all_gather_perf
```

## 步骤 8. 清理和回滚

> [!WARNING]
> 这些步骤将重置网络配置。

```bash
## 回滚网络配置
sudo rm /etc/netplan/40-cx7.yaml
sudo netplan apply
```

> [!NOTE]
> 如果断开交换机连接，请确保执行以下操作
> 1. 重新启用自动协商以避免以后交换机用于不同目的时出现问题。
> 2. 如果您使用 DHCP 为 Sparks 分配 IP，请删除交换机上的 DHCP 服务器配置。
> 3. 如果您创建了新桥，请将端口移回默认桥并删除新桥。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| "Network unreachable" 错误 | 网络接口未配置 | 验证 netplan 配置和 `sudo netplan apply` |
| SSH 身份验证失败 | SSH 密钥未正确分发 | 重新运行 `./discover-sparks` 并输入密码 |
| 节点在集群中不可见 | 网络连接问题 | 验证 QSFP 线缆连接，检查 IP 配置 |
| "APT update" 错误（例如 E: The list of sources could not be read.） | APT 源错误、冲突的源或签名密钥 | 检查 APT 和 Ubuntu 文档以修复 APT 源或密钥冲突 |
| NCCL 测试失败（例如 libnccl.so.2: cannot open shared object file） | 所有节点上未完成 NCCL 配置 | 确保在运行 NCCL 测试之前遵循 NCCL 操作指南配置**所有**节点 |
