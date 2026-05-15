# 推测性解码

> 了解如何在 Spark 上设置推测性解码以实现快速推理

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
  - [选项 1：EAGLE-3](#选项-1eagle-3)
  - [选项 2：草稿目标](#选项-2草稿目标)
- [在两个 Spark 上运行](#在两个-spark-上运行)
  - [步骤 1. 配置 Docker 权限](#步骤-1-配置-docker-权限)
  - [步骤 2. 网络设置](#步骤-2-网络设置)
  - [步骤 3. 设置容器名称变量](#步骤-3-设置容器名称变量)
  - [步骤 4. 启动 TRT-LLM 多节点容器](#步骤-4-启动-trt-llm-多节点容器)
  - [步骤 5. 配置 OpenMPI 主机文件](#步骤-5-配置-openmpi-主机文件)
  - [步骤 6. 启动 Eagle3 推测性解码](#步骤-6-启动-eagle3-推测性解码)
  - [步骤 7. 验证 API](#步骤-7-验证-api)
  - [步骤 8. 清理](#步骤-8-清理)
  - [步骤 9. 下一步](#步骤-9-下一步)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

推测性解码通过使用**小型、快速模型**提前草拟几个 token，然后让**大型模型**快速验证或调整它们来加速文本生成。
这样，大模型不需要逐步预测每个 token，减少了延迟，同时保持输出质量。

## 你将实现的目标

你将使用 TensorRT-LLM 在 NVIDIA Spark 上探索推测性解码，使用两种方法：EAGLE-3 和 Draft-Target。
这些示例展示了如何在保持输出质量的同时加速大型语言模型推理。

## 为什么需要两个 Spark？

单个 DGX Spark 具有 128 GB 的统一内存，由 CPU 和 GPU 共享。这足以运行像 GPT-OSS-120B 与 EAGLE-3 或 Llama-3.3-70B 与 Draft-Target 这样的模型，如**操作说明**选项卡中所示。

像 **Qwen3-235B-A22B** 这样的更大模型超出了单个 Spark 可以容纳的内存——即使使用 FP4 量化，模型权重、KV 缓存和 Eagle3 草稿头一起也需要超过 128 GB。通过连接两个 Spark，你可以将可用内存加倍到 256 GB，使得这些更大模型的部署成为可能。

**在两个 Spark 上运行**选项卡介绍了此设置。两个 Spark 通过 QSFP 电缆连接，并使用**张量并行（TP=2）**来分割模型——每个 Spark 持有每一层权重矩阵的一半，并计算每次前向传递的部分。节点使用 NCCL 和 OpenMPI 通过高带宽链路交换中间结果，因此模型在两个设备上作为一个逻辑实例操作。

简而言之：两个 Spark 让你运行单个 Spark 无法容纳的模型，同时推测性解码（Eagle3）进一步通过草拟和并行验证多个 token 来加速推理。

## 开始前须知

- Docker 和容器化应用程序的经验
- 理解推测性解码概念
- 熟悉 TensorRT-LLM 服务和 API 端点
- 了解大型语言模型的 GPU 内存管理

## 先决条件

- NVIDIA Spark 设备，具有足够的可用 GPU 内存
- 启用了 GPU 支持的 Docker

  ```bash
  docker run --gpus all nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc12 nvidia-smi
  ```
- 用于模型访问的活动 HuggingFace 令牌
- 用于模型下载的网络连接

## 时间与风险

* **持续时间：** 10-20 分钟用于设置，模型下载的额外时间（取决于网络速度）
* **风险：** 大型模型的 GPU 内存耗尽，容器注册表访问问题，下载期间的网络超时
* **回滚：** 停止 Docker 容器并可选地清理下载的模型缓存。
* **最后更新：** 2026年4月20日
  * 升级到最新容器 1.3.0rc12
  * 添加两个 Spark 上的 Qwen3-235B-A22B 推测性解码示例

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

## 步骤 2. 设置环境变量

为下游服务设置环境变量：

 ```bash
export HF_TOKEN=<your-huggingface-token>
 ```

## 步骤 3. 运行推测性解码方法

### 选项 1：EAGLE-3

通过执行以下命令运行 EAGLE-3 推测性解码：

```bash
docker run \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  --rm -it --ulimit memlock=-1 --ulimit stack=67108864 \
  --gpus=all --ipc=host --network host \
  nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc12 \
  bash -c '
    hf download openai/gpt-oss-120b && \
    hf download nvidia/gpt-oss-120b-Eagle3-long-context \
        --local-dir /opt/gpt-oss-120b-Eagle3/ && \
    cat > /tmp/extra-llm-api-config.yml <<EOF
enable_attention_dp: false
disable_overlap_scheduler: false
enable_autotuner: false
cuda_graph_config:
    max_batch_size: 1
speculative_config:
    decoding_type: Eagle
    max_draft_len: 5
    speculative_model_dir: /opt/gpt-oss-120b-Eagle3/

kv_cache_config:
    free_gpu_memory_fraction: 0.9
    enable_block_reuse: false
EOF
    export TIKTOKEN_ENCODINGS_BASE="/tmp/harmony-reqs" && \
    mkdir -p $TIKTOKEN_ENCODINGS_BASE && \
    wget -P $TIKTOKEN_ENCODINGS_BASE https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken && \
    wget -P $TIKTOKEN_ENCODINGS_BASE https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken
    trtllm-serve openai/gpt-oss-120b \
      --backend pytorch --tp_size 1 \
      --max_batch_size 1 \
      --extra_llm_api_options /tmp/extra-llm-api-config.yml'
```

服务器运行后，从另一个终端通过发出 API 调用来测试它：

```bash
## 测试补全端点
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-oss-120b",
    "prompt": "逐步解决以下问题。如果一辆火车在 3 小时内行驶 180 公里，然后在接下来的 2 小时内减速 20%，总行驶距离是多少？显示所有中间计算并提供最终数值答案。",
    "max_tokens": 300,
    "temperature": 0.7
  }'
```

**EAGLE-3 推测性解码的关键特性**

- **更简单的部署** — EAGLE-3 使用内置的草稿头在内部生成推测 token，而不是管理单独的草稿模型。
- **更好的准确性** — 通过融合模型多个层的特征，草稿 token 更有可能被接受，减少浪费的计算。
- **更快的生成** — 每次前向传递并行验证多个 token，减少自回归推理的延迟。

### 选项 2：草稿目标

执行以下命令来设置和运行草稿目标推测性解码：

```bash
docker run \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  --rm -it --ulimit memlock=-1 --ulimit stack=67108864 \
  --gpus=all --ipc=host --network host nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc12 \
  bash -c "
#    # 下载模型
    hf download nvidia/Llama-3.3-70B-Instruct-FP4 && \
    hf download nvidia/Llama-3.1-8B-Instruct-FP4 \
    --local-dir /opt/Llama-3.1-8B-Instruct-FP4/ && \

#    # 创建配置文件
    cat <<EOF > extra-llm-api-config.yml
print_iter_log: false
disable_overlap_scheduler: true
speculative_config:
  decoding_type: DraftTarget
  max_draft_len: 4
  speculative_model_dir: /opt/Llama-3.1-8B-Instruct-FP4/
kv_cache_config:
  enable_block_reuse: false
EOF

#    # 启动 TensorRT-LLM 服务器
    trtllm-serve nvidia/Llama-3.3-70B-Instruct-FP4 \
      --backend pytorch --tp_size 1 \
      --max_batch_size 1 \
      --kv_cache_free_gpu_memory_fraction 0.9 \
      --extra_llm_api_options ./extra-llm-api-config.yml
  "
```

服务器运行后，从另一个终端通过发出 API 调用来测试它：

```bash
## 测试补全端点
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Llama-3.3-70B-Instruct-FP4",
    "prompt": "解释推测性解码的好处：",
    "max_tokens": 150,
    "temperature": 0.7
  }'
```

**草稿目标的关键特性：**

- **高效的资源使用**：8B 草稿模型加速 70B 目标模型
- **灵活的配置**：可调节的草稿 token 长度以进行优化
- **内存高效**：使用 FP4 量化模型以减少内存占用
- **兼容的模型**：使用具有一致分词的 Llama 系列模型

## 步骤 4. 清理

完成后停止 Docker 容器：

```bash
## 查找并停止容器
docker ps
docker stop <container_id>

## 可选：从缓存中清理下载的模型
## rm -rf $HOME/.cache/huggingface/hub/models--*gpt-oss*
```

## 步骤 5. 下一步

- 尝试不同的 `max_draft_len` 值（1, 2, 3, 4, 8）
- 监控 token 接受率和吞吐量改进
- 使用不同的提示长度和生成参数进行测试
- 在[此处](https://nvidia.github.io/TensorRT-LLM/advanced/speculative-decoding.html)阅读更多关于推测性解码的信息。

---

## 在两个 Spark 上运行

### 步骤 1. 配置 Docker 权限

**在 Spark A 和 Spark B 上运行：**

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 步骤 2. 网络设置

按照**[连接两个 Spark](https://build.nvidia.com/spark/connect-two-sparks/stacked-sparks)** playbook 中的网络设置说明进行操作。

> [!NOTE]
> 在继续之前，请完成连接两个 Spark playbook 中的步骤 1-3：
>
> - **步骤 1**：确保两个系统上使用相同的用户名
> - **步骤 2**：物理硬件连接（QSFP 电缆）
> - **步骤 3**：网络接口配置
>   - 使用**选项 2：使用 netplan 配置文件的手动 IP 分配**
>   - 每个 Spark 有两个网络端口对。当你物理连接两个 Spark 之间的电缆时，连接的端口将显示为 **Up**。你可以使用任意一组显示为 Up 的端口 — 无论是 **`enp1s0f0np0`** 和 **`enP2p1s0f0np0`**，还是 **`enp1s0f1np1`** 和 **`enP2p1s0f1np1`**
>   - 本 playbook 假设你正在使用 **`enp1s0f1np1`** 和 **`enP2p1s0f1np1`**。如果你的 Up 接口不同，请在下面的命令中替换你的接口名称

**对于本 playbook，我们将使用以下 IP 地址：**

**Spark A（节点 1）：**
- `enp1s0f1np1`: 192.168.200.12/24
- `enP2p1s0f1np1`: 192.168.200.14/24

**Spark B（节点 2）：**
- `enp1s0f1np1`: 192.168.200.13/24
- `enP2p1s0f1np1`: 192.168.200.15/24

完成连接两个 Spark 设置后，返回此处继续 TRT-LLM 容器设置。

### 步骤 3. 设置容器名称变量

**在 Spark A 和 Spark B 上运行：**

```bash
export TRTLLM_MN_CONTAINER=trtllm-multinode
```

### 步骤 4. 启动 TRT-LLM 多节点容器

**在 Spark A 和 Spark B 上运行：**

```bash
docker run -d --rm \
  --name $TRTLLM_MN_CONTAINER \
  --gpus '"device=all"' \
  --network host \
  --ulimit memlock=-1 \
  --ulimit stack=67108864 \
  --device /dev/infiniband:/dev/infiniband \
```

### 步骤 5. 配置 OpenMPI 主机文件

（文档继续，由于长度限制，我将使用子代理批量处理剩余文档）
