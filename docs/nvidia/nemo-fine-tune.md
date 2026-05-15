# 使用 NeMo 进行微调

> 使用 NVIDIA NeMo 本地微调模型

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

本操作指南引导您在 NVIDIA Spark 设备上设置和使用 NVIDIA NeMo AutoModel 进行大型语言模型和视觉语言模型的微调。NeMo AutoModel 提供 GPU 加速的端到端训练，支持 Hugging Face 模型和原生 PyTorch，实现即时微调而无需转换延迟。该框架支持从单个 GPU 到多节点集群的分布式训练，具有专门为 ARM64 架构和 Blackwell GPU 系统设计的优化内核和内存高效配方。

## 您将实现的目标

您将在您的 NVIDIA Spark 设备上为大型语言模型（1-70B 参数）和视觉语言模型建立完整的微调环境。完成后，您将拥有一个工作安装，支持参数高效微调（PEFT）、监督微调（SFT）和分布式训练功能，并带有 FP8 精度优化，同时保持与 Hugging Face 生态系统的兼容性。

## 开始前须知

- 在 Linux 终端环境和 SSH 连接中工作
- 基本了解 Python 虚拟环境和包管理
- 熟悉 GPU 计算概念和 CUDA 工具包使用
- 有容器化工作流和 Docker/Podman 操作经验
- 了解机器学习模型训练概念和微调工作流

## 先决条件

- 具有 Blackwell 架构 GPU 访问的 NVIDIA Spark 设备
- 已安装并配置 CUDA 工具包 12.0+：`nvcc --version`
- Python 3.10+ 环境可用：`python3 --version`
- 最小 32GB 系统 RAM 用于有效模型加载和训练
- 活跃的互联网连接用于下载模型和包
- 安装了 Git 用于克隆存储库：`git --version`
- 已配置 SSH 访问您的 NVIDIA Spark 设备

## 辅助文件

