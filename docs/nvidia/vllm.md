# vLLM 用于推理

> 在 DGX Spark 上安装和使用 vLLM

## 目录

- [概述](#概述)
- [安装说明](#安装说明)
- [在两台 Spark 上运行](#在两台-spark-上运行)
  - [步骤 11.（可选）启动 405B 推理服务器](#步骤-11可选启动-405b-推理服务器)
- [通过交换机在多台 Spark 上运行](#通过交换机在多台-spark-上运行)
- [故障排除](#故障排除)

---

## 概述

## 基本原理

vLLM 是一个为高效运行大语言模型而设计的推理引擎。其核心理念是**在服务 LLM 时最大化吞吐量并最小化内存浪费**。

- 它使用一种名为 **PagedAttention** 的内存高效注意力算法，可在处理长序列时避免 GPU 内存耗尽。
- 通过 **连续批处理**，新请求可以添加到正在处理的批次中，保持 GPU 充分利用。
- 它提供 **OpenAI 兼容的 API**，因此为 OpenAI API 构建的应用程序可以切换到 vLLM 后端，几乎无需修改。

## 您将完成的工作

您将在配备 Blackwell 架构的 DGX Spark 上设置 vLLM 高吞吐量 LLM 服务，可以使用预构建的 Docker 容器，或使用自定义 LLVM/Triton 支持为 ARM64 构建。

## 开始前需要了解

- 具备使用 Docker 构建和配置容器的经验
- 熟悉 CUDA 工具包安装和版本管理
- 了解 Python 虚拟环境和包管理
- 掌握使用 CMake 和 Ninja 从源代码构建软件的知识
- 具有 Git 版本控制和补丁管理经验

## 前置条件

- 具有 ARM64 处理器和 Blackwell GPU 架构的 DGX Spark 设备
- 安装了 CUDA 13.0 工具包：`nvcc --version` 显示 CUDA 工具包版本
- 已安装并配置 Docker：`docker --version` 成功
- 安装了 NVIDIA Container Toolkit
- 可用的 Python 3.12：`python3.12 --version` 成功
- 已安装 Git：`git --version` 成功
- 网络访问权限，用于下载软件包和容器镜像

## 模型支持矩阵

以下模型在 Spark 上支持 vLLM。所有列出的模型均可用且可直接使用：

| 模型 | 量化方式 | 支持状态 | Hugging Face 标识符 |
|-------|-------------|----------------|-----------|
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | BF16 | ✅ | [`nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16`](https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16) |
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | FP8 | ✅ | [`nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-FP8`](https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-FP8) |
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | NVFP4 | ✅ | [`nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4`](https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4) |
| **Gemma 4 31B IT** | Base | ✅ | [`google/gemma-4-31B-it`](https://huggingface.co/google/gemma-4-31B-it) |
| **Gemma 4 31B IT** | NVFP4 | ✅ | [`nvidia/Gemma-4-31B-IT-NVFP4`](https://huggingface.co/nvidia/Gemma-4-31B-IT-NVFP4) |
| **Gemma 4 26B A4B IT** | Base | ✅ | [`google/gemma-4-26B-A4B-it`](https://huggingface.co/google/gemma-4-26B-A4B-it) |
| **Gemma 4 E4B IT** | Base | ✅ | [`google/gemma-4-E4B-it`](https://huggingface.co/google/gemma-4-E4B-it) |
| **Gemma 4 E2B IT** | Base | ✅ | [`google/gemma-4-E2B-it`](https://huggingface.co/google/gemma-4-E2B-it) |
| **Nemotron-3-Super-120B** | NVFP4 | ✅ | [`nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4`](https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4) |
| **GPT-OSS-20B** | MXFP4 | ✅ | [`openai/gpt-oss-20b`](https://huggingface.co/openai/gpt-oss-20b) |
| **GPT-OSS-120B** | MXFP4 | ✅ | [`openai/gpt-oss-120b`](https://huggingface.co/openai/gpt-oss-120b) |
| **Llama-3.1-8B-Instruct** | FP8 | ✅ | [`nvidia/Llama-3.1-8B-Instruct-FP8`](https://huggingface.co/nvidia/Llama-3.1-8B-Instruct-FP8) |
| **Llama-3.1-8B-Instruct** | NVFP4 | ✅ | [`nvidia/Llama-3.1-8B-Instruct-NVFP4`](https://huggingface.co/nvidia/Llama-3.1-8B-Instruct-NVFP4) |
| **Llama-3.3-70B-Instruct** | NVFP4 | ✅ | [`nvidia/Llama-3.3-70B-Instruct-NVFP4`](https://huggingface.co/nvidia/Llama-3.3-70B-Instruct-NVFP4) |
| **Qwen3-8B** | FP8 | ✅ | [`nvidia/Qwen3-8B-FP8`](https://huggingface.co/nvidia/Qwen3-8B-FP8) |
| **Qwen3-8B** | NVFP4 | ✅ | [`nvidia/Qwen3-8B-NVFP4`](https://huggingface.co/nvidia/Qwen3-8B-NVFP4) |
| **Qwen3-14B** | FP8 | ✅ | [`nvidia/Qwen3-14B-FP8`](https://huggingface.co/nvidia/Qwen3-14B-FP8) |
| **Qwen3-14B** | NVFP4 | ✅ | [`nvidia/Qwen3-14B-NVFP4`](https://huggingface.co/nvidia/Qwen3-14B-NVFP4) |
| **Qwen3-32B** | NVFP4 | ✅ | [`nvidia/Qwen3-32B-NVFP4`](https://huggingface.co/nvidia/Qwen3-32B-NVFP4) |
| **Qwen2.5-VL-7B-Instruct** | NVFP4 | ✅ | [`nvidia/Qwen2.5-VL-7B-Instruct-NVFP4`](https://huggingface.co/nvidia/Qwen2.5-VL-7B-Instruct-NVFP4) |
| **Qwen3-VL-Reranker-2B** | Base | ✅ | [`Qwen/Qwen3-VL-Reranker-2B`](https://huggingface.co/Qwen/Qwen3-VL-Reranker-2B) |
| **Qwen3-VL-Reranker-8B** | Base | ✅ | [`Qwen/Qwen3-VL-Reranker-8B`](https://huggingface.co/Qwen/Qwen3-VL-Reranker-8B) |
| **Qwen3-VL-Embedding-2B** | Base | ✅ | [`Qwen/Qwen3-VL-Embedding-2B`](https://huggingface.co/Qwen/Qwen3-VL-Embedding-2B) |
| **Phi-4-multimodal-instruct** | FP8 | ✅ | [`nvidia/Phi-4-multimodal-instruct-FP8`](https://huggingface.co/nvidia/Phi-4-multimodal-instruct-FP8) |
| **Phi-4-multimodal-instruct** | NVFP4 | ✅ | [`nvidia/Phi-4-multimodal-instruct-NVFP4`](https://huggingface.co/nvidia/Phi-4-multimodal-instruct-NVFP4) |
| **Phi-4-reasoning-plus** | FP8 | ✅ | [`nvidia/Phi-4-reasoning-plus-FP8`](https://huggingface.co/nvidia/Phi-4-reasoning-plus-FP8) |
| **Phi-4-reasoning-plus** | NVFP4 | ✅ | [`nvidia/Phi-4-reasoning-plus-NVFP4`](https://huggingface.co/nvidia/Phi-4-reasoning-plus-NVFP4) |
| **Nemotron3-Nano** | BF16 | ✅ | [`nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16`](https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16) |
| **Nemotron3-Nano** | FP8 | ✅ | [`nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8`](https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8) |

> [!NOTE]
> Phi-4-multimodal-instruct 模型在启动 vLLM 时需要 `--trust-remote-code` 参数。

> [!NOTE]
> 您可以使用 NVFP4 量化文档为您的喜爱模型生成自己的 NVFP4 量化检查点。这使您能够利用 NVFP4 量化的性能和内存优势，即使模型尚未由 NVIDIA 发布。

提醒：并非所有模型架构都支持 NVFP4 量化。

## 时间与风险

* **持续时间：** Docker 方式需 30 分钟
* **风险：** 容器注册表访问需要内部凭证
* **回滚：** Docker 方式是非破坏性的
* **最后更新：** 2026 年 4 月 28 日
  * 添加对 Nemotron-3-Nano-Omni 推理 BF16、FP8、NVFP4 的支持

## 安装说明

## 步骤 1. 使用特定模型的部署指南

某些模型需要特殊的部署配置。请参阅其各自的模型卡片以在 DGX Spark 上运行：

| 模型 | 量化方式 | Hugging Face 模型卡片链接 |
|-------|-------------|----------------|
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | BF16 | https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16 |
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | FP8 | https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-FP8 |
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | NVFP4 | https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4 |

## 步骤 2. 配置 Docker 权限

为方便管理容器而无需使用 sudo，您必须在 `docker` 组中。如果您选择跳过此步骤，您需要使用 sudo 运行 Docker 命令。

打开新终端并测试 Docker 访问。在终端中运行：
```bash
docker ps
```

如果您看到权限被拒绝错误（例如尝试连接到 Docker 守护程序套接字时被拒绝），请将您的用户添加到 docker 组，这样您就不需要使用 sudo 运行该命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## 步骤 3. 拉取 vLLM 容器镜像

从 https://catalog.ngc.nvidia.com/orgs/nvidia/containers/vllm 找到最新的容器版本

```bash
export LATEST_VLLM_VERSION=<最新容器版本>
## 例如
## export LATEST_VLLM_VERSION=26.02-py3

export HF_MODEL_HANDLE=<HF标识符>
## 例如
## export HF_MODEL_HANDLE=openai/gpt-oss-20b

docker pull nvcr.io/nvidia/vllm:${LATEST_VLLM_VERSION}
```

对于 Gemma 4 模型系列，请使用 vLLM 自定义容器：
```bash
docker pull vllm/vllm-openai:gemma4-cu130
```

## 步骤 4. 在容器中测试 vLLM

启动容器并使用测试模型启动 vLLM 服务器，以验证基本功能。

```bash
docker run -it --gpus all -p 8000:8000 \
nvcr.io/nvidia/vllm:${LATEST_VLLM_VERSION} \
vllm serve ${HF_MODEL_HANDLE}
```

对于 Gemma 4 模型系列（例如 `google/gemma-4-31B-it`）：
```bash
docker run -it --gpus all -p 8000:8000 \
vllm/vllm-openai:gemma4-cu130 ${HF_MODEL_HANDLE}
```

预期输出应包括：
- 模型加载确认
- 在端口 8000 上启动服务器
- GPU 内存分配详情

在另一个终端中测试服务器：

```bash
curl http://localhost:8000/v1/chat/completions \
-H "Content-Type: application/json" \
-d '{
    "model": "'"${HF_MODEL_HANDLE}"'",
    "messages": [{"role": "user", "content": "12*17"}],
    "max_tokens": 500
}'
```

预期响应应包含 `"content": "204"` 或类似的数学计算结果。

## 步骤 5. 清理和回滚

对于容器方式（非破坏性）：

```bash
docker rm $(docker ps -aq --filter ancestor=nvcr.io/nvidia/vllm:${LATEST_VLLM_VERSION})
docker rmi nvcr.io/nvidia/vllm
```

## 步骤 6. 后续步骤

- **生产部署：** 使用您的特定模型需求配置 vLLM
- **性能调优：** 根据您的工作负载调整批大小和内存设置
- **监控：** 为生产使用设置日志记录和指标收集
- **模型管理：** 探索其他模型格式和量化选项

## 在两台 Spark 上运行

## 步骤 1. 配置网络连接

按照 [连接两台 Spark](https://build.nvidia.com/spark/connect-two-sparks) 操作手册中的网络设置说明，建立 DGX Spark 节点之间的连接。

这包括：
- 物理 QSFP 电缆连接
- 网络接口配置（自动或手动 IP 分配）
- 无密码 SSH 设置
- 网络连接验证

## 步骤 2. 下载集群部署脚本

在两个节点上获取 vLLM 集群部署脚本。此脚本协调分布式推理所需的 Ray 集群设置。

```bash
## 在两个节点上下载
wget https://raw.githubusercontent.com/vllm-project/vllm/refs/heads/main/examples/online_serving/run_cluster.sh
chmod +x run_cluster.sh
```

## 步骤 3. 从 NGC 拉取 NVIDIA vLLM 镜像

首先，您需要配置 docker 以从 NGC 拉取
如果这是您首次使用 docker，请运行：
```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

在此之后，您应该能够无需使用 `sudo` 运行 docker 命令。

```bash
docker pull nvcr.io/nvidia/vllm:25.11-py3
export VLLM_IMAGE=nvcr.io/nvidia/vllm:25.11-py3
```

## 步骤 4. 启动 Ray 主节点

在节点 1 上启动 Ray 集群主节点。此节点协调分布式推理并提供 API 端点。

```bash
## 在节点 1 上启动主节点

## 获取高速接口的 IP 地址
## 使用 ibdev2netdev 显示 "(Up)" 的接口 (enp1s0f0np0 或 enp1s0f1np1)
export MN_IF_NAME=enp1s0f1np1
export VLLM_HOST_IP=$(ip -4 addr show $MN_IF_NAME | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

echo "使用接口 $MN_IF_NAME，IP 为 $VLLM_HOST_IP"

bash run_cluster.sh $VLLM_IMAGE $VLLM_HOST_IP --head ~/.cache/huggingface \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=$VLLM_HOST_IP
```

## 步骤 5. 启动 Ray 工作节点

将节点 2 连接到 Ray 集群作为工作节点。这为张量并行提供了额外的 GPU 资源。

```bash
## 在节点 2 上作为工作节点加入

## 设置接口名称（与节点 1 相同）
export MN_IF_NAME=enp1s0f1np1

## 获取节点 2 自己的 IP 地址
export VLLM_HOST_IP=$(ip -4 addr show $MN_IF_NAME | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

## 重要：将 HEAD_NODE_IP 设置为节点 1 的 IP 地址
## 您必须从节点 1 获取此值（在节点 1 上运行：echo $VLLM_HOST_IP）
export HEAD_NODE_IP=<节点1IP地址>

echo "工作节点 IP：$VLLM_HOST_IP，连接到主节点：$HEAD_NODE_IP"

bash run_cluster.sh $VLLM_IMAGE $HEAD_NODE_IP --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=$HEAD_NODE_IP
```
> **注意：** 将 `<节点1IP地址>` 替换为节点 1 的实际 IP 地址，特别是 [连接两台 Spark](https://build.nvidia.com/spark/connect-two-sparks) 操作手册中配置的 QSFP 接口 nep1s0f1np1。

## 步骤 6. 验证集群状态

确认 Ray 集群中已识别并可用两个节点。

```bash
## 在节点 1（主节点）上
## 找到 vLLM 容器名称（它将是 node-<随机数字>）
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E '^node-[0-9]+$')
echo "找到容器：$VLLM_CONTAINER"

docker exec $VLLM_CONTAINER ray status
```

预期输出显示 2 个节点，具有可用的 GPU 资源。

## 步骤 7. 下载 Llama 3.3 70B 模型

通过 Hugging Face 进行身份验证并下载推荐的生产就绪模型。

```bash
## 在运行 `ray status` 的同一容器中运行以下命令
hf auth login
hf download meta-llama/Llama-3.3-70B-Instruct
```

## 步骤 8. 启动 Llama 3.3 70B 的推理服务器

在两个节点上使用张量并行启动 vLLM 推理服务器。

```bash
## 在节点 1 上进入容器并启动服务器
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E '^node-[0-9]+$')
docker exec -it $VLLM_CONTAINER /bin/bash -c '
  vllm serve meta-llama/Llama-3.3-70B-Instruct \
    --tensor-parallel-size 2 --max_model_len 2048'
```

## 步骤 9. 测试 70B 模型推理

使用示例推理请求验证部署。

```bash
## 从节点 1 或外部客户端测试
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.3-70B-Instruct",
    "prompt": "Write a haiku about a GPU",
    "max_tokens": 32,
    "temperature": 0.7
  }'
```

预期输出包括生成的俳句响应。

## 步骤 10.（可选）部署 Llama 3.1 405B 模型

> [!WARNING]
> 405B 模型的内存余量不足以用于生产环境。

仅为测试目的下载量化后的 405B 模型。

```bash
## 在节点 1 上下载量化模型
huggingface-cli download hugging-quants/Meta-Llama-3.1-405B-Instruct-AWQ-INT4
```

### 步骤 11.（可选）启动 405B 推理服务器

使用内存受限参数启动大型模型服务器。

```bash
## 在节点 1 上使用受限参数启动
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E '^node-[0-9]+$')
docker exec -it $VLLM_CONTAINER /bin/bash -c '
  vllm serve hugging-quants/Meta-Llama-3.1-405B-Instruct-AWQ-INT4 \
    --tensor-parallel-size 2 --max-model-len 64 --gpu-memory-utilization 0.9 \
    --max-num-seqs 1 --max_num_batched_tokens 64'
```

## 步骤 12.（可选）测试 405B 模型推理

使用受限参数验证 405B 部署。

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"模型":"meta-llama/Llama-3.1-405B-Instruct-AWQ-INT4","提示":"写一个关于GPU的俳句","max_tokens":32,"temperature":0.7}'
```

预期输出包括生成的俳句响应。

## 通过交换机在多台 Spark 上运行

## 故障排除

| 症状 | 原因 | 解决方法 |
|-------|-------|-------|
| 容器启动失败，显示"拉取访问被拒绝" | 缺少或不正确的 nvcr.io 凭证 | 使用有效凭证重新运行 `docker login nvcr.io` |
| Web 界面无法访问 | 服务仍在启动或端口冲突 | 等待 2-3 分钟，检查 `docker ps` 了解容器状态 |

> [!NOTE]
> DGX Spark 使用统一内存架构 (UMA)，允许 GPU 和 CPU 之间动态共享内存。
> 许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，您也可能遇到内存问题。
> 如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

---

*翻译完成*
