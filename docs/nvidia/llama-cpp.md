# 在 DGX Spark 上使用 llama.cpp 运行模型

> 使用 CUDA 构建 llama.cpp 并通过 OpenAI 兼容 API（以 Nemotron 3 Nano Omni 为例）提供模型服务

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

[llama.cpp](https://github.com/ggml-org/llama.cpp) 是一个用于大型语言模型的轻量级 C/C++ 推理栈。您使用 CUDA 构建它，以便张量工作在 DGX Spark GB10 GPU 上运行，然后加载 GGUF 权重并通过 `llama-server` 的 OpenAI 兼容 HTTP API 暴露聊天功能。

本操作指南将逐步介绍整个栈，以 **Nemotron 3 Nano Omni** 作为实践示例：这是一个 NVIDIA MoE 家族，可以在 Spark 上的量化 GGUF 中良好运行。所有支持模型的检查点选择和路径在下面的矩阵中汇总；命令在操作说明中。

## 您将实现的目标

您将为 GB10 构建带 CUDA 的 llama.cpp，下载一个 **Nemotron 3 Nano Omni** 示例检查点，并运行 **`llama-server`**，启用 GPU 卸载。您将获得：

- 通过 llama.cpp 进行本地推理（不需要单独的 Python 推理框架）
- 用于工具和应用的 OpenAI 兼容 `/v1/chat/completions` 端点
- 在 DGX Spark 上此栈上运行 **Nemotron 3 Nano Omni** 示例的具体验证

## 开始前须知

- 基本熟悉 Linux 命令行和终端命令
- 了解 git 和使用 CMake 从源码构建
- 基本了解 REST API 和 cURL 进行测试
- 熟悉 Hugging Face Hub 以下载 GGUF 文件

## 先决条件

**硬件要求**

- NVIDIA DGX Spark with GB10 GPU
- 足够的统一内存用于示例 **Q8_0** 检查点（权重约 **~35GB**，加上 KV 缓存和运行时开销 - 如果选择更大的量化或更长上下文，请扩展）
- 至少 **~40GB** 空闲磁盘用于示例下载和构建工件（如果保留多个 GGUF，请更多）

**软件要求**

- NVIDIA DGX OS
- Git: `git --version`
- CMake (3.14+): `cmake --version`
- CUDA 工具包: `nvcc --version`
- 访问 GitHub 和 Hugging Face 的网络权限

## 模型支持矩阵

以下模型在 Spark 上的 llama.cpp 中受支持。操作说明默认使用 **Nemotron 3 Nano Omni** 示例行。

| 模型 | 支持状态 | HF Handle |
|------|---------|-----------|
| **Nemotron 3 Nano Omni** (示例操作指南) | ✅ | `ggml-org/NVIDIA-Nemotron-3-Nano-Omni` |
| **Qwen3.6-35B-A3B** | ✅ | `unsloth/Qwen3.6-35B-A3B-GGUF` |
| **Qwen3.6-27B** | ✅ | `unsloth/Qwen3.6-27B-GGUF` |
| **Gemma 4 31B IT** | ✅ | `ggml-org/gemma-4-31B-it-GGUF` |
| **Gemma 4 26B A4B IT** | ✅ | `ggml-org/gemma-4-26B-A4B-it-GGUF` |
| **Gemma 4 E4B IT** | ✅ | `ggml-org/gemma-4-E4B-it-GGUF` |
| **Gemma 4 E2B IT** | ✅ | `ggml-org/gemma-4-E2B-it-GGUF` |
| **Nemotron-3-Nano** | ✅ | `unsloth/Nemotron-3-Nano-30B-A3B-GGUF` |

## 时间与风险

* **预计时间：** 大约 30 分钟，加上下载示例 GGUF（默认量化约 ~35GB 量级）
* **风险等级：** 低 - 构建仅在您的克隆中本地进行；以下步骤不需要系统范围的安装
* **回滚方案：** 删除 `llama.cpp` 克隆和 `~/models/` 下的模型目录以回收磁盘空间
* **最后更新：** 2026年4月28日
  * 操作指南现在使用 Nemotron Omni；其他模型行仍然可用

---

## 操作说明

## 步骤 1. 验证先决条件

**示例** 检查点是来自 Hugging Face 存储库 `ggml-org/NVIDIA-Nemotron-3-Nano-Omni` 的 **`nemotron-3-nano-omni-ga_v1.0-Q8_0.gguf`**（完整 handle: `ggml-org/NVIDIA-Nemotron-3-Nano-Omni/nemotron-3-nano-omni-ga_v1.0-Q8_0.gguf`）。其他受支持的 GGUF - 包括 Qwen3.6、Gemma 和备选 Nemotron Omni 构建 - 使用相同的构建和服务器步骤；更改 `hf download` 和 `--model` 路径（参见 [概述模型矩阵](overview.md)）。

确保已安装所需工具：

```bash
git --version
cmake --version
nvcc --version
```

所有命令应该返回版本信息。如果缺少任何命令，请在继续之前安装它们。

安装 Hugging Face CLI：

```bash
python3 -m venv llama-cpp-venv
source llama-cpp-venv/bin/activate
pip install -U "huggingface_hub[cli]"
```

验证安装：

```bash
hf version
```

## 步骤 2. 克隆 llama.cpp 存储库

克隆上游 llama.cpp - 您正在构建的框架：

```bash
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
```

## 步骤 3. 使用 CUDA 构建 llama.cpp

使用 CUDA 和 GB10 的 **sm_121** 架构配置 CMake，以便 GGML 的 CUDA 后端与您的 GPU 匹配：

```bash
mkdir build && cd build
cmake .. -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="121" -DLLAMA_CURL=OFF
make -j8
```

构建通常需要大约 5-10 分钟。完成后，`llama-server` 等二进制文件将出现在 `build/bin/` 下。

## 步骤 4. 下载示例 Nemotron 3 Nano Omni GGUF

llama.cpp 加载 **GGUF** 格式的模型。本操作指南使用 `ggml-org/NVIDIA-Nemotron-3-Nano-Omni` 的 **Q8_0** 检查点，该检查点在 DGX Spark GB10 统一内存中平衡质量和内存。

```bash
hf download ggml-org/NVIDIA-Nemotron-3-Nano-Omni \
  nemotron-3-nano-omni-ga_v1.0-Q8_0.gguf \
  --local-dir ~/models/NVIDIA-Nemotron-3-Nano-Omni
```

文件大小约为 **~35GB**（确切大小可能有所不同）。如果被中断，下载可以恢复。

## 步骤 5. 使用 Nemotron 3 Nano Omni 启动 llama-server

从 `llama.cpp/build` 目录，使用 GPU 卸载启动 OpenAI 兼容服务器：

```bash
./bin/llama-server \
  --model ~/models/NVIDIA-Nemotron-3-Nano-Omni/nemotron-3-nano-omni-ga_v1.0-Q8_0.gguf \
  --host 0.0.0.0 \
  --port 30000 \
  --n-gpu-layers 99 \
  --ctx-size 8192 \
  --threads 8
```

**参数（简短）：**

- `--host` / `--port`: HTTP API 的绑定地址和端口
- `--n-gpu-layers 99`: 将层卸载到 GPU（如果使用不同的模型，请调整）
- `--ctx-size`: 上下文长度（可以增加到模型/服务器限制；使用更多内存）
- `--threads`: 非 GPU 工作的 CPU 线程

您应该看到类似的日志行：

```
llama_new_context_with_model: n_ctx = 8192
...
main: server is listening on 0.0.0.0:30000
```

**在测试期间保持此终端打开**。大型 GGUF 可能需要一两分钟才能加载；在您看到 `server is listening` 之前，端口 30000 上没有监听器（如果 `curl` 报告连接被拒绝，请参见故障排除）。

## 步骤 6. 测试 API

使用 **与运行 `llama-server` 的同一机器上的第二个终端**（例如另一个 SSH 会话进入 DGX Spark）。如果在笔记本电脑上运行 `curl` 而服务器仅在 Spark 上运行，请使用 Spark 主机名或 IP 而不是 `localhost`。

```bash
curl -X POST http://127.0.0.1:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nemotron",
    "messages": [{"role": "user", "content": "New York is a great city because..."}],
    "max_tokens": 100
  }'
```

如果您看到 `curl: (7) Failed to connect`，服务器仍在加载、进程已退出（检查服务器日志以获取 OOM 或路径错误），或者您没有在运行 `llama-server` 的主机上运行 `curl`。

示例响应格式（字段因 llama.cpp 版本而异；`message` 可能包括额外的键）：

```json
{
  "choices": [
    {
      "finish_reason": "length",
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "New York is a great city because it's a living, breathing collage of cultures, ideas, and possibilities—all stacked into one vibrant, never‑sleeping metropolis. Here are just a few reasons that many people ("
      }
    }
  ],
  "created": 1765916539,
  "model": "nemotron-3-nano-omni-ga_v1.0-Q8_0.gguf",
  "object": "chat.completion",
  "usage": {
    "completion_tokens": 100,
    "prompt_tokens": 25,
    "total_tokens": 125
  },
  "id": "chatcmpl-...",
  "timings": {
    ...
  }
}
```

## 步骤 7. 更长的完成（使用 Nemotron 3 Nano Omni）

尝试稍长的提示以确认 **Nemotron 3 Nano Omni** 的稳定生成：

```bash
curl -X POST http://127.0.0.1:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nemotron",
    "messages": [{"role": "user", "content": "Solve this step by step: If a train travels 120 miles in 2 hours, what is its average speed?"}],
    "max_tokens": 500
  }'
```

## 步骤 8. 清理

在运行服务器的终端中使用 `Ctrl+C` 停止服务器。

要删除本教程的工件：

```bash
rm -rf ~/llama.cpp
rm -rf ~/models/NVIDIA-Nemotron-3-Nano-Omni
```

如果您不再需要 `hf`，请停用 Python venv：

```bash
deactivate
```

## 步骤 9. 后续步骤

1. **上下文长度：** 增加 `--ctx-size` 进行更长的聊天（注意内存；只有当构建、模型和硬件允许时，1M-token 类上下文才是可能的）。
2. **其他模型：** 将 `--model` 指向任何兼容的 GGUF；llama.cpp 服务器 API 保持不变。
3. **集成：** 使用 OpenAI 客户端模式，将 Open WebUI、Continue.dev 或自定义客户端指向 `http://<spark-host>:30000/v1`。

服务器实现 llama.cpp 构建启用的常见 OpenAI 风格聊天功能（包括流式传输和在支持的情况下与工具相关的流程）。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| `cmake` 失败，显示 "CUDA not found" | CUDA 工具包不在 PATH 中 | 运行 `export PATH=/usr/local/cuda/bin:$PATH` 并从干净的构建目录重新运行 CMake |
| 构建错误提到错误的 GPU 架构 | CMake `CMAKE_CUDA_ARCHITECTURES` 与 GB10 不匹配 | 使用 `-DCMAKE_CUDA_ARCHITECTURES="121"` 进行 DGX Spark GB10，如操作说明所示 |
| GGUF 下载失败或停滞 | 网络或 Hugging Face 不可用 | 重新运行 `hf download`；它会恢复部分文件 |
| 启动 `llama-server` 时 "CUDA out of memory" | 模型对于当前上下文或 VRAM 太大 | 降低 `--ctx-size`（例如 4096）或使用同一存储库中较小的量化 |
| 服务器运行但延迟高 | 层不在 GPU 上 | 确认 `--n-gpu-layers` 足够高以满足您的模型；检查请求期间的 `nvidia-smi` |
| 端口 30000 上的 `curl: (7) Failed to connect` | 尚无监听器、主机错误或崩溃 | 等待 `server is listening`；在与 `llama-server` 相同的主机上运行 `curl`（或 Spark 的 IP）；运行 `ss -tln` 并确认 `:30000`；阅读服务器 stderr 以获取 OOM 或错误的 `--model` 路径 |
| 聊天 API 错误或空回复 | 错误的 `--model` 路径或不兼容的 GGUF | 验证 `.gguf` 文件的路径；如果 GGUF 需要更新的格式，请更新 llama.cpp |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的灵活共享。一些软件仍在赶上 UMA 行为。如果您意外遇到内存压力，您可以尝试刷新页面缓存（在共享系统上小心使用）：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的平台问题，请参阅 [DGX Spark 已知问题](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html) 文档。
