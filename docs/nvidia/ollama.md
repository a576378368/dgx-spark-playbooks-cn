# Ollama

> 安装和使用 Ollama

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

本操作指南演示如何使用 NVIDIA Sync 的 Custom Apps 功能在您的 NVIDIA Spark 设备上设置远程访问 Ollama 服务器。您将在 Spark 设备上安装 Ollama，配置 NVIDIA Sync 以创建 SSH 隧道，并从您的本地机器访问 Ollama API。这消除了在您的网络上暴露端口的需要，同时通过安全的 SSH 隧道从您的笔记本电脑启用 AI 推理。

## 您将实现的目标

您将在您的 NVIDIA Spark 上运行 Ollama 并通过 API 调用从您的本地笔记本电脑访问它。此设置允许您在本地机器上构建应用程序或使用工具，这些工具通过 Ollama API 进行大型语言模型推理，利用 Spark 设备的强大 GPU 功能，而无需复杂的网络配置。

## 开始前须知

- 使用 SSH 连接和系统托盘应用程序
- 基本了解终端命令和 cURL 进行 API 测试
- 了解 REST API 概念和 JSON 格式
- 有容器环境和 GPU 加速工作负载的经验

## 先决条件

- 已设置并连接到您的网络的 DGX Spark 设备
- 已安装并连接到您的 Spark 的 NVIDIA Sync
- 用于测试 API 调用的本地机器的终端访问

## 时间与风险

* **持续时间**：初始设置需要 10-15 分钟，模型下载需要 2-3 分钟（因模型大小而异）

* **风险等级**：低 - 没有系统级更改，通过停止自定义应用很容易逆转

* **回滚方案**：在 NVIDIA Sync 中停止自定义应用，并在需要时使用标准包删除卸载 Ollama

* **最后更新：** 2025年10月12日
  * 首次发布

---

## 操作说明

## 步骤 1. 验证 Ollama 安装状态

**描述**：检查您的 NVIDIA Spark 设备上是否已安装 Ollama。这通过 NVIDIA Sync 终端在 Spark 设备上运行，以确定是否需要安装。

```bash
ollama --version
```

如果您看到版本信息，请跳到步骤 3。如果得到 "command not found"，请继续步骤 2。

## 步骤 2. 在您的 Spark 设备上安装 Ollama

**描述**：使用官方安装脚本下载并安装 Ollama。这在 Spark 设备上运行并安装 Ollama 二进制文件和服务组件。

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

等待安装完成。您应该看到表示安装成功的输出。

## 步骤 3. 下载和验证语言模型

**描述**：从您的 Spark 设备拉取语言模型。这下载模型文件并使其可用于推理。示例使用 Qwen2.5 30B，针对 Blackwell GPU 进行了优化。

```bash
ollama pull qwen2.5:32b
```

预期输出：
```
pulling manifest
pulling 58574f2e94b9: 100% ████████████████████████████  18 GB
pulling 53e4ea15e8f5: 100% ████████████████████████████ 1.5 KB
pulling d18a5cc71b84: 100% ████████████████████████████  11 KB
pulling cff3f395ef37: 100% ████████████████████████████  120 B
pulling 3cdc64c2b371: 100% ████████████████████████████  494 B
verifying sha256 digest
writing manifest
success
```

[此处省略剩余部分，由于文件较大]

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| `ollama` 命令未找到 | Ollama 未安装 | 运行安装脚本：`curl -fsSL https://ollama.com/install.sh | sh` |
| `curl: (7) Failed to connect` | Spark 不可达 | 检查 NVIDIA Sync 连接和网络 |
| 模型下载失败 | 网络问题或 Hugging Face 不可达 | 检查网络连接和重试 |
| GPU 未检测到 | CUDA 驱动程序问题 | 验证 `nvidia-smi` 和驱动程序安装 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的灵活共享。一些软件仍在赶上 UMA 行为。如果您意外遇到内存压力，您可以尝试刷新页面缓存（在共享系统上小心使用）：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的平台问题，请参阅 [DGX Spark 已知问题](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html) 文档。
