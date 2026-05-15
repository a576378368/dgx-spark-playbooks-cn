# Spark & Reachy 照片亭

> 使用 DGX Spark 和 Reachy Mini 的 AI 增强照片亭

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
  - [指南](#指南)
  - [服务配置](#服务配置)
- [开发](#开发)
  - [自定义配置参数](#自定义配置参数)
  - [使用新工具扩展演示](#使用新工具扩展演示)
  - [创建你自己的服务](#创建你自己的服务)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

![封面](assets/teaser.jpg)

Spark & Reachy 照片亭是一个交互式和事件驱动的照片亭演示，结合了 **DGX Spark™** 和 **Reachy Mini** 机器人，以创建引人入胜的多模态 AI 体验。该系统展示了：

- **一个多模态代理**，使用 `NeMo Agent Toolkit` 构建
- **一个 ReAct 循环**，由 `openai/gpt-oss-20b` LLM 驱动，由 `TensorRT-LLM` 提供支持
- **语音交互**，基于 `nvidia/riva-parakeet-ctc-1.1B` 和 `hexgrad/Kokoro-82M`
- **图像生成**，使用 `black-forest-labs/FLUX.1-Kontext-dev` 进行图像到图像的重新样式化
- **用户位置跟踪**，使用 `facebookresearch/detectron2` 和 `FoundationVision/ByteTrack` 构建
- **MinIO**，用于存储捕获/生成的图像以及通过 QR 码共享

演示基于通过消息总线通信的多个服务。

![架构图](assets/architecture-diagram.png)

另请参阅此 playbook 的演示视频：[视频](https://www.youtube.com/watch?v=6f1x8ReGLjc)

> [!NOTE]
> 此 playbook 适用于 Reachy Mini Lite。Reachy Mini（带板载 Raspberry Pi）可能需要轻微调整。为简化起见，我们将在本 playbook 中将机器人统称为 Reachy。

## 你将实现的目标

你将在 DGX Spark 上部署一个完整照片亭系统，本地运行多个推理模型——LLM、图像生成、语音识别、语音生成和计算机视觉——所有这些都不依赖云。Reachy 机器人通过自然对话与用户交互，拍摄照片，并根据提示生成自定义图像，展示了在边缘硬件上实时多模态 AI 处理。

## 开始前须知

- 基本的 Docker 和 Docker Compose 知识
- 基本的网络配置技能

## 先决条件

**硬件要求：**
- [NVIDIA DGX Spark](https://www.nvidia.com/en-us/products/workstations/dgx-spark/)
- 用于直接在 DGX Spark 上运行此 playbook 的显示器、键盘和鼠标。
- [Reachy Mini 或 Reachy Mini Lite 机器人](https://pollen-robotics-reachy-mini.hf.space/)

> [!TIP]
> 确保你的 Reachy 机器人固件是最新的。你可以找到更新它的说明[此处](https://huggingface.co/spaces/pollen-robotics/Reachy_Mini)。为简化起见，我们将机器人统称为 Reachy。

**软件要求：**
- 官方 [DGX Spark OS](https://docs.nvidia.com/dgx/dgx-spark/dgx-os.html) 镜像，包括所有必需的实用程序，如 Git、Docker、NVIDIA 驱动程序和 NVIDIA Container Toolkit
- DGX Spark 的互联网连接
- NVIDIA NGC 个人 API 密钥 (**`NVIDIA_API_KEY`**）。[创建一个密钥](https://org.ngc.nvidia.com/setup/api-keys)（如果需要）。确保在创建密钥时启用 `NGC Catalog` 范围。
- Hugging Face 访问令牌 (**`HF_TOKEN`**)。[创建一个令牌](https://huggingface.co/settings/tokens)（如果需要）。确保创建具有 _Read access to contents of all public gated repos you can access_（读取你可以访问的所有公共门控存储库内容的权限）的令牌。

## 辅助文件

所有必需的资产都可以在 [Spark & Reachy 照片亭存储库](https://github.com/NVIDIA/spark-reachy-photo-booth) 中找到。

- Docker Compose 应用程序
- 各种配置文件
- 所有服务的源代码
- 详细文档

## 时间与风险

* **估计时间：** 2 小时包括硬件设置、容器构建和模型下载
* **风险级别：** 中等
* **回滚：** 可以停止和删除 Docker 容器以释放资源。可以从缓存目录中删除下载的模型。可以安全地断开机器人和外设连接。可以通过删除自定义设置来恢复网络配置。
* **最后更新：** 2026年4月1日
  * 1.0.0 首次发布
  * 1.0.1 文档改进

---

## 操作说明

## 步骤 1. 克隆仓库

为了轻松管理容器而无需 `sudo`，你必须在 `docker` 组中。如果你选择跳过此步骤，你将需要使用 `sudo` 运行 Docker 命令。

打开新终端并测试 Docker 访问。在终端中，运行：

```bash
docker ps
```

如果你看到权限被拒绝错误（类似于尝试连接到 Docker 守护进程套接字时被拒绝），将你的用户添加到 docker 组，这样你就不需要使用 `sudo` 运行该命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

```bash
git clone https://github.com/NVIDIA/spark-reachy-photo-booth.git
cd spark-reachy-photo-booth
```

> [!WARNING]
> 此 playbook 预期在你的 DGX Spark 上直接运行，并使用包含的 Web 浏览器。

## 步骤 2. 创建你的环境

```bash
cp .env.example .env
```

编辑 `.env` 并设置：

- **`NVIDIA_API_KEY`**：你的 NVIDIA API 密钥（必须以 `nvapi-...` 开头）
- **`HF_TOKEN`**：你的 Hugging Face 令牌（必须以 `hf_...` 开头）
- **`EXTERNAL_MINIO_BASE_URL`**：保留不变，除非你想要（请参阅"在本地网络上启用 QR 码共享"部分）

要访问 FLUX.1-Kontext-dev 模型，请登录你的 Hugging Face 账户，然后审查并接受 [FLUX.1-Kontext-dev](https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev) 和 [FLUX.1-Kontext-dev-onnx](https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev-onnx) 许可协议和可接受使用政策。

其余值为本地开发配置了合理的默认值（MinIO）。对于生产部署或不受信任的环境，应更改这些值并安全存储。

## 步骤 3. 设置 Reachy

- 将电源线插入 Reachy 的底部并插入电源插座。
- 将 USB-C 线缆插入 Reachy 的底部并插入 DGX Spark。
- 启动 Reachy 底部的电源开关。开关旁边的 LED 应该变红。

你可以通过运行验证机器人是否被检测到：

```bash
lsusb | grep Reachy
```

你应该在终端中看到一个类似于 `Bus 003 Device 003: ID 38fb:1001 Pollen Robotics Reachy Mini Audio` 的设备打印。

运行以下命令以确保 Reachy 扬声器可以达到最大音量。

```bash
./robot-controller-service/scripts/speaker_setup.sh
```

![设置](assets/setup.jpg)

## 步骤 4. 启动堆栈

登录到 nvcr.io 注册表：
```bash
docker login nvcr.io -u "\$oauthtoken"
```

当提示输入密码时，输入你的 NGC 个人 API 密钥。

```bash
docker compose up --build -d
```

此命令拉取并构建容器镜像，并下载所需的模型工件。首次运行可能需要 30 分钟到 2 小时，具体取决于你的互联网速度。后续运行通常在大约 5 分钟内完成。

## 步骤 5. 在浏览器中打开 UI

在 DGX Spark 上，打开 Firefox（预安装）并浏览到 **Web UI**：[http://127.0.0.1:3001](http://127.0.0.1:3001)。

> [!TIP]
> 仅当所有容器都正在运行时，Web UI 才可访问。
> 你还可以使用 `docker compose ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"` 检查所有容器的状态。
> 如果一个或多个容器失败，请使用 `docker compose logs -f <container_name>` 检查日志。

> [!TIP]
> 你可以通过启用 X11 转发的 ssh 会话远程 **观看** 进行中的交互（`ssh -X <USER>@<SPARK_IP>`）。
> 你应该能够从此会话打开 Firefox 并连接到 [http://127.0.0.1:3001](http://127.0.0.1:3001)。

> [!NOTE]
> UI 对图像生成的性能有轻微影响。为了优化体验中的图像生成步骤的性能，你可以安装并使用 Chromium 而不是 Firefox，以及降低显示分辨率。

## 步骤 6. 可选：在本地网络上启用 QR 码共享

Reachy 可以拍摄人们的照片并根据它们生成图像。Web UI 显示生成的图像以及 QR 码以供下载。本节解释如何设置系统，以便 QR 码可以从用户手机上打开。

要使 QR 码在你的手机上打开，你的 DGX Spark 和手机必须在同一个本地网络上。确保你的路由器允许网络内的设备到设备通信。

#### 1. 找到你的 Spark 的本地 IP 地址

在 Spark 上，运行以下命令：

```bash
ip -f inet addr show enP7s7 | grep inet
```

如果您的 Spark 通过 Wi-Fi 连接，请使用此命令

```bash
ip -f inet addr show wlP9s9 | grep inet
```

找到 LAN 上的 IPv4（通常类似于 `192.168.x.x` 或 `10.x.x.x`）。

#### 2. 确保 MinIO 可以从你的手机访问

- **同一网络**：将你的手机连接到与 DGX Spark 相同的 Wi-Fi/LAN。
- **防火墙**：默认情况下，DGX Spark 不会阻止传入请求。如果你安装了防火墙，请允许 **`9010` (MinIO API)** 的入站流量到 DGX Spark。

#### 3. 更新 `.env` 并重新启动

编辑 `.env` 并替换：

- **`EXTERNAL_MINIO_BASE_URL=127.0.0.1:9010`** → **`EXTERNAL_MINIO_BASE_URL=<SPARK_LAN_IP>:9010`**

然后重新启动：

```bash
docker compose down
docker compose up --build -d
```

## 步骤 7. 可选：进一步操作和自定义应用程序

### 指南

- [入门](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/docs/getting-started.md) – 详细的设置和配置指南
- [编写你的第一个服务](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/docs/writing-your-first-service.md) – 如何创建和集成新服务

### 服务配置

每个服务都有自己的 README，其中包含自定义、环境变量和服务特定配置的详细信息：

| 服务 | 描述 |
|------|------|
| [agent-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/agent-service/README.md) | LLM 驱动的代理工作流和决策逻辑 |
| [animation-compositor-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/animation-compositor-service/README.md) | 结合动画片段和音频混合 |
| [animation-database-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/animation-database-service/README.md) | 动画库和程序动画生成 |
| [camera-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/camera-service/README.md) | 相机捕获和图像获取 |
| [interaction-manager-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/interaction-manager-service/README.md) | 事件编排和机器人语音管理 |
| [metrics-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/metrics-service/README.md) | 指标收集和监控 |
| [remote-control-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/remote-control-service/README.md) | 基于 Web 的远程控制界面 |
| [robot-controller-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/robot-controller-service/README.md) | 直接机器人硬件控制 |
| [speech-to-text-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/speech-to-text-service/README.md) | 音频转录（NVIDIA Riva/Parakeet） |
| [text-to-speech-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/text-to-speech-service/README.md) | 语音合成 |
| [tracker-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/tracker-service/README.md) | 人物检测和跟踪 |
| [ui-server-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/ui-server-service/README.md) | Web UI 的后端 |

有关自定义服务配置、使用新工具扩展演示或创建你自己的服务的详细指南，请参阅 [开发](development) 选项卡。

---

## 开发

## 开发

本节提供了自定义和开发 Reachy 照片亭应用程序的综合说明。如果你正在寻找部署和运行应用程序而不进行修改，请参考 [操作说明](instructions) 选项卡 - 此开发指南专门针对需要对应用程序进行修改的人。

## 步骤 1. 系统依赖

为了使用仓库的 Python 开发设置，请安装以下软件包：

```bash
sudo apt install python3.12-dev portaudio19-dev
```

要创建 Python **venv**，请按照[此处](https://docs.astral.sh/uv/getting-started/installation/)的说明安装 uv。

然后运行以下命令以生成 Python **venv**：

```bash
uv sync --all-packages
```

## 步骤 2. 了解构建和开发过程

每个以 `-service` 结尾的文件夹都是在其自己的容器中运行的独立 Python 程序。你必须始终通过与存储库根目录的 `docker-compose.yaml` 交互来启动服务。你可以通过运行以下命令启用所有 Python 服务的代码热重载：

```bash
docker compose up --build --watch
```

每当你更改存储库中的 Python 代码时，相关的容器将被更新并自动重启。

[入门](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/docs/getting-started.md) 指南提供了构建系统、开发工作流、调试策略和监控基础设施的综合指南。

## 步骤 3. 对应用程序进行更改

现在你的开发环境已设置好，以下是开发人员通常探索的最常见的自定义。

### 自定义配置参数

每个服务都有可配置的参数，包括系统提示、音频设备、模型设置等。请检查各个服务的 README 和 `src/configuration.py` 文件以获取详细的配置选项。请注意，`src/configuration.py` 中的默认配置也可能在 `compose.yaml` 文件中被覆盖。请查看以下服务以入门：

- [speech-to-text-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/speech-to-text-service/README.md) - 配置音频设备和转录设置
- [text-to-speech-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/text-to-speech-service/README.md) - 调整语音合成参数
- [agent-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/agent-service/README.md) - 自定义 LLM 系统提示、代理行为和决策逻辑

另请参阅 [操作说明](instructions) 获取所有服务及其 README 的完整列表。

### 使用新工具扩展演示

agent-service 和 interaction-manager-service 是使用新功能扩展演示的核心服务：

- [agent-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/agent-service/README.md) - 在此处添加新代理工具和功能
- [interaction-manager-service](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/interaction-manager-service/README.md) - 管理事件编排和机器人语音

### 创建你自己的服务

[编写你的第一个服务](https://github.com/NVIDIA/spark-reachy-photo-booth/tree/main/docs/writing-your-first-service.md) 指南提供了在系统中对新微服务进行脚手架、实现和集成的逐步教程。按照此指南创建自定义服务以扩展照片亭功能。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 机器人没有声音（音量低） | Reachy 扬声器音量默认设置得太低 | 将 Reachy 扬声器音量增加到最大 |
| 机器人没有声音（设备冲突） | 另一个应用程序捕获 Reachy 扬声器 | 检查 `animation-compositor` 日志中的 "Error querying device (-1)"，验证 Reachy 扬声器未在 Ubuntu 声音设置中设置为系统默认值，确保没有其他应用程序捕获扬声器，然后重新启动演示 |
| 首次启动时图像生成失败 | 瞬态初始化问题 | 重新运行 `docker compose up --build -d` 以解决此问题 |

如果你有任何 Reachy 问题未涵盖此指南，请阅读 [Hugging Face 的官方故障排除指南](https://huggingface.co/docs/reachy_mini/troubleshooting)。

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的动态共享。
> 随着许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，你也可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
