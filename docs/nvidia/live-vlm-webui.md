# Live VLM WebUI

> 通过网络摄像头流式传输实现实时视觉语言模型（VLM）交互

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
  - [命令行选项](#命令行选项)
  - [接受 SSL 证书](#接受-ssl-证书)
  - [授予相机权限](#授予相机权限)
  - [性能优化技巧](#性能优化技巧)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

Live VLM WebUI 是一个用于实时视觉语言模型（VLM）交互和基准测试的通用 Web 界面。它允许您将网络摄像头直接流式传输到任何 VLM 后端（Ollama、vLLM、SGLang 或云 API），并接收实时 AI 驱动的分析。这个工具非常适合测试 VLM 模型、在不同硬件配置上进行性能基准测试，以及探索视觉 AI 功能。

界面提供基于 WebRTC 的视频流、集成的 GPU 监控、可定制的提示，以及对多个 VLM 后端的支持。它与 DGX Spark 中强大的 Blackwell GPU 无缝协作，实现令人印象深刻的速度的实时视觉推理。

## 您将实现的目标

您将在 DGX Spark 上设置一个完整的实时视觉 AI 测试环境，使您能够：

- 流式传输网络摄像头视频并通过 Web 浏览器获得即时的 VLM 分析
- 测试和比较不同的视觉语言模型（Gemma 3、Llama Vision、Qwen VL 等）
- 在模型处理视频帧时实时监控 GPU 和系统性能
- 为各种用例定制提示（对象检测、场景描述、OCR、安全监控）
- 从网络上的任何设备使用 Web 浏览器访问界面

## 开始前须知

- 基本熟悉 Linux 命令行和终端操作
- 基本了解使用 pip 安装 Python 包
- 基本了解 REST API 和服务如何通过 HTTP 通信
- 熟悉 Web 浏览器和网络访问（IP 地址、端口）
- 可选：了解视觉语言模型及其功能（有帮助但非必需）

## 先决条件

**硬件要求：**
- 网络摄像头（笔记本电脑内置摄像头、USB 摄像头或具有相机的远程浏览器）
- 至少 10GB 可用存储空间用于 Python 包和模型下载

**软件要求：**
- 安装了 DGX OS 的 DGX Spark
- Python 3.10 或更高版本（使用 `python3 --version` 验证）
- pip 包管理器（使用 `pip --version` 验证）
- 网络访问权限，用于从 PyPI 下载 Python 包
- 本地运行的 VLM 后端（Ollama 最容易）或云 API 访问权限
- Web 浏览器访问 `https://<SPARK_IP>:8090`

**VLM 后端选项：**
1. **Ollama**（初学者推荐）- 易于安装和使用
2. **vLLM** - 生产工作负载的高性能
3. **SGLang** - 替代的高性能后端
4. **NIM** - NVIDIA 推理微服务，提供优化的性能
5. **云 API** - NVIDIA API 目录、OpenAI 或其他与 OpenAI 兼容的 API

## 辅助文件

所有源代码和文档可以在 [Live VLM WebUI GitHub 存储库](https://github.com/NVIDIA-AI-IOT/live-vlm-webui) 找到。

包将通过 pip 直接安装，因此基本安装不需要额外文件。

## 时间与风险

* **预计时间：** 20-30 分钟（包括 Ollama 安装和模型下载）
  * 5 分钟通过 pip 安装 Live VLM WebUI
  * 10-15 分钟安装 Ollama 并下载模型（取决于模型大小）
  * 5 分钟配置和测试
* **风险等级：** 低
  * Python 包在用户空间安装，与系统隔离
  * 无需系统级更改
  * Web 界面功能需要端口 8090 可访问
  * 自签名 SSL 证书需要浏览器安全异常
* **回滚方案：** 使用 `pip uninstall live-vlm-webui` 卸载 Python 包。Ollama 可以使用标准包删除卸载。不会对 DGX Spark 配置进行持久更改。
* **最后更新：** 2026年1月2日
  * 首次发布

---

## 操作说明

## 步骤 1. 安装 Ollama 作为 VLM 后端

首先，安装 Ollama 以提供视觉语言模型。Ollama 是在 DGX Spark 上本地运行/提供模型的最简单选项之一。

```bash
## 安装 Ollama
curl -fsSL https://ollama.com/install.sh | sh

## 验证安装
ollama --version
```

Ollama 将自动作为系统服务启动并检测您的 Blackwell GPU。

现在下载一个视觉语言模型。我们建议从 `gemma3:4b` 开始进行快速测试：

```bash
## 下载轻量级模型（推荐用于测试）
ollama pull gemma3:4b

## 可以尝试的替代模型：
## ollama pull llama3.2-vision:11b    # 有时质量更好，但速度较慢
## ollama pull qwen2.5-vl:7b          #
```

模型下载可能需要 5-15 分钟，取决于您的网速和模型大小。

验证 Ollama 正常工作：

```bash
## 检查 Ollama API 是否可访问
curl http://localhost:11434/v1/models
```

预期输出应显示 JSON 响应，列出您下载的模型。

## 步骤 2. 安装 Live VLM WebUI

使用 pip 安装 Live VLM WebUI：

```bash
pip install live-vlm-webui
```

安装将下载所有必需的 Python 依赖项并安装 `live-vlm-webui` 命令。

现在启动服务器：

```bash
## 启动 Web 服务器
live-vlm-webui
```

服务器将：
- 自动生成用于 HTTPS 的 SSL 证书（需要用于相机访问）
- 在端口 8090 上启动 WebRTC 服务器
- 自动检测您的 Blackwell GPU

服务器将启动并显示如下输出：

```
Starting Live VLM WebUI...
Generating SSL certificates...
GPU detected: NVIDIA GB10 Blackwell

Access the WebUI at:
  Local URL:   https://localhost:8090
  Network URL: https://<YOUR_SPARK_IP>:8090

Press Ctrl+C to stop the server
```

### 命令行选项

Live VLM WebUI 支持多个命令行选项进行自定义：

```bash
## 指定不同的端口
live-vlm-webui --port 8091

## 使用自定义 SSL 证书
live-vlm-webui --ssl-cert /path/to/cert.pem --ssl-key /path/to/key.pem

## 更改默认 API 端点
live-vlm-webui --api-base http://localhost:8000/v1

## 后台运行（可选）
nohup live-vlm-webui > live-vlm.log 2>&1 &
```

## 步骤 3. 访问 Web 界面

在 Web 浏览器中打开并导航到：

```
https://<YOUR_SPARK_IP>:8090
```

将 `<YOUR_SPARK_IP>` 替换为 DGX Spark 的 IP 地址。您可以使用以下命令找到它：

```bash
hostname -I | awk '{print $1}'
```

**重要：** 您必须使用 `https://`（而不是 `http://`），因为现代浏览器需要安全连接才能访问相机。

### 接受 SSL 证书

由于应用程序使用自签名 SSL 证书，您的浏览器将显示安全警告。这是预期且安全的。

**在 Chrome/Edge 中：**
1. 点击 "**高级**" 按钮
2. 点击 "**继续访问 \<YOUR_SPARK_IP\>（不安全）**"

**在 Firefox 中：**
1. 点击 "**高级...**"
2. 点击 "**接受风险并继续**"

### 授予相机权限

当提示时，允许网站访问您的相机。网络摄像头流应该出现在界面上。

> [!TIP]
> **推荐远程访问：** 为了获得最佳体验，请从同一网络上的笔记本电脑或 PC 访问 Web 界面。这提供了比在 DGX Spark 上本地访问更好的浏览器性能和内置相机访问。

## 步骤 4. 配置 VLM 设置

界面自动检测本地 VLM 后端。在左侧边栏的 **VLM API 配置** 部分验证配置：

**API 端点：** 应显示 `http://localhost:11434/v1`（Ollama）

**模型选择：** 点击下拉菜单并选择您下载的模型（例如 `gemma3:4b`）

**可选设置：**
- **最大令牌数：** 控制响应长度（默认：512，减少到 100-200 以获得更快的响应）
- **帧处理间隔：** 分析之间跳过的帧数（默认：30 帧，增加以获得更慢的速度）

### 性能优化技巧

为了在 DGX Spark Blackwell GPU 上获得最佳性能：

- **模型选择：** `gemma3:4b` 提供 1-2 秒/帧，`llama3.2-vision:11b` 提供较慢速度。
- **帧间隔：** 设置为 60 帧（30 fps 时为 2 秒）或更大，以便舒适查看
- **最大令牌数：** 减少到 100 以获得更快的响应

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。
> 由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

## 步骤 5. 开始分析视频

点击绿色的 "**启动相机并开始 VLM 分析**" 按钮。

界面将：
1. 通过 WebRTC 开始流式传输您的网络摄像头
2. 开始处理帧并向 VLM 发送帧
3. 实时显示 AI 分析结果
4. 在底部显示 GPU/CPU/RAM 指标

您应该看到：
- **实时视频流** 在右侧（带有镜像切换）
- **VLM 分析结果** 覆盖在视频上或在信息框中
- **性能指标** 显示延迟和帧数
- **GPU 监控** 显示 Blackwell GPU 利用率和 VRAM 使用情况

使用 DGX Spark 中的 Blackwell GPU，您应该看到 `gemma3:4b` 的推理时间为 **1-2 秒/帧**，`llama3.2-vision:11b` 的速度类似。

## 步骤 6. 自定义提示

左侧边栏底部的 **提示编辑器** 允许您自定义 VLM 分析的内容。

**快速提示** - 8 个预设可立即使用：
- **场景描述** - "用一句话描述您在此图像中看到的内容。"
- **对象检测** - "列出您在此图像中可以看到的所有对象，用逗号分隔。"
- **活动识别** - "描述人物的活动和他们正在做的事情。"
- **安全监控** - "是否有任何可见的安全隐患？用 'ALERT: 描述' 或 'SAFE' 回答。"
- **OCR/文本识别** - "读取并转录图像中可见的任何文本。"
- 更多...

**自定义提示** - 输入您自己的：

试试这个用于实时 CSV 输出（对于下游应用很有用）：

```
列出您在此图像中可以看到的所有对象，用逗号分隔。
不要包含解释文本。仅输出逗号分隔的列表。
```

VLM 将立即使用新提示进行下一帧分析。这实现了实时"提示工程"，您可以在观看实时结果时迭代和优化提示。

## 步骤 7. 测试不同模型（可选）

想要比较模型？下载另一个模型并切换：

```bash
## 下载另一个模型
ollama pull llama3.2-vision:11b

## 该模型将出现在 Web 界面的模型下拉菜单中
```

在 Web 界面中：
1. 停止 VLM 分析（如果正在运行）
2. 从 **模型** 下拉菜单中选择新模型
3. 再次启动 VLM 分析

在 DGX Spark 的 Blackwell GPU 上比较不同模型的推理速度和质量。

## 步骤 8. 监控性能

底部部分显示实时系统指标：

- **GPU 使用率** - Blackwell GPU 利用率百分比
- **VRAM 使用率** - GPU 内存消耗
- **CPU 使用率** - 系统 CPU 利用率
- **系统 RAM** - 内存使用情况

使用这些指标来：
- 对同一硬件上的不同模型进行基准测试
- 识别性能瓶颈
- 为您的用例优化设置

## 步骤 9. 清理

完成后，在运行服务器的终端中使用 `Ctrl+C` 停止服务器。

要完全删除 Live VLM WebUI：

```bash
pip uninstall live-vlm-webui
```

您的 Ollama 安装和下载的模型仍可用于将来使用。

要同时删除 Ollama（可选）：

```bash
## 卸载 Ollama
sudo systemctl stop ollama
sudo rm /usr/local/bin/ollama
sudo rm -rf /usr/share/ollama

## 删除 Ollama 模型（可选）
rm -rf ~/.ollama
```

## 步骤 10. 后续步骤

现在 Live VLM WebUI 正在运行，探索这些用例：

**模型基准测试：**
- 在 DGX Spark 上测试多个模型（Gemma 3、Llama Vision、Qwen VL）
- 比较推理延迟、准确性和 GPU 利用率
- 评估结构化输出能力（JSON、CSV）

**应用原型设计：**
- 使用 Web 界面作为构建您自己的 VLM 应用程序的参考
- 与 ROS 2 集成用于机器人视觉
- 连接到 RTSP IP 摄像头用于安全监控（Beta 功能）

**云 API 集成：**
- 从本地 Ollama 切换到云 API（NVIDIA API 目录、OpenAI）
- 比较边缘与云推理性能和成本
- 测试混合部署

要使用 NVIDIA API 目录或其他云 API：

1. 在 **VLM API 配置** 部分中，更改 **API 基础 URL** 为：
   - NVIDIA API 目录：`https://integrate.api.nvidia.com/v1`
   - OpenAI：`https://api.openai.com/v1`
   - 其他：您的自定义端点

2. 在出现的字段中输入您的 **API 密钥**

3. 从下拉菜单中选择您的模型（列表从 API 获取）

**高级配置：**
- 使用 vLLM、SGLang 或 NIM 后端以获得更高吞吐量
- 设置 NIM 以获得优化的 NVIDIA 特定性能
- 为您的特定用例自定义 Python 后端

有关更多高级用法，请参阅 GitHub 上的 [完整文档](https://github.com/NVIDIA-AI-IOT/live-vlm-webui/tree/main/docs)。

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html) 和 [Live VLM WebUI 故障排除指南](https://github.com/NVIDIA-AI-IOT/live-vlm-webui/blob/main/docs/troubleshooting.md)。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| pip install 显示 "error: externally-managed-environment" | Python 3.12+ 防止系统范围的 pip 安装 | 使用虚拟环境：`python3 -m venv live-vlm-env && source live-vlm-env/bin/activate && pip install live-vlm-webui` |
| 浏览器显示 "您的连接不安全" 警告 | 应用程序使用自签名 SSL 证书 | 点击 "高级" → "继续访问 \<IP\>（不安全）" - 这是安全的，也是预期行为 |
| 相机不可访问或 "权限被拒绝" | 浏览器需要 HTTPS 才能访问相机 | 确保您使用的是 `https://`（而不是 `http://`）。接受自签名证书警告并在提示时授予相机权限 |
| "无法连接到 VLM" 或 "连接被拒绝" | Ollama 或 VLM 后端未运行 | 使用 `curl http://localhost:11434/v1/models` 验证 Ollama 是否运行。如果未运行，请使用 `sudo systemctl start ollama` 启动 |
| VLM 响应非常慢（>5 秒/帧） | 模型太大，无法获得可用的 VRAM 或配置不正确 | 尝试较小的模型（`gemma3:4b` 而不是较大的模型）。将帧处理间隔增加到 60+ 帧。将最大令牌数减少到 100-200 |
| GPU 统计数据显示所有指标为 "N/A" | NVML 不可用或 GPU 驱动程序问题 | 使用 `nvidia-smi` 验证 GPU 访问。确保正确安装了 NVIDIA 驱动程序 |
| 模型下拉菜单中 "没有可用模型" | API 端点不正确或未下载模型 | 验证 API 端点是否为 Ollama 的 `http://localhost:11434/v1`。使用 `ollama pull gemma3:4b` 下载模型 |
| 服务器启动失败，显示 "端口已被占用" | 端口 8090 已被其他服务占用 | 停止冲突的服务或使用 `--port` 标志指定不同的端口：`live-vlm-webui --port 8091` |
| 无法从网络上的远程浏览器访问 | 防火墙阻止端口 8090 或 IP 地址错误 | 验证防火墙允许端口 8090：`sudo ufw allow 8090`。使用 `hostname -I` 命令的正确 IP |
| 视频流卡顿或冻结 | 网络问题或浏览器性能 | 使用 Chrome 或 Edge 浏览器。从网络上的单独 PC 访问，而不是本地访问。检查网络带宽 |
| 分析结果以意外语言显示 | 模型支持多语言并在提示中检测到语言 | 在提示中明确指定输出语言："用英语回答：描述您所看到的内容" |
| pip install 因依赖错误而失败 | Python 包版本冲突 | 尝试使用 `--user` 标志安装：`pip install --user live-vlm-webui` |
| 安装后找不到命令 `live-vlm-webui` | 二进制路径不在 PATH 中 | 将 `~/.local/bin` 添加到 PATH：`export PATH="$HOME/.local/bin:$PATH"` 然后运行 `source ~/.bashrc` |
| 相机正常但没有 VLM 分析结果出现，浏览器显示 InvalidStateError | 通过远程机器的 SSH 端口转发访问 | WebRTC 需要直接网络连接，不通过 SSH 隧道工作（SSH 只转发 TCP，WebRTC 需要 UDP）。**解决方案 1**：从服务器网络上的浏览器直接访问 Web UI。**解决方案 2**：直接使用服务器机器的浏览器。**解决方案 3**：使用 X11 转发（`ssh -X`）远程显示浏览器 |