本操作指南的所有必要文件可以在 [GitHub 上找到](https://github.com/NVIDIA-NeMo/Automodel)

## 时间与风险

* **持续时间：** 完整设置和初始模型微调需要 45-90 分钟
* **风险：** 模型下载可能很大（几个 GB），ARM64 包兼容性问题可能需要故障排除，多节点配置的分布式训练设置复杂性增加
* **回滚方案：** 虚拟环境可以完全删除；主机系统上除了包安装外没有系统级更改。
* **最后更新：** 2026年3月4日
  * 推荐通过 Docker 运行 NeMo 微调工作流

---

## 操作说明

## 步骤 1. 验证系统要求

检查您的 NVIDIA Spark 设备是否满足 [NeMo AutoModel](https://github.com/NVIDIA-NeMo/Automodel) 安装的先决条件。此步骤在主机系统上运行以确认 CUDA 工具包可用性和 Python 版本兼容性。

```bash
## 验证 CUDA 安装
nvcc --version

## 检查 Python 版本（需要 3.10+）
python3 --version

## 验证 GPU 可访问性
nvidia-smi

## 检查可用系统内存
free -h

## Docker 权限：
docker ps

## 如果有权限问题，（例如，尝试连接到 Docker 守护进程套接字时权限被拒绝），则执行：
sudo usermod -aG docker $USER
newgrp docker
```

## 步骤 2. 配置 Docker 权限

要轻松管理容器而不使用 sudo，您必须在 `docker` 组中。如果您选择跳过此步骤，则需要使用 sudo 运行 Docker 命令。

打开一个新终端并测试 Docker 访问。在终端中，运行：

```bash
docker ps
```

如果您看到权限被拒绝错误（类似于尝试连接到 Docker 守护进程套接字时权限被拒绝），将您的用户添加到 docker 组，这样您就不需要使用 sudo 运行该命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## 步骤 3. 获取带有 NeMo AutoModel 的容器镜像

```bash
docker pull nvcr.io/nvidia/nemo-automodel:26.02
```

## 步骤 4. 启动 Docker

启动具有 GPU 访问权限的交互式容器。`--rm` 标志确保您退出时容器被删除。

```bash
docker run \
  --gpus all \
  --ulimit memlock=-1 \
  -it --ulimit stack=67108864 \
  --entrypoint /usr/bin/bash \
  --rm nvcr.io/nvidia/nemo-automodel:26.02
```

## 步骤 5. 探索可用示例

审查为不同模型类型和训练场景提供的预配置训练配方。这些配方为 ARM64 和 Blackwell 架构提供了优化的配置。

```bash
## 导航到 /opt/Automodel
cd /opt/Automodel

## 列出 LLM 微调示例
ls examples/llm_finetune/

## 查看示例配方配置
cat examples/llm_finetune/finetune.py | head -20
```

## 步骤 6. 运行示例微调
以下命令显示如何执行全量微调（SFT）、参数高效微调（PEFT）使用 LoRA 和 QLoRA。

首先，导出您的 HF_TOKEN，以便可以下载闭源模型。

```bash
## 运行基本 LLM 微调示例
export HF_TOKEN=<your_huggingface_token>
```
> [!NOTE]
> 将 `<your_huggingface_token>` 替换为您的个人 Hugging Face 访问令牌。下载任何闭源模型都需要有效的令牌。
> 
> - 生成令牌：[Hugging Face 令牌](https://huggingface.co/settings/tokens)，指南可在[此处](https://huggingface.co/docs/hub/en/security-tokens)找到。
> - 在每个模型的页面上请求并接收访问权限（并接受许可证/条款），然后再尝试下载。
>   - Llama-3.1-8B：[meta-llama/Llama-3.1-8B](https://huggingface.co/meta-llama/Llama-3.1-8B)
>   - Qwen3-8B：[Qwen/Qwen3-8B](https://huggingface.co/Qwen/Qwen3-8B)
>   - Meta-Llama-3-70B：[meta-llama/Meta-Llama-3-70B](https://huggingface.co/meta-llama/Meta-Llama-3-70B)
>
> 对于您使用的任何其他闭源模型，相同的步骤适用：访问其 Hugging Face 上的模型卡片，请求访问权限，接受许可证，并等待批准。

**LoRA 微调示例：**

执行基本微调示例以验证完整设置。这演示了使用适合测试的小模型的参数高效微调。
对于下面的示例，我们使用 YAML 进行配置，参数覆盖作为命令行参数传递。

```bash
## 运行基本 LLM 微调示例
cd /opt/Automodel
python3 examples/llm_finetune/finetune.py \
-c examples/llm_finetune/llama3_2/llama3_2_1b_squad_peft.yaml \
--model.pretrained_model_name_or_path meta-llama/Llama-3.1-8B \
--packed_sequence.packed_sequence_size 1024 \
--step_scheduler.max_steps 20
```

这些覆盖确保 Llama-3.1-8B LoRA 运行按预期行为：
- `--model.pretrained_model_name_or_path`：从 Hugging Face 模型中心选择要微调的 Llama-3.1-8B 模型（通过您的 Hugging Face 令牌获取权重）。
- `--packed_sequence.packed_sequence_size`：将打包序列大小设置为 1024 以启用打包序列训练。
- `--step_scheduler.max_steps`：设置最大训练步骤数。我们将其设置为 20 以进行演示，请根据您的需求进行调整。

> [!NOTE]
> 配方 YAML `llama3_2_1b_squad_peft.yaml` 定义了可在 Llama 模型大小之间重用的训练超参数（LoRA 等级、学习率等）。`--model.pretrained_model_name_or_path` 覆盖决定了实际加载的模型权重。

**QLoRA 微调示例：**

我们可以使用 QLoRA 以内存高效的方式微调大型模型。

```bash
cd /opt/Automodel
python3 examples/llm_finetune/finetune.py \
-c examples/llm_finetune/llama3_1/llama3_1_8b_squad_qlora.yaml \
--model.pretrained_model_name_or_path meta-llama/Meta-Llama-3-70B \
--loss_fn._target_ nemo_automodel.components.loss.te_parallel_ce.TEParallelCrossEntropy \
--step_scheduler.local_batch_size 1 \
--packed_sequence.packed_sequence_size 1024 \
--step_scheduler.max_steps 20
```

这些覆盖确保 70B QLoRA 运行按预期行为：
- `--model.pretrained_model_name_or_path`：选择要微调的 70B 基础模型（通过您的 Hugging Face 令牌获取权重）。
- `--loss_fn._target_`：使用与张量并行训练兼容的 TransformerEngine-并行交叉熵损失变体，适用于大型 LLM。
- `--step_scheduler.local_batch_size`：将每 GPU 微批量大小设置为 1 以使 70B 在内存中；整体有效批量大小仍由配方中的梯度累积和数据/张量并行设置驱动。
- `--step_scheduler.max_steps`：设置最大训练步骤数。我们将其设置为 20 以进行演示，请根据您的需求进行调整。
- `--packed_sequence.packed_sequence_size`：将打包序列大小设置为 1024 以启用打包序列训练。

**全量微调示例：**

运行以下命令执行全量（SFT）微调：

```bash
cd /opt/Automodel
python3 examples/llm_finetune/finetune.py \
-c examples/llm_finetune/qwen/qwen3_8b_squad_spark.yaml \
--model.pretrained_model_name_or_path Qwen/Qwen3-8B \
--step_scheduler.local_batch_size 1 \
--step_scheduler.max_steps 20 \
--packed_sequence.packed_sequence_size 1024
```

这些覆盖确保 Qwen3-8B SFT 运行按预期行为：
- `--model.pretrained_model_name_or_path`：从 Hugging Face 模型中心选择要微调的 Qwen/Qwen3-8B 模型（通过您的 Hugging Face 令牌获取权重）。如果您想要微调不同的模型，请调整此参数。
- `--step_scheduler.max_steps`：设置最大训练步骤数。我们将其设置为 20 以进行演示，请根据您的需求进行调整。
- `--step_scheduler.local_batch_size`：将每 GPU 微批量大小设置为 1 以适应内存；整体有效批量大小仍由配方中的梯度累积和数据/张量并行设置驱动。
- `--packed_sequence.packed_sequence_size`：将打包序列大小设置为 1024 以启用打包序列训练。

## 步骤 7. 验证成功训练完成

通过检查检查点目录中包含的工件来验证微调模型。

```bash
## 检查日志和检查点输出。
## LATEST 是指向最新检查点的符号链接。
## 检查点是训练期间保存的检查点。
## 以下是预期输出的示例（username 和 domain-users 是占位符）。
ls -lah checkpoints/LATEST/

## $ ls -lah checkpoints/LATEST/
## total 32K
## drwxr-xr-x 6 username domain-users 4.0K Oct 16 22:33 .
## drwxr-xr-x 4 username domain-users 4.0K Oct 16 22:33 ..
## -rw-r--r-- 1 username domain-users 1.6K Oct 16 22:33 config.yaml
## drwxr-xr-x 2 username domain-users 4.0K Oct 16 22:33 dataloader
## drwxr-xr-x 2 username domain-users 4.0K Oct 16 22:33 model
## drwxr-xr-x 2 username domain-users 4.0K Oct 16 22:33 optim
## drwxr-xr-x 2 username domain-users 4.0K Oct 16 22:33 rng
## -rw-r--r-- 1 username domain-users 1.3K Oct 16 22:33 step_scheduler.pt
```

## 步骤 8. 清理（可选）

容器使用 `--rm` 标志启动，因此退出时自动删除。要回收 Docker 镜像使用的磁盘空间，请运行：

> [!WARNING]
> 这将删除 NeMo AutoModel 镜像。如果您想稍后使用它，需要再次拉取。

```bash
docker rmi nvcr.io/nvidia/nemo-automodel:26.02
```

## 步骤 9. 可选：在 Hugging Face Hub 上发布您的微调模型检查点

在 Hugging Face Hub 上发布您的微调模型检查点。
> [!NOTE]
> 这是一个可选步骤，对于使用微调模型不是必需的。
> 如果您想要与他人分享您的微调模型或在其他项目中使用它，则很有用。
> 您还可以通过克隆存储库并使用检查点在其他项目中使用微调模型。
> 要在其他项目中使用微调模型，您需要安装 Hugging Face CLI。
> 您可以通过运行 `pip install huggingface_hub` 安装 Hugging Face CLI。
> 有关更多信息，请参考 [Hugging Face CLI 文档](https://huggingface.co/docs/huggingface_hub/en/guides/cli)。

> [!TIP]
> 您可以使用 `hf` 命令将微调模型检查点上传到 Hugging Face Hub。
> 有关更多信息，请参考 [Hugging Face CLI 文档](https://huggingface.co/docs/huggingface_hub/en/guides/cli)。

```bash
## 将微调模型检查点发布到 Hugging Face Hub
## 将在命名空间 <your_huggingface_username>/my-cool-model 下发布，根据需要调整名称。
hf upload my-cool-model checkpoints/LATEST/model
```

> [!TIP]
> 如果您对 Hugging Face Hub 没有写权限，上述命令可能会失败，使用您使用的 HF_TOKEN。
> 示例错误消息：
> ```bash
> user@host:/opt/Automodel$ hf upload my-cool-model checkpoints/LATEST/model
> Traceback (most recent call last):
>   File "/home/user/.local/lib/python3.10/site-packages/huggingface_hub/utils/_http.py", line 409, in hf_raise_for_status
>     response.raise_for_status()
>   File "/home/user/.local/lib/python3.10/site-packages/requests/models.py", line 1024, in raise_for_status
>     raise HTTPError(http_error_msg, response=self)
> requests.exceptions.HTTPError: 403 Client Error: Forbidden for url: https://huggingface.co/api/repos/create
> ```
> 要解决此问题，您需要创建一个具有*写*权限的访问令牌，请按照此处的 Hugging Face 指南进行操作 [此处](https://huggingface.co/docs/hub/en/security-tokens)。

## 步骤 10. 后续步骤

开始使用 NeMo AutoModel 进行您的特定微调任务。从提供的配方开始，并根据您的模型要求和数据集进行自定义。

```bash
## 复制配方进行自定义
cp examples/llm_finetune/finetune.py my_custom_training.py

## 为您的特定模型和数据编辑配置，然后运行：
python3 my_custom_training.py
```

探索 [NeMo AutoModel GitHub 存储库](https://github.com/NVIDIA-NeMo/Automodel)以获取更多配方、文档和社区示例。考虑设置自定义数据集，尝试不同的模型架构，并扩展到多节点分布式训练以用于更大的模型。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| `nvcc: command not found` | CUDA 工具包不在 PATH 中 | 将 CUDA 工具包添加到 PATH：`export PATH=/usr/local/cuda/bin:$PATH` |
| `pip install uv` 权限被拒绝 | 系统级 pip 限制 | 使用 `pip3 install --user uv` 并更新 PATH |
| GPU 在训练中未检测到 | CUDA 驱动程序/运行时不匹配 | 验证驱动程序兼容性：`nvidia-smi` 并在需要时重新安装 CUDA |
| 训练期间内存不足 | 模型太大，无法获得可用的 GPU 内存 | 减少批量大小，启用梯度检查点或使用模型并行 |
| ARM64 包兼容性问题 | 包不可用于 ARM 架构 | 使用源码安装或使用 ARM64 标志从源码构建 |
| 无法访问 URL 的闭源仓库 | 某些 HuggingFace 模型有访问限制 | 重新生成您的 [HuggingFace 令牌](https://huggingface.co/docs/hub/en/security-tokens)；并在您的 Web 浏览器上请求访问[闭源模型](https://huggingface.co/docs/hub/en/models-gated#customize-requested-information) |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。
> 由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
