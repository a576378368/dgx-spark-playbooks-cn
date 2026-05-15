# 使用 PyTorch 进行微调

> 使用 PyTorch 本地微调模型

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [在两个 Spark 上运行](#在两个-spark-上运行)
  - [步骤 1. 配置网络连接](#步骤-1-配置网络连接)
  - [步骤 2. 配置 Docker 权限](#步骤-2-配置-docker-权限)
  - [步骤 3. 安装 NVIDIA Container Toolkit 并设置 Docker 环境](#步骤-3-安装-nvidia-container-toolkit-并设置-docker-环境)
  - [步骤 4. 启用资源通告](#步骤-4-启用资源通告)
  - [步骤 5. 初始化 Docker Swarm](#步骤-5-初始化-docker-swarm)
  - [步骤 6. 加入工作节点并部署](#步骤-6-加入工作节点并部署)
  - [步骤 7. 找到你的 Docker 容器 ID](#步骤-7-找到你的-docker-容器-id)
  - [步骤 9. 调整配置文件](#步骤-9-调整配置文件)
  - [步骤 10. 运行微调脚本](#步骤-10-运行微调脚本)
  - [步骤 14. 清理和回滚](#步骤-14-清理和回滚)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

本 playbook 指导你设置和使用 PyTorch 在 NVIDIA Spark 设备上微调大型语言模型。

## 你将实现的目标

你将在 NVIDIA Spark 设备上建立一个完整的大型语言模型（1-70B 参数）微调环境。
完成后，你将有一个支持参数高效微调（PEFT）和监督微调（SFT）的 working 安装。

## 开始前须知

- 之前有在 PyTorch 中微调的经验
- 使用 Docker

## 先决条件
这些配方专门针对 DGX Spark。请确保操作系统和驱动程序是最新的。

## 辅助文件
微调所需的所有文件都包含在 [GitHub 存储库的文件夹中](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/pytorch-fine-tune)。

## 时间与风险

* **估计时间：** 30-45 分钟用于设置和运行微调。微调运行时间因模型大小而异
* **风险：** 模型下载可能很大（几 GB），ARM64 包兼容性问题可能需要故障排除。
* **最后更新：** 2025年1月15日
  * 添加双 Spark 分布式微调示例
  * 添加在 Llama3 3B、8B 和 70B 模型上运行完整 SFT、LoRA 和 qLoRA 工作流的详细说明。

---

## 操作说明

## 步骤 1. 配置 Docker 权限

为了轻松管理容器而无需 sudo，你必须在 `docker` 组中。如果你选择跳过此步骤，你将需要使用 sudo 运行 Docker 命令。

打开新终端并测试 Docker 访问。在终端中，运行：

```bash
docker ps
```

如果你看到权限被拒绝错误（类似于尝试连接到 Docker 守护进程套接字时被拒绝），将你的用户添加到 docker 组，这样你就不需要使用 sudo 运行该命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## 步骤 2. 拉取最新的 PyTorch 容器

```bash
docker pull nvcr.io/nvidia/pytorch:25.11-py3
```

## 步骤 3. 启动 Docker

```bash
docker run --gpus all -it --rm --ipc=host \
-v $HOME/.cache/huggingface:/root/.cache/huggingface \
-v ${PWD}:/workspace -w /workspace \
nvcr.io/nvidia/pytorch:25.11-py3
```

## 步骤 4. 在容器内安装依赖项

```bash
pip install transformers peft datasets trl bitsandbytes
```

## 步骤 5：使用 Huggingface 进行身份验证

```bash
hf auth login
##<输入你的 huggingface 令牌。
##<输入 n 用于 git 凭据>
```

## 步骤 6：克隆包含微调配方的 git 仓库

```bash
git clone https://github.com/NVIDIA/dgx-spark-playbooks
cd dgx-spark-playbooks/nvidia/pytorch-fine-tune/assets
```

## 步骤 7：运行微调配方

#### 可用的微调脚本

提供以下微调脚本，每个脚本针对不同的模型大小和训练方法进行了优化：

| 脚本 | 模型 | 微调类型 | 描述 |
|------|------|----------|------|
| `Llama3_3B_full_finetuning.py` | Llama 3.2 3B | 完整 SFT | 完整监督微调（所有参数可训练） |
| `Llama3_8B_LoRA_finetuning.py` | Llama 3.1 8B | LoRA | 低秩适应（参数高效） |
| `Llama3_70B_LoRA_finetuning.py` | Llama 3.1 70B | LoRA | 支持 FSDP 的低秩适应 |
| `Llama3_70B_qLoRA_finetuning.py` | Llama 3.1 70B | QLoRA | 量化 LoRA（4 位量化以提高内存效率） |

#### 基本用法

使用默认设置运行任何脚本：

```bash
## 在 Llama 3.2 3B 上进行完整微调
python Llama3_3B_full_finetuning.py

## 在 Llama 3.1 8B 上进行 LoRA 微调
python Llama3_8B_LoRA_finetuning.py

## 在 Llama 3.1 70B 上进行 qLoRA 微调
python Llama3_70B_qLoRA_finetuning.py
```

#### 常用命令行参数

所有脚本都支持以下命令行参数进行自定义：

##### 模型配置
- `--model_name`：模型名称或路径（默认：因脚本而异）
- `--dtype`：模型精度 - `float32`、`float16` 或 `bfloat16`（默认：`bfloat16`）

##### 训练配置
- `--batch_size`：每设备训练批量大小（默认：因脚本而异）
- `--seq_length`：最大序列长度（默认：`2048`）
- `--num_epochs`：训练轮次（默认：`1`）
- `--gradient_accumulation_steps`：梯度累积步骤（默认：`1`）
- `--learning_rate`：学习率（默认：因脚本而异）
- `--gradient_checkpointing`：启用梯度检查点以节省内存（标志）

##### LoRA 配置（仅 LoRA 和 QLoRA 脚本）
- `--lora_rank`：LoRA 秩 - 更高的值 = 更多可训练参数（默认：`8`）

##### 数据集配置
- `--dataset_size`：从 Alpaca 数据集使用的样本数（默认：`512`）

##### 日志记录配置
- `--logging_steps`：每 N 步记录指标（默认：`1`）
- `--log_dir`：TensorBoard 日志目录（默认：`logs`）

##### 模型保存
- `--output_dir`：保存微调模型的目录（默认：`None` - 不保存模型）

##### 使用示例
```bash
python Llama3_8B_LoRA_finetuning.py \
  --dataset_size 100 \
  --num_epochs 1 \
  --batch_size 2
```

---

## 在两个 Spark 上运行

### 步骤 1. 配置网络连接

按照 [连接两个 Spark](https://build.nvidia.com/spark/connect-two-sparks/stacked-sparks) playbook 中的网络设置说明在你的 DGX Spark 节点之间建立连接。

这包括：
- 物理 QSFP 电缆连接
- 网络接口配置（自动或手动 IP 分配）
- 无密码 SSH 设置
- 网络连接验证

### 步骤 2. 配置 Docker 权限

为了轻松管理容器而无需 sudo，你必须在 `docker` 组中。如果你选择跳过此步骤，你将需要使用 sudo 运行 Docker 命令。

打开新终端并测试 Docker 访问。在终端中，运行：

```bash
docker ps
```

如果你看到权限被拒绝错误（类似于尝试连接到 Docker 守护进程套接字时被拒绝），将你的用户添加到 docker 组，这样你就不需要使用 sudo 运行该命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 步骤 3. 安装 NVIDIA Container Toolkit 并设置 Docker 环境

确保 NVIDIA 驱动程序和 NVIDIA Container Toolkit 安装在将提供 GPU 资源的每个节点（管理器和工作节点）上。此包使 Docker 容器能够访问主机的 GPU 硬件。确保完成 [安装步骤](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)，包括 NVIDIA Container Toolkit 的 [Docker 配置](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#configuring-docker)。

### 步骤 4. 启用资源通告

首先，通过运行找到你的 GPU UUID：

```bash
nvidia-smi -a | grep UUID
```

接下来，修改 Docker 守护进程配置以向 Swarm 通告 GPU。编辑 **/etc/docker/daemon.json**：

```bash
sudo nano /etc/docker/daemon.json
```

添加或修改文件以包含 nvidia 运行时和 GPU UUID（将 **GPU-45cbf7b3-f919-7228-7a26-b06628ebefa1** 替换为你的实际 GPU UUID）：

```json
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "nvidia",
  "node-generic-resources": [
    "NVIDIA_GPU=GPU-45cbf7b3-f919-7228-7a26-b06628ebefa1"
    ]
}
```

修改 NVIDIA Container Runtime 以向 Swarm 通告 GPU，通过取消注释 **config.toml** 文件中的 swarm-resource 行。你可以使用你喜欢的文本编辑器（例如 vim、nano...）或使用以下命令执行此操作：

```bash
sudo sed -i 's/^#\s*\(swarm-resource\s*=\s*".*"\)/\1/' /etc/nvidia-container-runtime/config.toml
```

最后，重启 Docker 守护进程以应用所有更改：

```bash
sudo systemctl restart docker
```

在所有节点上重复这些步骤。

### 步骤 5. 初始化 Docker Swarm

在你想用作主节点的任何节点上，运行以下 swarm 初始化命令：

```bash
docker swarm init --advertise-addr $(ip -o -4 addr show enp1s0f0np0 | awk '{print $4}' | cut -d/ -f1) $(ip -o -4 addr show enp1s0f1np1 | awk '{print $4}' | cut -d/ -f1)
```

上述命令的典型输出类似于以下内容：

```
Swarm initialized: current node (node-id) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token <worker-token> <advertise-addr>:<port>

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

### 步骤 6. 加入工作节点并部署

现在我们可以继续设置集群的工作节点。在所有工作节点上重复这些步骤。

在每个工作节点上运行 docker swarm init 建议的命令以加入 Docker swarm：

```bash
docker swarm join --token <worker-token> <advertise-addr>:<port>
```

在两个节点上，下载 [**pytorch-ft-entrypoint.sh**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/pytorch-fine-tune/assets/pytorch-ft-entrypoint.sh) 脚本到包含微调脚本和配置文件的目录，并运行以下命令使其可执行：

```bash
chmod +x $PWD/pytorch-ft-entrypoint.sh
```

在主节点上，通过下载 [**docker-compose.yml**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/pytorch-fine-tune/assets/docker-compose.yml) 文件到与上一步相同的目录并运行以下命令来部署 Finetuning 多节点堆栈：

```bash
docker stack deploy -c $PWD/docker-compose.yml finetuning-multinode
```

> [!NOTE]
> 确保将两个文件下载到你运行命令的同一目录中。

你可以使用以下命令验证工作节点的状态：

```bash
docker stack ps finetuning-multinode
```

如果一切正常，你应该看到类似于以下的输出：

```
nvidia@spark-1b3b:~$ docker stack ps finetuning-multinode
ID             NAME                                IMAGE                              NODE         DESIRED STATE   CURRENT STATE            ERROR     PORTS
vlun7z9cacf9   finetuning-multinode_finetunine.1   nvcr.io/nvidia/pytorch:25.10-py3   spark-1d84   Running         Starting 2 seconds ago             
tjl49zicvxoi   finetuning-multinode_finetunine.2   nvcr.io/nvidia/pytorch:25.10-py3   spark-1b3b   Running         Starting 2 seconds ago             
```

> [!NOTE]
> 如果你的 "Current state" 不是 "Running"，请参阅故障排除部分获取更多信息。

### 步骤 7. 找到你的 Docker 容器 ID

你可以使用 `docker ps` 找到你的 Docker 容器 ID。你可以将容器 ID 保存在变量中，如下所示。在两个节点上运行此命令：

```bash
export FINETUNING_CONTAINER=$(docker ps -q -f name=finetuning-multinode)
```

### 步骤 9. 调整配置文件

对于多节点运行，我们提供 2 个配置文件：
- [**config_finetuning.yaml**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/pytorch-fine-tune/assets/configs/config_finetuning.yaml) 用于 Llama3 3B 的完整微调。
- [**config_fsdp_lora.yaml**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/pytorch-fine-tune/assets/configs/config_fsdp_lora.yaml) 用于 LoRa 和 FSDP 的 Llama3 8B 和 Llama3 70B 微调。

这些配置文件需要调整：
- 根据其等级设置每个节点上的 `machine_rank`。你的主节点应该有一个等级 `0`。第二个节点有一个等级 `1`。
- 使用主节点的 IP 地址设置 `main_process_ip`。确保两个配置文件具有相同的值。在主节点上使用 `ifconfig` 找到 CX-7 IP 地址的正确值。
- 设置主节点上可以使用的端口号。

需要在 YAML 文件中填写的字段：

```bash
machine_rank: 0
main_process_ip: < TODO: 指定 IP >
main_process_port: < TODO: 指定端口 >
```

所有脚本和配置文件都在这个 [**存储库**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/pytorch-fine-tune/assets) 中。

### 步骤 10. 运行微调脚本

成功运行先前的步骤后，你可以使用此 [**存储库**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/pytorch-fine-tune/assets) 中可用的 `run-multi-llama_*` 脚本之一进行微调。以下是在 Llama3 70B 上使用 LoRa 进行微调和 FSDP2 的示例：

```bash
## 需要指定 huggingface 令牌用于模型下载。
export HF_TOKEN=<your-huggingface-token>

docker exec \
  -e HF_TOKEN=$HF_TOKEN \
  -it $FINETUNING_CONTAINER bash -c '
  bash /workspace/install-requirements;
  accelerate launch --config_file=/workspace/configs/config_fsdp_lora.yaml /workspace/Llama3_70B_LoRA_finetuning.py'
```

在运行期间，微调的进度条只会出现在主节点的 stdout 上。这是一种预期的行为，因为 `accelerate` 使用 `tqdm` 的包装器仅在主进程中显示进度，如 [**此处**](https://github.com/huggingface/accelerate/blob/main/src/accelerate/utils/tqdm.py#L25) 所解释。在工作节点上使用 `nvidia-smi` 应该显示 GPU 正在使用。

### 步骤 14. 清理和回滚

在主节点上使用以下命令停止并删除容器：

```bash
docker stack rm finetuning-multinode
```

删除下载的模型以释放磁盘空间：

```bash
rm -rf $HOME/.cache/huggingface/hub/models--meta-llama* $HOME/.cache/huggingface/hub/datasets*
```

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 无法访问 URL 的闸门仓库 | 某些 HuggingFace 模型有访问限制 | 重新生成你的 [HuggingFace 令牌](https://huggingface.co/docs/hub/en/security-tokens)；并在你的网页浏览器中请求访问 [闸门模型](https://huggingface.co/docs/hub/en/models-gated#customize-requested-information) |
| 多 Spark 运行中的错误和超时 | 各种原因 | 我们建议设置以下变量以启用额外的日志记录和运行时一致性检查 <br> `ACCELERATE_DEBUG_MODE=1`<br> `ACCELERATE_LOG_LEVEL=DEBUG`<br> `TORCH_CPP_LOG_LEVEL=INFO`<br> `TORCH_DISTRIBUTED_DEBUG=DETAIL`|
| 任务：非零退出（255） | 容器以错误代码 255 退出 | 使用 `docker ps -a --filter "name=finetuning-multinode"` 检查容器日志以获取容器 ID，然后使用 `docker logs <container_id>` 查看详细错误消息 |
| 无法连接到 unix:///var/run/docker.sock 的 Docker 守护进程。Docker 守护进程正在运行吗？ | Docker 守护进程崩溃，因为 Docker Swarm 尝试绑定到陈旧或无法访问的链路本地 IP 地址 | 停止 Docker `sudo systemctl stop docker`<br> 删除 Swarm 状态 `sudo rm -rf /var/lib/docker/swarm`<br> 重启 Docker `sudo systemctl start docker`<br> 在活动接口上使用有效广告地址重新初始化 Swarm |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的动态共享。
> 随着许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，你也可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
