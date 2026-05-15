# LM Studio on DGX Spark

> 在 Spark 设备上部署 LM Studio 并提供 LLM 服务；使用 LM Link 远程访问模型。

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
  - [JavaScript](#javascript)
  - [Python](#python)
  - [Bash](#bash)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

LM Studio 是一个应用程序，用于在您自己的硬件上完全发现、运行和提供大型语言模型服务。您可以私密且免费地运行本地 LLM，如 gpt-oss、Qwen3、Gemma3、DeepSeek 和许多其他模型。

本操作指南向您展示如何在 NVIDIA DGX Spark 设备上部署 LM Studio 以使用 GPU 加速本地运行 LLM。在 DGX Spark 上运行 LM Studio 使 Spark 能够作为您自己的私有高性能 LLM 服务器。

**LM Link**（可选）允许您从另一台机器使用 Spark 的模型，就像它们是本地的。您可以通过端到端加密连接链接您的 DGX Spark 和您的笔记本电脑（或其他设备），以便您可以从笔记本电脑加载和运行 Spark 上的模型，而无需在同一 LAN 上或打开网络访问。请参阅 [LM Link](https://lmstudio.ai/link) 和操作说明中的步骤 3b。

## 您将实现的目标

您将在 NVIDIA DGX Spark 设备上部署 LM Studio 以运行 **Nemotron 3 Nano Omni**（`nvidia/nemotron-3-nano-omni`），并从您的笔记本电脑使用该模型。更具体地说，您将：

- 在 Spark 上安装 **llmster**，一个完全无头的、终端原生的 LM Studio
- 通过 API 在 DGX Spark 上本地运行 LLM 推理
- 使用 LM Studio SDK 从您的笔记本电脑与模型交互
- 可选地使用 **LM Link** 通过加密链接连接 Spark 和笔记本电脑，以便远程模型看起来像本地（不需要相同的网络或绑定设置）

## 开始前须知

- [设置本地网络访问](https://build.nvidia.com/spark/connect-to-your-spark) 到您的 DGX Spark 设备
- 使用终端/命令行界面
- 了解 REST API 概念

## 先决条件

**硬件要求：**
- 具有 ARM64 处理器和 Blackwell GPU 架构的 DGX Spark 设备
- 最小 65GB GPU 显存，推荐 70GB 或以上
- 至少 65GB 可用存储空间，推荐 70GB 或以上

**软件要求：**
- NVIDIA DGX OS
- 客户端设备（Mac、Windows 或 Linux）
- 笔记本电脑和 DGX Spark 必须在同一本地网络上
- 下载包和模型的网络访问权限

## 模型支持矩阵
要探索 LM Studio 中的所有支持模型，请查看 [LM Studio 模型目录](https://lmstudio.ai/models) 页面。

| 模型 | 支持状态 | 模型路径 |
|------|---------|----------|
| **Nemotron 3 Nano Omni** | ✅ | `nvidia/nemotron-3-nano-omni` |
| **Qwen3.6-35B-A3B** | ✅ | `qwen/qwen3.6-35b-a3b` |
| **GPT-OSS-120B** | ✅ | `openai/gpt-oss-120b` |

## LM Link（可选）

[LM Link](https://lmstudio.ai/link) 允许您**远程使用本地模型**。您链接机器（例如您的 DGX Spark 和您的笔记本电脑），然后在 Spark 上加载模型并从笔记本电脑使用它们，就像它们是本地的一样。

- **端到端加密** - 基于 Tailscale 网状 VPN；设备不暴露于公共互联网。
- **与本地服务器配合使用** - 任何连接到 LM Studio 的本地 API（例如 `localhost:1234`）的工具都可以使用您的 Link 的模型，包括 Codex、Claude Code、OpenCode 和 LM Studio SDK。
- **预览版** - 免费最多 2 个用户，每个用户最多 5 个设备（总共 10 个设备）。在 [lmstudio.ai/link](https://lmstudio.ai/link) 创建您的 Link。

如果您使用 LM Link，则可以跳过将服务器绑定到 `0.0.0.0` 和使用 Spark 的 IP；一旦设备链接，将您的笔记本电脑指向 `localhost:1234`，远程模型将出现在模型加载器中。

## 辅助文件

所有必需的资源可以在下面找到。这些示例脚本可以在操作说明的步骤 7 中使用。

- [run.js](https://github.com/lmstudio-ai/docs/blob/main/_assets/nvidia-spark-playbook/js/run.js) - JavaScript 脚本，用于向 Spark 发送测试提示
- [run.py](https://github.com/lmstudio-ai/docs/blob/main/_assets/nvidia-spark-playbook/py/run.py) - Python 脚本，用于向 Spark 发送测试提示
- [run.sh](https://github.com/lmstudio-ai/docs/blob/main/_assets/nvidia-spark-playbook/bash/run.sh) - Bash 脚本，用于向 Spark 发送测试提示

## 时间与风险

* **预计时间：** 15-30 分钟（包括模型下载时间，具体取决于您的互联网连接和模型大小）
* **风险等级：** 低
  * 大型模型下载可能需要大量时间，具体取决于网络速度
* **回滚方案：**
  * 可以从模型目录手动删除下载的模型。
  * 卸载 LM Studio 或 llmster
* **最后更新：** 2026年4月28日
  * 引入 Nemotron Omni 作为示例

---

## 操作说明

## 步骤 1. 在 DGX Spark 上安装 llmster

**llmster** 是 LM Studio 的终端原生、无头 LM Studio '守护进程'。

您可以在服务器、云实例、没有 GUI 的机器上安装它，或者 просто 在您的计算机上安装。这对于在 DGX Spark 上以无头模式运行 LM Studio，然后通过 API 从您的笔记本电脑连接到它非常有用。

**在您的 Spark 上，通过运行以下命令安装 llmster：**

```bash
curl -fsSL https://lmstudio.ai/install.sh | bash
```

对于 Windows：
```bash
irm https://lmstudio.ai/install.ps1 | iex
```

安装后，按照终端输出中的说明将 `lms` 添加到您的 PATH。使用 `lms` CLI 或 SDK / LM Studio V1 REST API（具有[增强功能](https://lmstudio.ai/docs/developer/rest)的新功能）/ OpenAI 兼容 REST API 与 LM Studio 交互。

## 步骤 2. 下载所需的辅助文件

在您的本地终端中运行以下 curl 命令以下载完成本操作指南后续步骤所需的文件。您可以选择 Python、JavaScript 或 Bash。

```bash
## JavaScript
curl -L -O https://raw.githubusercontent.com/lmstudio-ai/docs/main/_assets/nvidia-spark-playbook/js/run.js

## Python
curl -L -O https://raw.githubusercontent.com/lmstudio-ai/docs/main/_assets/nvidia-spark-playbook/py/run.py

## Bash
curl -L -O https://raw.githubusercontent.com/lmstudio-ai/docs/main/_assets/nvidia-spark-playbook/bash/run.sh
```

## 步骤 3. 启动 LM Studio API 服务器

使用 `lms`，LM Studio 的 CLI，从您的终端启动服务器。启用本地网络访问，这允许运行在您机器上的 LM Studio API 服务器被同一本地网络上的所有其他设备访问（确保它们是可信设备）。为此，运行以下命令：

```bash
lms server start --bind 0.0.0.0 --port 1234
```

要测试您的笔记本电脑和 Spark 之间的连接性，请在您的本地终端中运行以下命令

```bash
curl http://<SPARK_IP>:1234/api/v1/models 
```
其中 `<SPARK_IP>` 是您设备的 IP 地址。您可以通过在您的 Spark 上运行以下命令找到您的 Spark 的 IP 地址：

```bash
hostname -I
```

## 步骤 4.（可选）使用 LM Link 连接

**LM Link** 允许您从您的笔记本电脑（或其他设备）使用 Spark 的模型，就像它们是本地的一样，通过端到端加密连接。您不需要在同一本地网络上或将服务器绑定到 `0.0.0.0`。

1. **创建 Link** - 转到 [lmstudio.ai/link](https://lmstudio.ai/link) 并按照 **创建您的 Link** 设置您的私有 LM Link 网络。
2. **链接两个设备** - 在您的 DGX Spark（llmster）和您的笔记本电脑上，登录并加入相同的 Link。LM Link 使用 Tailscale 网状 VPN；设备通信时不打开到互联网的端口。
3. **使用远程模型** - 在您的笔记本电脑上，打开 LM Studio（或使用本地服务器）。您的 Spark 的远程模型将出现在模型加载器中。任何连接到 `localhost:1234` 的工具 - 包括 LM Studio SDK、Codex、Claude Code、OpenCode 和步骤 7 中的脚本 - 都可以使用这些模型而无需更改端点。

LM Link 处于 **预览版**，最多免费 2 个用户，每个用户最多 5 个设备。有关详细信息和限制，请参阅 [LM Link](https://lmstudio.ai/link)。

## 步骤 5. 下载模型到您的 Spark

作为示例，从 LM Studio 目录下载 **NVIDIA Nemotron 3 Nano Omni**（`nvidia/nemotron-3-nano-omni`），以便您可以在 Spark 上使用大量统一内存运行它。

```bash
lms get nvidia/nemotron-3-nano-omni
```

由于其大尺寸，此下载需要一些时间。通过列出您的模型验证模型已成功下载：

```bash
lms ls
```

## 步骤 6. 加载模型

在您的 Spark 上加载模型，以便它可以响应来自您的笔记本电脑的请求。

```bash
lms load nvidia/nemotron-3-nano-omni
```

## 步骤 7. 在笔记本电脑上设置一个使用 LM Studio SDK 的简单程序

安装 LM Studio SDK 并使用简单脚本向您的 Spark 发送提示并验证响应。要快速开始，我们提供以下 Python、JavaScript 和 Bash 的简单脚本。从本操作指南的概述页面下载脚本并在包含脚本的目录中运行相应的命令。

> [!NOTE]
> 在每个脚本中，将 `<SPARK_IP>` 替换为您的 DGX Spark 在本地网络上的 IP 地址。

### JavaScript

先决条件：用户已安装 `npm` 和 `node`

```bash
npm install @lmstudio/sdk
node run.js
```

### Python

先决条件：用户已安装 `uv`

```bash
uv run --script run.py
```

### Bash

先决条件：用户已安装 `jq` 和 `curl`

```bash
bash run.sh
```

## 步骤 8. 后续步骤

- 尝试从 [LM Studio 模型目录](https://lmstudio.ai/models) 下载并提供不同的模型。
- 使用 [LM Link](https://lmstudio.ai/link) 连接更多设备，并通过端到端加密从任何地方使用您的 Spark 的模型。

## 步骤 9. 清理和回滚

如需完全移除，请删除并卸载 LM Studio。请注意，LM Studio 将模型与应用程序分开存储。卸载 LM Studio 将不会删除下载的模型，除非您明确删除它们。

如果您想删除整个 LM Studio 应用程序，请首先从托盘中退出 LM Studio，然后将应用程序移至垃圾箱。

要卸载 llmster，请删除文件夹 `~/.lmstudio/llmster`。

要删除下载的模型，请删除 `~/.lmstudio/models/` 的内容。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| API 返回 "model not found" 错误 | 模型未下载或未在 LM Studio 中加载 | 运行 `lms ls` 验证下载状态，然后使用 `lms load {model-name}` 加载模型 |
| `lms` 命令未找到 | 假设成功安装的 PATH 问题 | 通过运行 `source ~/.bashrc` 刷新您的 shell |
| 模型加载失败 - CUDA 内存不足 | 模型太大，无法获得可用的 VRAM | 切换到较小的模型或不同的量化 |
| LM Link：设备未连接或远程模型不可见 | 设备不在同一个 Link 中，或未在两侧设置 LM Link | 确保 Spark 和笔记本电脑都在 [lmstudio.ai/link](https://lmstudio.ai/link) 上登录并加入同一个 Link。加入后重启 LM Studio/llmster。有关工作原理，请参阅 [LM Link](https://lmstudio.ai/link)。|

> [!NOTE] 
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。
> 由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
