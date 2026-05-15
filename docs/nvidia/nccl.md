# 两个 Spark 的 NCCL

> 在两个 Spark 上安装和测试 NCCL

## 目录

- [概述](#概述)
- [在两个 Spark 上运行](#在两个-spark-上运行)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

NCCL（NVIDIA 集合通信库）可在多个节点之间实现高性能的 GPU 到 GPU 通信。
本操作指南为 DGX Spark 系统（具有 Blackwell 架构）设置 NCCL 进行多节点分布式训练。
您将配置网络，使用 Blackwell 支持从源码构建 NCCL，并验证节点之间的通信。

## 您将实现的目标

您将拥有一个可用的多节点 NCCL 环境，使您能够为分布式训练工作负载在 DGX Spark 系统之间实现高带宽 GPU 通信，
并验证网络性能和正确的 GPU 拓扑检测。

## 开始前须知

- 使用 Linux 网络配置和 netplan
- 基本了解 MPI（消息传递接口）概念
- SSH 密钥管理和无密码身份验证设置

## 先决条件

- 两个 DGX Spark 系统
- 完成 Connect two Sparks 操作指南
- 安装了 NVIDIA 驱动程序：`nvidia-smi`
- CUDA 工具包可用：`nvcc --version`
- Root/sudo 权限：`sudo whoami`

## 时间与风险

* **持续时间**：30 分钟用于设置和验证
* **风险级别**：中等 - 涉及网络配置更改
* **回滚方案**：可以从 DGX Spark 删除 NCCL 和 NCCL Tests 存储库
* **最后更新：** 2025年12月15日
  * 使用 nccl 最新版本 v2.28.9-1

---

## 在两个 Spark 上运行

## 步骤 1. 配置网络连接

遵循 [Connect two Sparks](https://build.nvidia.com/spark/connect-two-sparks/stacked-sparks) 操作指南中的网络设置说明，建立您的 DGX Spark 节点之间的连接。

这包括：
- 物理 QSFP 线缆连接
- 网络接口配置（自动或手动 IP 分配）
- 无密码 SSH 设置
- 网络连接验证

## 步骤 2. 使用 Blackwell 支持构建 NCCL

在两个节点上执行这些命令以使用 Blackwell 架构支持从源码构建 NCCL：

```bash
## 安装依赖项并构建 NCCL
sudo apt-get update && sudo apt-get install -y libopenmpi-dev
git clone -b v2.28.9-1 https://github.com/NVIDIA/nccl.git ~/nccl/
cd ~/nccl/
make -j src.build NVCC_GENCODE="-gencode=arch=compute_121,code=sm_121"

## 设置环境变量
export CUDA_HOME="/usr/local/cuda"
export MPI_HOME="/usr/lib/aarch64-linux-gnu/openmpi"
export NCCL_HOME="$HOME/nccl/build/"
export LD_LIBRARY_PATH="$NCCL_HOME/lib:$CUDA_HOME/lib64/:$MPI_HOME/lib:$LD_LIBRARY_PATH"
```

## 步骤 3. 构建 NCCL 测试套件

在**两个节点**上编译 NCCL 测试套件：

```bash
## 克隆并构建 NCCL 测试
git clone https://github.com/NVIDIA/nccl-tests.git ~/nccl-tests/
cd ~/nccl-tests/
make MPI=1
```

## 步骤 4. 查找活动网络接口和 IP 地址

首先，确定哪些网络端口可用且已启动：

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

在您的输出中使用显示为 "(Up)" 的接口。在此示例中，我们将使用 **enp1s0f1np1**。您可以忽略以 `enP2p<...>` 为前缀的接口，而仅考虑以 `enp1<...>` 为前缀的接口。

您需要找到已启动的 CX-7 接口的 IP 地址。在两个节点上，运行以下命令以查找 IP 地址并注意它们用于下一步。
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

在此示例中，节点 1 的 IP 地址为 **169.254.35.62**。对节点 2 重复此过程。

## 步骤 5. 运行 NCCL 通信测试

> [!NOTE] 
> 仅使用一个 QSFP 线缆即可实现全带宽。
> 当连接两个 QSFP 线缆时，必须为所有四个接口分配 IP 地址以获得全带宽。

在两个节点上执行以下命令以运行 NCCL 通信测试。将 IP 地址和接口名称替换为您在上一步中找到的地址。

```bash
## 设置网络接口环境变量（使用您上一步中的 Up 接口）
export UCX_NET_DEVICES=enp1s0f1np1
export NCCL_SOCKET_IFNAME=enp1s0f1np1
export OMPI_MCA_btl_tcp_if_include=enp1s0f1np1

## 在两个节点上运行 all_gather 性能测试（将 IP 地址替换为您在上一步中找到的地址）
mpirun -np 2 -H <Node 1 的 IP>:1,<Node 2 的 IP>:1 \
  --mca plm_rsh_agent "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
  $HOME/nccl-tests/build/all_gather_perf
```

您还可以使用更大的缓冲区大小测试您的 NCCL 设置，以使用更多的 200Gbps 带宽。

```bash
## 设置网络接口环境变量（使用您的活动接口）
export UCX_NET_DEVICES=enp1s0f1np1
export NCCL_SOCKET_IFNAME=enp1s0f1np1
export OMPI_MCA_btl_tcp_if_include=enp1s0f1np1

## 在两个节点上运行 all_gather 性能测试
mpirun -np 2 -H <Node 1 的 IP>:1,<Node 2 的 IP>:1 \
  --mca plm_rsh_agent "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
  $HOME/nccl-tests/build/all_gather_perf -b 16G -e 16G -f 2
```

注意：`mpirun` 命令中的 IP 地址后跟 `:1`。例如，`mpirun -np 2 -H 169.254.35.62:1,169.254.35.63:1`

## 步骤 7. 清理和回滚

```bash
## 回滚网络配置（如果需要）
rm -rf ~/nccl/
rm -rf ~/nccl-tests/
```

## 步骤 8. 后续步骤
您的 NCCL 环境已准备好在 DGX Spark 上进行多节点分布式训练工作负载。
现在您可以尝试运行更大的分布式工作负载，例如 TRT-LLM 或 vLLM 推理。

---

## 故障排除

## 在两个 Spark 上运行的常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| mpirun 挂起或超时 | SSH 连接问题 | 1. 测试基本 SSH 连接性：`ssh <remote_ip>` 应该无需密码提示即可工作<br>2. 尝试简单的 mpirun 测试：`mpirun -np 2 -H <Node 1 的 IP>:1,<Node 2 的 IP>:1 hostname`<br>3. 验证 SSH 密钥为所有节点正确设置 |
| 网络接口未找到 | 错误的接口名称或关闭状态 | 使用 `ibdev2netdev` 检查接口状态并验证 IP 配置 |
| NCCL 构建失败 | 缺少依赖项（如 OpenMPI）或错误的 CUDA 版本 | 验证 CUDA 安装和所需的库是否存在 |
