# VS Code 中的 Vibe Coding

> 使用 DGX Spark 作为本地或远程 Vibe Coding 助手，配合 Ollama 和 Continue

## 目录

- [概述](#概述)
  - [你将实现的目标](#你将实现的目标)
  - [先决条件](#先决条件)
  - [时间与风险](#时间与风险)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

本 playbook 引导你设置 DGX Spark 作为 **Vibe Coding 助手**——本地或作为 VSCode 与 Continue.dev 的远程编码伴侣。
本指南使用 **Ollama** 和 **GPT-OSS 120B** 提供轻松部署到 VSCode 的编码助手。包含高级说明，允许 DGX Spark 和 Ollama 使编码助手可通过你的本地网络访问。本指南也是在操作系统**全新安装**上编写的。如果你的操作系统不是全新安装并且遇到问题，请参阅故障排除选项卡。

### 你将实现的目标

你将拥有一个完全配置的 DGX Spark 系统，能够：
- 通过 Ollama 运行本地代码辅助。
- 为 Continue 和 VSCode 集成远程提供模型。
- 使用统一内存托管像 GPT-OSS 120B 这样的大型 LLM。

### 先决条件

- DGX Spark（建议 128GB 统一内存）
- **Ollama** 和你选择的 LLM（例如 `gpt-oss:120b`）
- **VSCode**
- **Continue** VSCode 扩展
- 用于模型下载的互联网访问
- 基本熟悉打开 Linux 终端、复制和粘贴命令。
- 具有 sudo 访问权限。
- 可选：用于远程访问配置的防火墙控制

### 时间与风险

* **持续时间：** 大约 30 分钟
* **风险：** 由于网络问题导致的数据下载缓慢或失败
* **回滚：** 正常使用期间不进行永久系统更改。
* **最后更新：** 2025年10月21日
  * 首次发布

---

## 操作说明

## 步骤 1. 安装 Ollama

使用以下命令安装最新版本的 Ollama：

```bash
curl -fsSL https://ollama.com/install.sh | sh
```
服务运行后，拉取所需的模型：

```bash
ollama pull gpt-oss:120b
```

## 步骤 2. （可选）启用远程访问

要允许远程连接（例如，从使用 VSCode 和 Continue 的工作站），请修改 Ollama systemd 服务：

```bash
sudo systemctl edit ollama
```

在注释部分下方添加以下行：

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
```

重新加载并重启服务：

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

如果使用防火墙，请打开端口 11434：

```bash
sudo ufw allow 11434/tcp
```

验证工作站可以连接到你的 DGX Spark 的 Ollama 服务器：

  ```bash
  curl -v http://YOUR_SPARK_IP:11434/api/version
  ```
 将 **YOUR_SPARK_IP** 替换为你的 DGX Spark 的 IP 地址。
 如果连接失败，请参阅故障排除选项卡。

## 步骤 3. 安装 VSCode

对于 DGX Spark（基于 ARM），下载并安装 VSCode：
  转到 https://code.visualstudio.com/download 并下载 VSCode 的 Linux ARM64 版本。下载完成后，请注意下载的包名称。在下一个命令中用它替换 DOWNLOADED_PACKAGE_NAME。
```bash
sudo dpkg -i DOWNLOADED_PACKAGE_NAME
```

如果使用远程工作站，**安装适合你的系统架构的 VSCode**。

## 步骤 4. 安装 Continue.dev 扩展

打开 VSCode 并从 Marketplace 安装 **Continue.dev**：
- 转到 VSCode 中的 **Extensions view**（扩展视图）
- 搜索由 [Continue.dev](https://www.continue.dev/) 发布的 **Continue** 并安装扩展。
安装后，点击右侧栏中的 Continue 图标。

## 步骤 5. 本地推理设置
- 点击 `Or, configure your own models`（或，配置你自己的模型）
- 点击 `Click here to view more providers`（点击此处查看更多信息提供者）
- 选择 `Ollama` 作为 Provider（提供者）
- 对于 Model（模型），选择 `Autodetect`（自动检测）
- 通过发送测试提示来测试推理。

你下载的模型现在将默认用于推理（例如 `gpt-oss:120b`）。

## 步骤 6. 设置工作站以连接到 DGX Spark 的 Ollama 服务器

要在工作站上运行 VSCode 并连接到远程 DGX Spark 实例，必须在该工作站上完成以下操作：
  - 如步骤 4 中所述安装 Continue
  - 点击左侧窗格中的 `Continue` 图标
  - 点击 `Or, configure your own models`（或，配置你自己的模型）
  - 点击 `Click here to view more providers`（点击此处查看更多信息提供者）
  - 选择 `Ollama` 作为 Provider（提供者）
  - 选择 `Autodetect` 作为 Model（模型）。

Continue **将**无法检测到模型，因为它试图连接到本地托管的 Ollama 服务器。
  - 找到 Continue 窗口右上角的 `gear` 图标并点击它。
  - 在左侧窗格中，点击 **Models**（模型）
  - 在 **Chat** 下的第一个下拉菜单旁边点击齿轮图标。
  - Continue 的 `config.yaml` 将打开。记录你的 DGX Spark 的 IP 地址。
  - 将配置替换为以下内容。**YOUR_SPARK_IP** 应替换为你的 DGX Spark 的 IP。

```yaml
name: Config
version: 1.0.0
schema: v1

assistants:
  - name: default
    model: OllamaSpark

models:
  - name: OllamaSpark
    provider: ollama
    model: gpt-oss:120b
    apiBase: http://YOUR_SPARK_IP:11434
    title: gpt-oss:120b
    roles:
      - chat
      - edit
      - autocomplete
```

将 `YOUR_SPARK_IP` 替换为你的 DGX Spark 的 IP 地址。
为任何其他你希望远程托管的 Ollama 模型添加额外的模型条目。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| Ollama 未启动 | GPU 驱动程序可能未正确安装 | 在终端中运行 `nvidia-smi`。如果命令失败，请检查 DGX Dashboard 是否有 DGX Spark 的更新。|
| Continue 无法通过网络连接 | 端口 11434 可能未打开或无法访问 | 运行命令 `ss -tuln \| grep 11434`。如果输出未反映 ` tcp   LISTEN 0      4096               *:11434            *:*  `，请回到步骤 2 并运行 ufw 命令。|
| Continue 无法检测本地运行的 Ollama 模型 | 配置未正确设置或检测 | 检查 `/etc/systemd/system/ollama.service.d/override.conf` 文件中的 `OLLAMA_HOST` 和 `OLLAMA_ORIGINS`。如果 `OLLAMA_HOST` 和 `OLLAMA_ORIGINS` 设置正确，请将这些行添加到你的 `~/.bashrc` 文件中。|
| 高内存使用 | 模型太大 | 使用 `nvidia-smi` 确认没有其他大型模型或容器在运行。使用较小的模型，如 `gpt-oss:20b` 进行轻量级使用。|

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的动态共享。
> 随着许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，你也可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
