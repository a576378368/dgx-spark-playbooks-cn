# 构建和部署多智能体聊天机器人

> 在您的 Spark 上部署多智能体聊天机器人系统并与智能体聊天

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

本操作指南向您展示如何使用 DGX Spark 原型设计、构建和部署完全本地的多智能体系统。
由于具有 128GB 的统一内存，DGX Spark 可以并行运行多个 LLM 和 VLM - 实现智能体之间的交互。

核心是一个由 gpt-oss-120B 驱动的监督智能体，协调专门的下游智能体进行编码、检索增强生成（RAG）和图像理解。
感谢 DGX Spark 对流行 AI 框架和库的开箱即用支持，开发和原型设计快速且无摩擦。
这些组件共同展示了如何在本地高性能硬件上高效执行复杂的多模态工作流。

## 您将实现的目标

您将在您的 DGX Spark 上运行一个完整的多智能体聊天机器人系统，可通过
您的本地 Web 浏览器访问。
设置包括：
- 使用 llama.cpp 服务器和 TensorRT LLM 服务器提供 LLM 和 VLM 模型服务
- 为模型推理和文档检索提供 GPU 加速
- 使用由 gpt-oss-120B 驱动的监督智能体进行多智能体系统编排
- MCP（模型上下文协议）服务器作为监督智能体的工具

## 先决条件

- DGX Spark 设备已设置并可访问
- DGX Spark GPU 上没有其他进程在运行
- 有足够的磁盘空间用于模型下载

> [!NOTE]
> 此演示默认使用 DGX Spark 的 128GB 内存中的约 120GB。
> 请确保您的 Spark 上没有其他工作负载正在运行，使用 `nvidia-smi`，或切换到较小的监督模型，如 gpt-oss-20B。

## 时间与风险

* **预计时间**：30 分钟到 1 小时
* **风险**：
  * Docker 权限问题可能需要用户组更改和会话重启
  * 设置包括下载 gpt-oss-120B（~63GB）、Deepseek-Coder:6.7B-Instruct（~7GB）和 Qwen3-Embedding-4B（~4GB）的模型文件，具体取决于网络速度，可能需要 30 分钟到 2 小时
* **回滚方案**：使用提供的清理命令停止并删除 Docker 容器。
* **最后更新**：2025年11月20日
  * 修复在 DGX Spark 上运行 llama.cpp 的中断命令

---

## 操作说明

## 步骤 1. 配置 Docker 权限

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

## 步骤 2. 克隆存储库

```bash
git clone https://github.com/NVIDIA/dgx-spark-playbooks
cd dgx-spark-playbooks/nvidia/multi-agent-chatbot/assets
```

## 步骤 3. 运行模型下载脚本

```bash
chmod +x model_download.sh
./model_download.sh
```

设置脚本将负责从 HuggingFace 拉取模型 GGUF 文件。
拉取的模型文件包括 gpt-oss-120B（~63GB）、Deepseek-Coder:6.7B-Instruct（~7GB）和 Qwen3-Embedding-4B（~4GB）。
具体取决于网络速度，这可能需要 30 分钟到 2 小时。

## 步骤 4. 启动应用程序的 Docker 容器

```bash
docker compose -f docker-compose.yml -f docker-compose-models.yml up -d --build
```
此步骤构建基础 llama.cpp 服务器镜像并启动所有必需的 Docker 服务以提供模型、后端 API 服务器和前端 UI。
具体取决于网络速度，此步骤可能需要 10 到 20 分钟。
等待所有容器变得就绪和健康。

```bash
watch 'docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"'
```

## 步骤 5. 访问前端 UI

打开您的浏览器并转到：http://localhost:3000

> [!NOTE]
> 如果您通过 SSH 连接在远程 GPU 上运行此程序，在新终端窗口中，您需要运行以下命令，以便能够通过 localhost:3000 访问 UI，并且 UI 能够与 localhost:8000 的后端通信。

>```ssh -L 3000:localhost:3000 -L 8000:localhost:8000  username@IP-address```

## 步骤 6. 尝试示例提示

单击前端上的任何图块以尝试监督智能体和其他智能体。

**RAG 智能体**：
在尝试 RAG 智能体的示例提示之前，通过访问链接上传示例 PDF 文档 [NVIDIA Blackwell 白皮书](https://images.nvidia.com/aem-dam/Solutions/geforce/blackwell/nvidia-rtx-blackwell-gpu-architecture.pdf)
作为上下文，将 PDF 下载到本地文件系统，单击左侧边栏"上下文"下的绿色"上传文档"按钮，然后确保在"选择源"部分中勾选框。

## 步骤 8. 清理和回滚

完全删除容器并释放资源的步骤。

从多智能体聊天机器人项目的根目录，运行以下命令：

```bash
docker compose -f docker-compose.yml -f docker-compose-models.yml down

docker volume rm "$(basename "$PWD")_postgres_data"
```

## 步骤 9. 后续步骤

- 尝试使用多智能体聊天机器人系统使用不同的提示。
- 通过遵循存储库中的说明尝试不同的模型。
- 尝试添加新的 MCP（模型上下文协议）服务器作为监督智能体的工具。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 无法访问 URL 的闭源仓库 | 某些 HuggingFace 模型有访问限制 | 重新生成您的 [HuggingFace 令牌](https://huggingface.co/docs/hub/en/security-tokens)；并在您的 Web 浏览器上请求访问[闭源模型](https://huggingface.co/docs/hub/en/models-gated#customize-requested-information) |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。
> 由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
