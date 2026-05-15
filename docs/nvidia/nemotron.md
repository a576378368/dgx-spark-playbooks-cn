# Nemotron-3-Nano 使用 llama.cpp

> 在 DGX Spark 上使用 llama.cpp 运行 Nemotron-3-Nano-30B 模型

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

Nemotron-3-Nano-30B-A3B 是 NVIDIA 的强大语言模型，具有 300 亿参数的专家混合（MoE）架构，但只有 30 亿活跃参数。这种高效设计使得高质量推理需要较低的计算要求，非常适合 DGX Spark 的 GB10 GPU。

本操作指南演示如何使用 llama.cpp 运行 Nemotron-3-Nano，它在构建时为您的 GPU 架构编译 CUDA 内核。该模型包括内置推理（思考模式）和通过聊天模板的工具调用支持。

## 您将实现的目标

您将在您的 DGX Spark 上拥有一个完全功能的 Nemotron-3-Nano-30B-A3B 推理服务器，可通过 OpenAI 兼容 API 访问。此设置支持：

- 本地 LLM 推理
- OpenAI 兼容 API 端点，便于与现有工具集成
- 内置推理和工具调用功能

## 开始前须知

- 基本熟悉 Linux 命令行和终端命令
- 了解 git 和使用分支
- 有使用 CMake 从源码构建软件的经验
- 基本了解 REST API 和 cURL 进行测试
- 熟悉 Hugging Face Hub 进行模型下载

## 先决条件

**硬件要求：**
- NVIDIA DGX Spark with GB10 GPU
- 至少 40GB 可用 GPU 内存（模型使用约 38GB VRAM）
- 至少 50GB 可用存储空间用于模型下载和构建工件

**软件要求：**
- NVIDIA DGX OS
- Git: `git --version`
- CMake (3.14+): `cmake --version`
- CUDA 工具包: `nvcc --version`
- 访问 GitHub 和 Hugging Face 的网络权限

## 时间与风险

* **预计时间：** 30 分钟（包括 ~38GB 的模型下载）
* **风险等级：** 低
  * 构建过程从源码编译但不修改系统文件
  * 如果被中断，模型下载可以恢复
* **回滚方案：** 删除克隆的 `llama.cpp` 目录和下载的模型文件以完全移除安装
* **最后更新：** 2025年12月17日
  * 首次发布

---

## 操作说明

## 步骤 1. 验证先决条件

在继续之前，确保您的 DGX Spark 上安装了所需的工具。

```bash
git --version
cmake --version
nvcc --version
```

所有命令应该返回版本信息。如果缺少任何命令，请在继续之前安装它们。

安装 Hugging Face CLI：

```bash
python3 -m venv nemotron-venv
source nemotron-venv/bin/activate
pip install -U "huggingface_hub[cli]"
```

验证安装：

```bash
hf version
```

## 步骤 2. 克隆 llama.cpp 存储库

克隆 llama.cpp 存储库，它提供运行 Nemotron 模型的推理框架。

```bash
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
```

## 步骤 3. 使用 CUDA 支持构建 llama.cpp

使用 CUDA 启用并针对 GB10 的 sm_121 计算架构构建 llama.cpp。这为您的 DGX Spark GPU 编译了专门优化的 CUDA 内核。

```bash
mkdir build && cd build
cmake .. -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="121" -DLLAMA_CURL=OFF
make -j8
```

构建过程大约需要 5-10 分钟。您应该看到编译进度并最终看到成功的构建消息。

## 步骤 4. 下载 Nemotron GGUF 模型

从 Hugging Face 下载 Q8 量化 GGUF 模型。此模型提供出色的品质，同时适合 GB10 的内存容量。

```bash
hf download unsloth/Nemotron-3-Nano-30B-A3B-GGUF \
  Nemotron-3-Nano-30B-A3B-UD-Q8_K_XL.gguf \
  --local-dir ~/models/nemotron3-gguf
```

这下载约 38GB。如果被中断，下载可以恢复。

## 步骤 5. 启动 llama.cpp 服务器

使用 Nemotron 模型启动推理服务器。服务器提供 OpenAI 兼容的 API 端点。

```bash
./bin/llama-server \
  --model ~/models/nemotron3-gguf/Nemotron-3-Nano-30B-A3B-UD-Q8_K_XL.gguf \
  --host 0.0.0.0 \
  --port 30000 \
  --n-gpu-layers 99 \
  --ctx-size 8192 \
  --threads 8
```

**参数解释：**
- `--host 0.0.0.0`: 监听所有网络接口
- `--port 30000`: API 服务器端口
- `--n-gpu-layers 99`: 将所有层卸载到 GPU
- `--ctx-size 8192`: 上下文窗口大小（可增加到 1M）
- `--threads 8`: 非 GPU 操作的 CPU 线程

您应该看到服务器启动消息，指示模型已加载并准备就绪：
```
llama_new_context_with_model: n_ctx = 8192
...
main: server is listening on 0.0.0.0:30000
```

[此处省略剩余部分，由于文件较大]

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| `cmake` 失败，显示 "CUDA not found" | CUDA 工具包不在 PATH 中 | 运行 `export PATH=/usr/local/cuda/bin:$PATH` 并从干净的构建目录重新运行 CMake |
| 构建错误提到错误的 GPU 架构 | CMake `CMAKE_CUDA_ARCHITECTURES` 与 GB10 不匹配 | 使用 `-DCMAKE_CUDA_ARCHITECTURES="121"` 进行 DGX Spark GB10 |
| GGUF 下载失败或停滞 | 网络或 Hugging Face 不可用 | 重新运行 `hf download`；它会恢复部分文件 |
| "CUDA out of memory" 当启动 `llama-server` 时 | 模型对于当前上下文或 VRAM 太大 | 降低 `--ctx-size`（例如 4096）或使用同一存储库中较小的量化 |
| 服务器运行但延迟高 | 层不在 GPU 上 | 确认 `--n-gpu-layers` 足够高以满足您的模型；检查请求期间的 `nvidia-smi` |
| 端口 30000 上的 `curl: (7) Failed to connect` | 尚无监听器、主机错误或崩溃 | 等待 `server is listening`；在与 `llama-server` 相同的主机上运行 `curl`（或 Spark 的 IP）；运行 `ss -tln` 并确认 `:30000`；阅读服务器 stderr 以获取 OOM 或错误的 `--model` 路径 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的灵活共享。一些软件仍在赶上 UMA 行为。如果您意外遇到内存压力，您可以尝试刷新页面缓存（在共享系统上小心使用）：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的平台问题，请参阅 [DGX Spark 已知问题](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html) 文档。
