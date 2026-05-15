# 在环形拓扑中连接三个 DGX Spark

> 以环形拓扑连接和设置三个 DGX Spark 设备

## 目录

- [概述](#概述)
- [在三个 Spark 上运行](#在三个-spark-上运行)
  - [选项 1：自动配置 SSH](#选项-1自动配置-ssh)
  - [选项 2：手动发现和配置 SSH](#选项-2手动发现和配置-ssh)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

以环形拓扑配置三个 DGX Spark 系统，用于使用 200GbE 直连 QSFP 连接进行高速节点间通信。
此设置通过建立网络连接和配置 SSH 身份验证，在三个 DGX Spark 节点之间实现分布式工作负载。

## 您将实现的目标

您将物理连接三个 DGX Spark 设备（使用 QSFP 线缆），配置网络接口用于集群通信，
并建立节点之间的无密码 SSH，以创建功能性分布式计算环境。

## 开始前须知

- 基本了解分布式计算概念
- 使用网络接口配置和 netplan
- 具有 SSH 密钥管理经验

## 先决条件

- 三个 DGX Spark 系统
- 三个 QSFP 线缆，用于在设备之间以环形拓扑直接 200GbE 连接。使用[推荐线缆](https://marketplace.nvidia.com/en-us/enterprise/personal-ai-supercomputers/qsfp-cable-0-4m-for-dgx-spark/)或类似产品。
- SSH 访问可用于所有系统
- 所有系统上的 root 或 sudo 访问权限：`sudo whoami`
- 所有系统上使用相同的用户名
- 将所有系统更新到最新的 OS 和固件。参考 DGX Spark 文档 https://docs.nvidia.com/dgx/dgx-spark/os-and-component-update.html

## 辅助文件

此操作指南的文件可以在 [GitHub 上找到](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/connect-three-sparks/)

- [**discover-sparks.sh**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/connect-two-sparks/assets/discover-sparks) 用于自动节点发现和 SSH 密钥分发的脚本
- [**集群设置脚本**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/multi-sparks-through-switch/assets/spark_cluster_setup) 用于自动网络配置、验证和运行 NCCL 健全性测试

## 时间与风险

- **持续时间：** 1 小时，包括验证

- **风险级别：** 中等 - 涉及网络重新配置

- **回滚方案：** 可以通过删除 netplan 配置或 IP 分配来逆转网络更改

- **最后更新：** 2026年3月19日
  * 首次发布

---

## 在三个 Spark 上运行

## 步骤 1. 确保所有系统上使用相同的用户名

在所有系统上检查用户名并确保它们相同：

```bash
## 检查当前用户名
whoami
```

如果用户名不匹配，在所有系统上创建一个新用户（例如 nvidia）并使用新用户登录：

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

以环形拓扑在三个 DGX Spark 系统之间连接 QSFP 线缆。
这里，Port0 是靠近以太网端口的 CX7 端口，Port1 是远离它的 CX7 端口。
1. 节点1（Port0）到节点2（Port1）
2. 节点2（Port0）到节点3（Port1）
3. 节点3（Port0）到节点1（Port1）

> [!NOTE]
> 请仔细检查连接是否正确，否则网络配置可能会失败。

这建立了高速节点间通信所需的 200GbE 直连连接。
在三个节点之间连接后，您将在所有节点上看到类似下面的输出：在此示例中显示为"Up"的接口是 **enp1s0f0np0** / **enP2p1s0f0np0** 和 **enp1s0f1np1** / **enP2p1s0f1np1**（每个物理端口有两个逻辑接口）。

示例输出：
```bash
## 在所有节点上检查 QSFP 接口可用性
nvidia@dgx-spark-1:~$ ibdev2netdev
rocep1s0f0 port 1 ==> enp1s0f0np0 (Up)
rocep1s0f1 port 1 ==> enp1s0f1np1 (Up)
roceP2p1s0f0 port 1 ==> enP2p1s0f0np0 (Up)
roceP2p1s0f1 port 1 ==> enP2p1s0f1np1 (Up)
```

> [!NOTE] 
> 如果所有接口都没有显示为"Up"，请检查 QSFP 线缆连接，重新启动系统并重试。

## 步骤 3. 网络接口配置

选择一个选项来设置网络接口。选项是互斥的。推荐使用选项 1 以避免网络设置的复杂性。

> [!NOTE] 
> 每个 CX7 端口提供完整的 200GbE 带宽。
> 在三节点环形拓扑中，每个节点上的所有四个接口必须分配 IP 地址以形成对称集群。

**选项 1：使用脚本自动 IP 分配**

我们创建了一个 [GitHub 上的脚本](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/multi-sparks-through-switch/assets/spark_cluster_setup)，它自动化了以下内容：
1. 所有 DGX Sparks 的接口网络配置
2. 在 DGX Sparks 之间设置无密码身份验证
3. 验证多节点通信
4. 运行 NCCL 带宽测试

> [!NOTE]
> 如果您使用脚本，下面的步骤，您可以跳过本操作指南中的其余设置说明。

使用以下步骤运行脚本：

```bash
## 克隆存储库
git clone https://github.com/NVIDIA/dgx-spark-playbooks

## 进入脚本目录
cd dgx-spark-playbooks/nvidia/multi-sparks-through-switch/assets/spark_cluster_setup

## 检查脚本目录中的 README.md 以获取运行脚本和配置集群网络的步骤
```

**选项 2：使用 netplan 配置文件手动 IP 分配**

在节点 1 上：
```bash
## 创建 netplan 配置文件
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f0np0:
      dhcp4: false
      addresses:
        - 192.168.0.1/24
    enP2p1s0f0np0:
      dhcp4: false
      addresses:
        - 192.168.1.1/24
    enp1s0f1np1:
      dhcp4: false
      addresses:
        - 192.168.2.1/24
    enP2p1s0f1np1:
      dhcp4: false
      addresses:
        - 192.168.3.1/24
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
    enp1s0f0np0:
      dhcp4: false
      addresses:
        - 192.168.4.1/24
    enP2p1s0f0np0:
      dhcp4: false
      addresses:
        - 192.168.5.1/24
    enp1s0f1np1:
      dhcp4: false
      addresses:
        - 192.168.0.2/24
    enP2p1s0f1np1:
      dhcp4: false
      addresses:
        - 192.168.1.2/24
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
    enp1s0f0np0:
      dhcp4: false
      addresses:
        - 192.168.2.2/24
    enP2p1s0f0np0:
      dhcp4: false
      addresses:
        - 192.168.3.2/24
    enp1s0f1np1:
      dhcp4: false
      addresses:
        - 192.168.4.2/24
    enP2p1s0f1np1:
      dhcp4: false
      addresses:
        - 192.168.5.2/24
EOF

## 设置适当的权限
sudo chmod 600 /etc/netplan/40-cx7.yaml

## 应用配置
sudo netplan apply
```

## 步骤 4. 设置无密码 SSH 身份验证

### 选项 1：自动配置 SSH

从其中一个节点运行 DGX Spark [**discover-sparks.sh**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/connect-two-sparks/assets/discover-sparks) 脚本以自动发现和配置 SSH：

```bash
curl -O https://raw.githubusercontent.com/NVIDIA/dgx-spark-playbooks/refs/heads/main/nvidia/connect-two-sparks/assets/discover-sparks
bash ./discover-sparks
```

预期输出类似于下面的内容，IP 地址和节点名称不同。您可能会看到每个节点的多个 IP，因为四个接口（**enp1s0f0np0**，**enP2p1s0f0np0**，**enp1s0f1np1** 和 **enP2p1s0f1np1**）已分配 IP 地址。这是预期的，不会引起任何问题。第一次运行脚本时，系统会提示您输入每个节点的密码。
```
Found: 192.168.0.1 (dgx-spark-1.local)
Found: 192.168.0.2 (dgx-spark-2.local)
Found: 192.168.3.2 (dgx-spark-3.local)

Setting up bidirectional SSH access (local <-> remote nodes)...
You may be prompted for your password for each node.

SSH setup complete! All nodes can now SSH to each other without passwords.
```

> [!NOTE]
> 如果遇到任何错误，请按照下面的选项 2 手动配置 SSH 并调试问题。

### 选项 2：手动发现和配置 SSH

您需要找到已启动的 CX-7 接口的 IP 地址。在所有节点上，运行以下命令以查找 IP 地址并注意它们用于下一步。
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
        inet **192.168.1.1**/24 brd 192.168.1.255 scope link noprefixroute enp1s0f1np1
          valid_lft forever preferred_lft forever
        inet6 fe80::3e6d:66ff:fecc:b3b7/64 scope link
          valid_lft forever preferred_lft forever
```

在此示例中，节点 1 的 IP 地址为 **192.168.1.1**。对其他节点重复此过程。

在所有节点上，运行以下命令以启用无密码 SSH：
```bash
## 将您的 SSH 公钥复制到所有节点。请将 IP 地址替换为您在上一步中找到的地址。
ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@<Node 1 的 IP>
ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@<Node 2 的 IP>
ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@<Node 3 的 IP>
```

## 步骤 5. 验证多节点通信

测试基本多节点功能：

```bash
## 在节点之间测试主机名解析
ssh <Node 1 的 IP> hostname
ssh <Node 2 的 IP> hostname
ssh <Node 3 的 IP> hostname
```

## 步骤 6. 运行 NCCL 测试

现在您的集群已设置好以在三个节点之间运行分布式工作负载。尝试运行 NCCL 带宽测试。

使用以下步骤运行脚本，该脚本将在集群上运行 NCCL 测试：

```bash
## 克隆存储库
git clone https://github.com/NVIDIA/dgx-spark-playbooks

## 进入脚本目录
cd dgx-spark-playbooks/nvidia/multi-sparks-through-switch/assets/spark_cluster_setup

## 检查脚本目录中的 README.md 以获取使用 "--run-nccl-test" 选项运行 NCCL 测试的步骤
```

## 步骤 7. 清理和回滚

> [!WARNING]
> 这些步骤将重置网络配置。

```bash
## 回滚网络配置
sudo rm /etc/netplan/40-cx7.yaml
sudo netplan apply
```

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| "Network unreachable" 错误 | 网络接口未配置 | 验证 netplan 配置和 `sudo netplan apply` |
| SSH 身份验证失败 | SSH 密钥未正确分发 | 重新运行 `./discover-sparks` 并输入密码 |
| 节点在集群中不可见 | 网络连接问题 | 验证 QSFP 线缆连接，检查 IP 配置 |
| "APT update" 错误（例如 E: The list of sources could not be read.） | APT 源错误、冲突的源或签名密钥 | 检查 APT 和 Ubuntu 文档以修复 APT 源或密钥冲突 |
