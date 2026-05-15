# SGLang 用于推理

> 在 DGX Spark 上安装和使用 SGLang

## 目录

- [概述](#概述)
  - [时间与风险](#时间与风险)
- [安装说明](#安装说明)
- [故障排除](#故障排除)

---

## 概述

## 基本原理

SGLang 是一个用于大语言模型和视觉语言模型的快速服务框架，通过协同设计后端运行时和前端语言，使您与模型的交互更快且更具可控性。此设置在配备 Blackwell 架构的单个 NVIDIA Spark 设备上使用优化的 NVIDIA SGLang NGC 容器，提供预装所有依赖项的 GPU 加速推理。

## 您将完成的工作

您将在 NVIDIA Spark 设备上以服务器模式和离线推理模式部署 SGLang，支持使用 DeepSeek-V2-Lite 等模型进行高性能 LLM 服务，包括文本生成、聊天完成和视觉语言任务。

## 开始前需要了解

- 在 Linux 系统上的终端环境工作
- 基本理解 Docker 容器和容器管理
- 熟悉 NVIDIA GPU 驱动程序和 CUDA 工具包概念
- 具有 HTTP API 端点和 JSON 请求/响应处理经验

## 前置条件

- 具有 Blackwell 架构的 NVIDIA Spark 设备
- 已安装并运行 Docker Engine：`docker --version`
- 安装了 NVIDIA GPU 驱动程序：`nvidia-smi`
- 配置了 NVIDIA Container Toolkit：`docker run --rm --gpus all nvcr.io/nvidia/sglang:26.02-py3 nvidia-smi`
- 足够的磁盘空间（>20GB 可用）：`df -h`
- 网络连接用于拉取 NGC 容器：`ping nvcr.io`

## 辅助文件

- 离线推理 Python 脚本 [在此 GitHub 上找到](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/sglang/assets/offline-inference.py)

## 模型支持矩阵

以下模型在 Spark 上支持 SGLang。所有列出的模型均可用且可直接使用：

| 模型 | 量化方式 | 支持状态 | Hugging Face 标识符 |
|-------|-------------|----------------|-----------|
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | BF16 | ✅ | [`nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16`](https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16) |
| **GPT-OSS-20B** | MXFP4 | ✅ | `openai/gpt-oss-20b` |
| **GPT-OSS-120B** | MXFP4 | ✅ | `openai/gpt-oss-120b` |
| **Llama-3.1-8B-Instruct** | FP8 | ✅ | `nvidia/Llama-3.1-8B-Instruct-FP8` |
| **Llama-3.1-8B-Instruct** | NVFP4 | ✅ | `nvidia/Llama-3.1-8B-Instruct-FP4` |
| **Llama-3.3-70B-Instruct** | NVFP4 | ✅ | `nvidia/Llama-3.3-70B-Instruct-FP4` |
| **Qwen3-8B** | FP8 | ✅ | `nvidia/Qwen3-8B-FP8` |
| **Qwen3-8B** | NVFP4 | ✅ | `nvidia/Qwen3-8B-FP4` |
| **Qwen3-14B** | FP8 | ✅ | `nvidia/Qwen3-14B-FP8` |
| **Qwen3-14B** | NVFP4 | ✅ | `nvidia/Qwen3-14B-FP4` |
| **Qwen3-32B** | NVFP4 | ✅ | `nvidia/Qwen3-32B-FP4` |
| **Phi-4-multimodal-instruct** | FP8 | ✅ | `nvidia/Phi-4-multimodal-instruct-FP8` |
| **Phi-4-multimodal-instruct** | NVFP4 | ✅ | `nvidia/Phi-4-multimodal-instruct-FP4` |
| **Phi-4-reasoning-plus** | FP8 | ✅ | `nvidia/Phi-4-reasoning-plus-FP8` |
| **Phi-4-reasoning-plus** | NVFP4 | ✅ | `nvidia/Phi-4-reasoning-plus-FP4` |

注意：对于 NVFP4 模型，添加 `--quantization modelopt_fp4` 标志。

### 时间与风险

* **估计时间：** 初始设置和验证需 30 分钟
* **风险级别：** 低 - 使用预构建、已验证的 SGLang 容器，配置最少
* **回滚：** 使用 `docker stop` 和 `docker rm` 命令停止并删除容器
* **最后更新：** 2026 年 4 月 28 日
    * 引入 Nemotron-3-Nano-Omni 推理 FP8 支持

## 安装说明

## 步骤 1. 使用特定模型的部署指南

某些模型需要特殊的部署配置。请参阅其各自的模型卡片以在 DGX Spark 上运行：
| 模型 | 量化方式 | Hugging Face 模型卡片链接 |
|-------|-------------|----------------|
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | BF16 | https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16 |

## 步骤 2. 验证系统先决条件

在继续之前检查您的 NVIDIA Spark 设备是否满足所有要求。此步骤在您的主机系统上运行，确保 Docker、GPU 驱动程序和容器工具包正确配置。

> 注意：如果您在拉取容器镜像时遇到超时或"连接被拒绝"错误，您可能需要使用 VPN 或代理，因为某些注册表可能受到本地网络或 ISP 的限制。

```bash
## 验证 Docker 安装
docker --version

## 检查 NVIDIA GPU 驱动程序
nvidia-smi

## 验证 Docker GPU 支持
docker run --rm --gpus all nvcr.io/nvidia/sglang:26.02-py3 nvidia-smi

## 检查可用磁盘空间
df -h /
```

如果您看到权限被拒绝错误（例如尝试连接到 Docker 守护程序套接字时被拒绝），请将您的用户添加到 docker 组，这样您就不需要使用 sudo 运行该命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## 步骤 3. 拉取 SGLang 容器

下载最新的 SGLang 容器。此步骤在主机上运行，根据您的网络连接可能需要几分钟。

```bash
## 拉取 SGLang 容器
docker pull nvcr.io/nvidia/sglang:26.02-py3

## 验证镜像已下载
docker images | grep sglang
```

## 步骤 4. 启动 SGLang 容器以服务器模式

以服务器模式启动 SGLang 容器以启用 HTTP API 访问。这在容器内部运行推理服务器，在端口 30000 上公开以供客户端连接。

```bash
## 使用 GPU 支持和端口映射启动容器
docker run --gpus all -it --rm \
  -p 30000:30000 \
  -v /tmp:/tmp \
  nvcr.io/nvidia/sglang:26.02-py3 \
  bash
```

## 步骤 5. 启动 SGLang 推理服务器

在容器内，使用支持的模型启动 HTTP 推理服务器。此步骤在 Docker 容器内运行并启动 SGLang 服务器守护进程。

```bash
## 使用 DeepSeek-V2-Lite 模型启动推理服务器
python3 -m sglang.launch_server \
  --model-path deepseek-ai/DeepSeek-V2-Lite \
  --host 0.0.0.0 \
  --port 30000 \
  --trust-remote-code \
  --tp 1 \
  --attention-backend flashinfer \
  --mem-fraction-static 0.75 &

## 等待服务器初始化
sleep 30

## 检查服务器状态
curl http://localhost:30000/health
```

## 步骤 6. 测试客户端-服务器推理

在主机系统上的新终端中，测试 SGLang 服务器 API 以确保其正常工作。这验证服务器正在接受请求并生成响应。

```bash
## 使用 curl 测试
curl -X POST http://localhost:30000/generate \
  -H "Content-Type: application/json" \
  -d '{
      "text": "What does NVIDIA love?",
      "sampling_params": {
          "temperature": 0.7,
          "max_new_tokens": 100
      }
  }'
```

## 步骤 7. 测试 Python 客户端 API

创建一个简单的 Python 脚本以测试对 SGLang 服务器的程序化访问。这在主机系统上运行并演示如何将 SGLang 集成到应用程序中。

```python
import requests

## 向服务器发送提示
response = requests.post('http://localhost:30000/generate', json={
  'text': 'What does NVIDIA love?',
  'sampling_params': {
      'temperature': 0.7,
      'max_new_tokens': 100,
  },
})

print(f"Response: {response.json()['text']}")
```

## 步骤 8. 验证安装

确认服务器模式和离线模式都正常工作。此步骤验证完整的 SGLang 设置并确保可靠运行。

```bash
## 检查服务器模式（从主机）
curl http://localhost:30000/health
curl -X POST http://localhost:30000/generate -H "Content-Type: application/json" \
  -d '{"text": "Hello", "sampling_params": {"max_new_tokens": 10}}'

## 检查容器日志
docker ps
docker logs <CONTAINER_ID>
```

## 步骤 9. 清理和回滚

停止并删除容器以清理资源。此步骤将您的系统恢复到原始状态。

> [!WARNING]
> 这将停止所有 SGLang 容器并删除临时数据。

```bash
## 停止所有 SGLang 容器
docker ps | grep sglang | awk '{print $1}' | xargs docker stop

## 删除停止的容器
docker container prune -f

## 删除 SGLang 镜像（可选）
docker rmi nvcr.io/nvidia/sglang:26.02-py3
```

## 步骤 10. 后续步骤

成功部署 SGLang 后，您可以：

- 使用 `/generate` 端点将 HTTP API 集成到您的应用程序中
- 通过更改 `--model-path` 参数尝试不同的模型
- 通过调整 `--tp`（张量并行）设置来扩展使用多个 GPU
- 使用您选择的容器编译平台部署生产工作负载

## 故障排除

常见问题及其解决方案：

| 症状 | 原因 | 解决方法 |
|-------|-------|-------|
| 容器启动时出现 GPU 错误 | 缺少 NVIDIA 驱动程序/工具包 | 安装 nvidia-container-toolkit，重启 Docker |
| 服务器响应 404 或连接被拒绝 | 服务器未完全初始化 | 等待 60 秒，检查容器日志 |
| 模型加载期间出现内存不足错误 | GPU 内存不足 | 使用较小的模型或增加 --tp 参数 |
| 模型下载失败 | 网络连接问题 | 检查互联网连接，重试下载 |
| 权限被拒绝访问 /tmp | 卷挂载问题 | 使用完整路径：-v /tmp:/tmp 或创建专用目录 |

> [!NOTE]
> DGX Spark 使用统一内存架构 (UMA)，允许 GPU 和 CPU 之间动态共享内存。
> 许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，您也可能遇到内存问题。
> 如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

---

*翻译完成*
