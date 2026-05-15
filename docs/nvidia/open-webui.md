# Open WebUI 使用 Ollama 在 DGX Spark 上

> 在 NVIDIA DGX Spark 上使用 Ollama 运行 Open WebUI

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

**Open WebUI** 是一个现代化的、自托管的 Web 界面，用于与本地 LLM 交互。它提供了一个用户友好的界面，用于聊天、模型管理、文档上传和提示工程。

在你的 DGX Spark 上运行 Open WebUI 和 Ollama 允许你使用 128GB 统一内存的强大功能来运行大型本地模型，同时享受直观的 Web 界面。这使你能够：

- 与本地 LLM 进行对话式聊天
- 管理多个模型
- 上传和聊天你的文档
- 使用提示模板
- 创建和分享聊天会话

## 你将实现的目标

你将安装 Ollama（如果尚未安装）、配置它以使用你的 DGX Spark 的 GPU，并设置 Open WebUI 作为 Web 界面。然后你可以通过浏览器访问 Open WebUI 并开始与你的本地模型聊天。

## 流行用例

- **开发人员测试**：在部署到生产之前测试不同的 LLM 和提示
- **个人 AI 助手**：创建一个完全私有的 AI 助手，所有数据都保存在你的机器上
- **文档聊天**：上传你的文档并使用 RAG 与它们进行对话
- **模型比较**：轻松测试不同的模型以找到最适合你的用例的模型

## 开始前须知

- 基本的 Linux 终端和文本编辑器知识
- 熟悉 Ollama（如果你计划使用本地模型）
- 了解以下安全注意事项

## 重要：安全和风险

AI 代理可能引入实际风险。阅读 OpenWebUI 的指南以了解潜在风险。

主要风险：

1. **数据暴露**：个人信息或文件可能被泄露或窃取。
2. **恶意代码**：模型输出可能包含恶意代码或不安全的内容。

你无法消除所有风险；后果自负。**关键安全措施：**

- **强烈推荐**：在专用或隔离系统（例如，干净的 DGX Spark 或 VM）上运行 Open WebUI，并且仅复制代理需要的数据。不要在你的主要工作站上运行此，特别是当你有敏感数据时。
- 使用**专用账户**给代理而不是你的主要账户；仅授予代理所需的最小访问权限。
- 仅启用你**信任的技能**，最好是社区验证的技能。
- **关键**：确保 Open WebUI **绝不**在没有强身份验证的情况下暴露于公共互联网。使用 SSH 隧道或 VPN 如果远程访问。

## 先决条件

- 运行 Linux 的 DGX Spark，连接到你的网络
- 终端（SSH 或本地）访问 Spark
- 对于本地 LLM：足够的 GPU 内存用于你的选择模型（DGX Spark 的 128GB 支持大型模型）

## 时间与风险

- **持续时间**：大约 15 分钟用于安装和设置
- **风险等级**：**中到高**-模型可以访问你配置的文件、工具和渠道。如果你启用终端/命令执行技能或连接外部账户，风险显著增加。没有适当的隔离，此设置可能会暴露敏感数据或允许代码执行。**始终遵循上述安全措施。**
- **回滚方案**：你可以停止 Ollama 和 Open WebUI 服务，并通过 Docker 或手动删除删除容器。如果需要，可以分别卸载 Ollama 或 Open WebUI。
- **最后更新**：2026年3月11日

---

## 操作说明

## 步骤 1. 在你的 DGX Spark 上安装 Ollama

在你的 DGX Spark 上，打开终端并运行官方安装脚本。

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

下载依赖项后，Ollama 将显示**安全警告**。阅读风险；如果你接受它们，使用箭头键选择**是**并按回车。

## 步骤 2. 配置 Ollama 以使用 GPU

DGX Spark 的 128GB 统一内存支持大型模型。配置 Ollama 使用 GPU：

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
printf '[Service]\nEnvironment="OLLAMA_GPU_OVERHEAD=0.1"\n' | sudo tee /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## 步骤 3. 选择并下载模型

模型质量和能力随着大小而扩展。DGX Spark 有 **128GB 统一内存**，所以你可以运行大型模型。

**建议的模型：**

| GPU 内存 | 建议模型 | 模型大小 | 注意 |
|---------|---------|---------|------|
| 8-12 GB | qwen3-4B-Thinking-2507 | ~5GB | — |
| 16 GB | gpt-oss-20b | ~12GB | 更低延迟，适合交互式使用 |
| 24-48 GB | Nemotron-3-Nano-30B-A3B | ~20GB | — |
| 128 GB | gpt-oss-120b | ~65GB | **DGX Spark 上的最佳质量** |

下载模型：

```bash
ollama pull gpt-oss-120b
```

## 步骤 4. 安装 Open WebUI

使用 Docker 安装 Open WebUI：

```bash
docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v openwebui:/app/backend/data --name openwebui --restart always ghcr.io/open-webui/open-webui:main
```

## 步骤 5. 访问 Open WebUI

在浏览器中打开 http://localhost:3000

## 步骤 6. 配置模型连接

在 Open WebUI 中：
1. 进入设置
2. 选择 "Model Providers"
3. 选择 "Ollama"
4. 添加你的 Ollama 实例（http://host.docker.internal:11434）

## 步骤 7. 开始使用

现在你可以：
- 与模型聊天
- 上传文档
- 创建聊天会话
- 管理模型

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| Open WebUI 无法加载 | Docker 容器未运行 | 检查 `docker ps` 并启动容器 |
| 模型无法下载 | 网络问题或 Hugging Face 不可达 | 检查网络连接和重试 |
| GPU 未检测到 | CUDA 驱动程序问题 | 验证 `nvidia-smi` 和驱动程序安装 |
| 连接被拒绝 | Ollama 未运行 | 启动 Ollama 服务 |

有关最新的平台问题，请参阅 [DGX Spark 已知问题](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html) 文档。
