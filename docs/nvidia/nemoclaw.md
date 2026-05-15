# NemoClaw with Nemotron 3 Super 和 Telegram on DGX Spark

> 在 DGX Spark 上安装 NemoClaw，使用本地 Ollama 推理和 Telegram 机器人集成

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

### 基本概念

**NVIDIA NemoClaw** 是一个开源参考栈，简化了更安全地运行 OpenClaw 常驻助手的过程。它安装了 **NVIDIA OpenShell** 运行时——一个专为执行具有额外安全性的代理而设计的环境——以及开源模型如 NVIDIA Nemotron。单个安装程序命令处理 Node.js、OpenShell 和 NemoClaw CLI，然后引导您完成一个向导，在您的 DGX Spark 上创建一个使用 Ollama 和 Nemotron 3 Super 的沙盒代理。

通过本操作指南，您将拥有一个在 OpenShell 沙盒内的工作 AI 代理，可通过 Web 仪表板和 Telegram 机器人访问，推理路由到您的 Spark 上的本地 Nemotron 3 Super 120B 模型——所有这些都不会将您的主机文件系统或网络暴露给代理。

### 您将实现的目标

- 在 DGX Spark 上为 OpenShell 配置 Docker 和 NVIDIA 容器运行时
- 安装 Ollama，下载 Nemotron 3 Super 120B，并配置它用于沙盒访问
- 使用单个命令安装 NemoClaw（处理 Node.js、OpenShell 和 CLI）
- 运行向导以创建沙盒并配置本地推理
- 通过 CLI、TUI 和 Web UI 与代理聊天
- 设置一个 Telegram 机器人，将消息转发到您的沙盒代理

### 通知和免责声明

以下部分描述了运行此演示时的安全、风险和您的责任。

#### 快速开始安全检查

**仅在干净的环境中使用。** 在没有个人数据、机密信息或敏感凭证的新设备或 VM 上运行此演示。将其隔离，就像沙盒一样。

通过安装此演示，您接受对所有第三方组件的责任，包括审查其许可证、条款和安全状况。在安装或使用前阅读并接受。

#### 您将获得的内容

此体验仅"按原样"提供用于演示目的——无保证，无担保。这是一个演示，不是生产就绪的解决方案。您需要为您的环境和用例实施适当的安全控制。

#### AI 代理的关键风险

- **数据泄露** -- 代理访问的任何材料都可能被暴露、泄露或窃取。
- **恶意代码执行** -- 代理或其连接的工具可能会将您的系统暴露于恶意代码或网络攻击。
- **意外操作** -- 代理可能会在未经明确批准的情况下修改或删除文件、发送消息或访问服务。
- **提示注入和操纵** -- 外部输入或连接的内容可能会以意外方式劫持代理的行为。

#### 参与者确认

通过参与此演示，您确认您完全负责您的配置以及您连接的任何数据、账户和工具。在法律允许的最大范围内，NVIDIA 对因您的配置或使用 NemoClaw 演示材料（包括 OpenClaw 或任何连接的工具或服务）而造成的任何数据丢失、设备损坏、安全事件或其他伤害不承担责任。

### 隔离层（OpenShell）

| 层 | 保护内容 | 何时应用 |
|------|----------------------------------------------------|-----------------------------|
| 文件系统 | 防止在允许的路径之外读/写。 | 锁定在沙盒创建时。 |
| 网络 | 阻止未经授权的出站连接。 | 运行时热重载。 |
| 进程 | 阻止权限提升和危险的系统调用。 | 锁定在沙盒创建时。 |
| 推理 | 将模型 API 调用重定向到受控后端。 | 运行时热重载。 |

### 开始前须知

- 基本使用 Linux 终端和 SSH
- 熟悉 Docker（权限、`docker run`）
- 了解上述安全和风险部分

### 先决条件

**硬件和访问：**

- 一台 DGX Spark（GB10），带键盘和显示器，或 SSH 访问
- 一个来自 [@BotFather](https://t.me/BotFather) 的 **Telegram 机器人令牌**（使用 `/newbot` 创建）——只有在您想要 Telegram 机器人时才需要。在运行安装程序之前准备好它；向导会在提示时要求它。

**软件：**

- 安装了最新更新的 DGX OS

在开始前验证您的系统：

```bash
head -n 2 /etc/os-release
nvidia-smi
docker info --format '{{.ServerVersion}}'
```

预期：Ubuntu 24.04，NVIDIA GB10 GPU，Docker 28.x+。

### 开始前准备

| 项目 | 获取位置 |
|------|----------------|
| Telegram 机器人令牌（可选） | Telegram 上的 [@BotFather](https://t.me/BotFather) — 使用 `/newbot` 创建。仅在您需要 Telegram 机器人时才需要；在运行安装程序之前准备好它。 |

### 辅助文件

所有必需的资源都由 NemoClaw 安装程序处理。不需要手动克隆。

### 时间和风险

- **预计时间：** 20--30 分钟（假设 Ollama 和模型已下载）。首次下载模型会增加约 15--30 分钟，具体取决于网络速度。
- **风险级别：** 中等 -- 您正在沙盒中运行 AI 代理；隔离减少了风险，但并未完全消除。使用干净的环境，不要连接敏感数据或生产账户。
- **最后更新：** 2026年4月28日
  * 更新到 NemoClaw v0.0.22+：修订的 Telegram 设置，重命名的隧道命令，刷新的卸载说明。

---

## 操作说明

## 阶段 1：先决条件

这些步骤为 DGX Spark 上的 NemoClaw 准备一个干净的环境。如果 Docker、NVIDIA 运行时和 Ollama 已经配置，请跳到阶段 2。

### 步骤 1. 配置 Docker 和 NVIDIA 容器运行时

OpenShell 的网关在 Docker 内运行 k3s。在 DGX Spark（Ubuntu 24.04，cgroup v2）上，Docker 必须配置为 NVIDIA 运行时和主机 cgroup 命名空间模式。

为 Docker 配置 NVIDIA 容器运行时：

```bash
sudo nvidia-ctk runtime configure --runtime=docker
```

设置 OpenShell 在 DGX Spark 上所需的 cgroup 命名空间模式：

```bash
sudo python3 -c "
import json, os
path = '/etc/docker/daemon.json'
d = json.load(open(path)) if os.path.exists(path) else {}
d['default-cgroupns-mode'] = 'host'
json.dump(d, open(path, 'w'), indent=2)
"
```

重启 Docker：

```bash
sudo systemctl restart docker
```

验证 NVIDIA 运行时是否有效：

```bash
docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

如果您在 `docker` 上得到权限被拒绝错误，将您的用户添加到 Docker 组并在当前会话中激活新组：

```bash
sudo usermod -aG docker $USER
newgrp docker
```

这会立即应用组更改。或者，您可以注销并重新登录而不是运行 `newgrp docker`。

> [!NOTE]
> DGX Spark 使用 cgroup v2。OpenShell 的网关在 Docker 内嵌入 k3s 并需要主机 cgroup 命名空间访问。没有 `default-cgroupns-mode: host`，网关可能会因 "Failed to start ContainerManager" 错误而失败。

### 步骤 2. 安装 Ollama

安装 Ollama：

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

配置 Ollama 以监听所有接口，以便沙盒容器可以到达它：

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
printf '[Service]\nEnvironment="OLLAMA_HOST=0.0.0.0"\n' | sudo tee /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

验证它正在运行并且可以被所有接口访问：

```bash
curl http://0.0.0.0:11434
```

预期：`Ollama is running`。如果未运行，请使用 `sudo systemctl start ollama` 启动它。

> [!IMPORTANT]
> 始终通过 systemd 启动 Ollama（`sudo systemctl restart ollama`）——不要使用 `ollama serve &`。手动启动的 Ollama 进程不会拾取上面的 `OLLAMA_HOST=0.0.0.0` 设置，NemoClaw 沙盒将无法到达推理服务器。

### 步骤 3. 下载 Nemotron 3 Super 模型

下载 Nemotron 3 Super 120B（~87 GB；可能需要 15--30 分钟，具体取决于网络速度）：

```bash
ollama pull nemotron-3-super:120b
```

短暂运行它以将权重预加载到内存中（输入 `/bye` 退出）：

```bash
ollama run nemotron-3-super:120b
```

验证模型可用：

```bash
ollama list
```

您应该在输出中看到 `nemotron-3-super:120b`。

---

## 阶段 2：安装和运行 NemoClaw

### 步骤 4. 安装 NemoClaw

此单个命令处理所有内容：安装 Node.js（如果需要），安装 OpenShell，克隆最新的稳定 NemoClaw 版本，构建 CLI，并运行向导以创建沙盒。

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

向导引导您完成设置：

1. **沙盒名称** -- 选择一个名称（例如 `my-assistant`）。名称必须是小写字母数字，仅允许使用连字符。
2. **推理提供者** -- 选择 **Local Ollama**。
3. **模型** -- 选择 **nemotron-3-super:120b**。
4. **消息传递渠道** -- 如果您想要 Telegram 机器人，请在此处选择 `telegram` 并在提示时粘贴您的机器人令牌。首先通过 Telegram 中的 [@BotFather](https://t.me/BotFather) 创建机器人（参见步骤 9）。如果跳过此步骤，您可以稍后重新运行安装程序以使用 Telegram 重新创建沙盒。
5. **策略预设** -- 在提示时接受建议的预设（按 **Y**）。

> [!IMPORTANT]
> 必须在此步骤配置 Telegram。通道插件和机器人令牌在沙盒创建期间嵌入沙盒容器中——它们不能通过在主机上导出环境变量添加到现有沙盒。

完成时，您将看到如下输出：

```text
──────────────────────────────────────────────────
Dashboard    http://localhost:18789/
Sandbox      my-assistant (Landlock + seccomp + netns)
Model        nemotron-3-super:120b (Local Ollama)
──────────────────────────────────────────────────
Run:         nemoclaw my-assistant connect
Status:      nemoclaw my-assistant status
Logs:        nemoclaw my-assistant logs --follow
──────────────────────────────────────────────────
```

> [!IMPORTANT]
> 保存在末尾打印的令牌化 Web UI URL — 您将在步骤 8 中需要它。它看起来像：
> `http://127.0.0.1:18789/#token=<long-token-here>`

> [!NOTE]
> 如果安装后找不到 `nemoclaw`，运行 `source ~/.bashrc` 以重新加载您的 shell 路径。

### 步骤 5. 连接到沙盒并验证推理

连接到沙盒：

```bash
nemoclaw my-assistant connect
```

您将看到 `sandbox@my-assistant:~$` -- 您现在在沙盒化的环境中。

验证推理路由是否有效：

```bash
curl -sf https://inference.local/v1/models
```

预期：JSON 列出 `nemotron-3-super:120b`。

### 步骤 6. 与代理聊天（CLI）

仍在沙盒内，发送测试消息：

```bash
openclaw agent --agent main -m "hello" --session-id test
```

代理将使用 Nemotron 3 Super 回复。由于本地运行的 120B 参数模型，首次回复可能需要 30--90 秒。

### 步骤 7. 交互式 TUI

启动终端 UI 进行交互式聊天会话：

```bash
openclaw tui
```

按 **Ctrl+C** 退出 TUI。

### 步骤 8. 退出沙盒并访问 Web UI

退出沙盒以返回主机：

```bash
exit
```

**如果您直接在 Spark 上访问 Web UI**（连接了键盘和显示器），打开浏览器并导航到步骤 4 中的令牌化 URL：

```text
http://127.0.0.1:18789/#token=<long-token-here>
```

**如果您从远程机器访问 Web UI**，您需要设置 SSH 隧道。NemoClaw 向导已经在 Spark 上创建了端口 18789 转发，因此您只需要从远程机器进行隧道。

首先，找到您的 Spark 的 IP 地址。在 Spark 上，运行：

```bash
hostname -I | awk '{print $1}'
```

这将打印主要 IP 地址（例如 `192.168.1.42`）。您还可以在 Spark 桌面上的 **设置 > Wi-Fi** 或 **设置 > 网络** 中找到它，或检查路由器的连接设备列表。

从您的远程机器，创建到 Spark 的 SSH 隧道（将 `<your-spark-ip>` 替换为上面的 IP 地址）：

```bash
ssh -L 18789:127.0.0.1:18789 <your-user>@<your-spark-ip>
```

现在在您的远程机器浏览器中打开令牌化 URL：

```text
http://127.0.0.1:18789/#token=<long-token-here>
```

> [!IMPORTANT]
> 使用 `127.0.0.1`，而不是 `localhost` -- 网关来源检查需要完全匹配。

> [!NOTE]
> 如果 Web UI 无法加载且端口转发可能已过期，请在 Spark 主机上重置它：
> ```bash
> openshell forward stop 18789 my-assistant || true
> openshell forward start 18789 my-assistant --background
> ```

---

## 阶段 3：Telegram 机器人

> [!IMPORTANT]
> Telegram 必须在 **NemoClaw 向导**（步骤 4 → 消息传递渠道）中启用。通道插件和机器人令牌在沙盒创建时嵌入沙盒容器中 — `policy-add` 仅打开网络出口，单独使用是不够的。如果您在向导期间跳过了 Telegram，请重新运行安装程序以使用 Telegram 重新创建沙盒。

### 步骤 9. 创建 Telegram 机器人

在步骤 4 运行 NemoClaw 安装程序之前，请先执行此操作，以便向导提示时您有机器人令牌准备就绪。

在 Telegram 中，找到 [@BotFather](https://t.me/BotFather)，发送 `/newbot`，并按照提示操作。复制它给您的机器人令牌并在到达 **消息传递渠道** 步骤时粘贴到向导中。

### 步骤 10. 安装 cloudflared 并启动 Telegram 桥

Telegram 桥需要一个公共 webhook URL，以便 Telegram 可以将消息传递到您的机器人。NemoClaw 使用 [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) 创建一个免费的 `trycloudflare.com` 隧道。

确保您在 **主机** 上（而不是在沙盒内）。如果您在沙盒内，请先运行 `exit`。

安装 cloudflared（DGX Spark 是 arm64）：

```bash
curl -L --output cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
sudo dpkg -i cloudflared.deb
```

启动隧道：

```bash
nemoclaw tunnel start
```

验证公共 URL 是否在线：

```bash
nemoclaw status
```

您应该看到 `● cloudflared`，其中包含 `trycloudflare.com` 公共 URL（例如 `https://assembled-peer-persian-kitty.trycloudflare.com`）。

在 Telegram 中，找到您的机器人并发送消息。机器人将其转发给代理并回复。

> [!NOTE]
> 如果 `nemoclaw tunnel start` 打印 `cloudflared not found — no public URL`，上面的 cloudflared 安装未成功完成。重新运行安装，然后重新启动隧道：
> ```bash
> nemoclaw tunnel stop && nemoclaw tunnel start
> ```

> [!NOTE]
> 由于本地运行的 120B 参数模型，首次回复可能需要 30--90 秒。

> [!NOTE]
> 如果发送消息返回 `Error: Channel is unavailable: telegram`，向导期间未启用通道。重新运行安装程序以使用 Telegram 重新创建沙盒。

> [!NOTE]
> 有关限制哪些 Telegram 聊天可以与代理交互的详细信息，请参阅 [NemoClaw Telegram 桥文档](https://docs.nvidia.com/nemoclaw/latest/deployment/set-up-telegram-bridge.html)。

---

## 阶段 4：清理和卸载

### 步骤 11. 停止服务

停止 cloudflared 隧道：

```bash
nemoclaw tunnel stop
```

停止端口转发：

```bash
openshell forward list          # 找到活动转发
openshell forward stop 18789    # 停止仪表板转发
```

### 步骤 12. 卸载 NemoClaw

通过 curl 运行卸载程序（与 [NemoClaw README](https://github.com/NVIDIA/NemoClaw) 匹配）。它删除所有沙盒、OpenShell 网关、Docker 容器/镜像/卷、CLI 和所有状态文件。Docker、Node.js、npm 和 Ollama 被保留。

```bash
curl -fsSL https://raw.githubusercontent.com/NVIDIA/NemoClaw/refs/heads/main/uninstall.sh | bash
```

**卸载程序标志**（通过 `bash -s -- <flags>` 传递）：

| 标志 | 效果 |
|------|--------|
| `--yes` | 跳过确认提示 |
| `--keep-openshell` | 保留 `openshell` 二进制文件 |
| `--delete-models` | 还删除 NemoClaw 下载的 Ollama 模型 |

要删除一切，包括 Ollama 模型，以非交互方式：

```bash
curl -fsSL https://raw.githubusercontent.com/NVIDIA/NemoClaw/refs/heads/main/uninstall.sh | bash -s -- --yes --delete-models
```

卸载程序运行 6 个步骤：
1. 停止 NemoClaw 辅助服务和端口转发进程
2. 删除所有 OpenShell 沙盒、NemoClaw 网关和提供者
3. 删除全局 `nemoclaw` npm 包
4. 删除 NemoClaw/OpenShell Docker 容器、镜像和卷
5. 删除 Ollama 模型（仅使用 `--delete-models`）
6. 删除状态目录（`~/.nemoclaw`，`~/.config/openshell`，`~/.config/nemoclaw`）和 OpenShell 二进制文件

> [!NOTE]
> 如果您有一个本地克隆在 `~/.nemoclaw/source` 中您想要保留，请在运行卸载程序之前移动或备份它——它是步骤 6 的状态清理的一部分被删除。

## 有用命令

| 命令 | 描述 |
|------|------|
| `nemoclaw my-assistant connect` | 进入沙盒的 Shell |
| `nemoclaw my-assistant status` | 显示沙盒状态和推理配置 |
| `nemoclaw my-assistant logs --follow` | 实时流式传输沙盒日志 |
| `nemoclaw list` | 列出所有注册的沙盒 |
| `nemoclaw tunnel start` | 启动 cloudflared 隧道（Telegram webhooks 的公共 URL） |
| `nemoclaw tunnel stop` | 停止 cloudflared 隧道 |
| `openshell term` | 在主机上打开监控 TUI |
| `openshell forward list` | 列出活动端口转发 |
| `openshell forward start 18789 my-assistant --background` | 为 Web UI 重新启动端口转发 |
| `curl -fsSL https://raw.githubusercontent.com/NVIDIA/NemoClaw/refs/heads/main/uninstall.sh \| bash` | 删除 NemoClaw（保留 Docker、Node.js、Ollama） |
| `curl -fsSL https://raw.githubusercontent.com/NVIDIA/NemoClaw/refs/heads/main/uninstall.sh \| bash -s -- --delete-models` | 删除 NemoClaw 和 Ollama 模型 |

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 安装后找不到 `nemoclaw` | Shell PATH 未更新 | 运行 `source ~/.bashrc`（或 `source ~/.zshrc` 表示 zsh），或打开新终端窗口。 |
| 安装程序因 Node.js 版本错误失败 | Node.js 版本低于 20 | 安装 Node.js 20+：`curl -fsSL https://deb.nodesource.com/setup_22.x \| sudo -E bash - && sudo apt-get install -y nodejs` 然后重新运行安装程序。 |
| npm install 因 `EACCES` 权限错误失败 | npm 全局目录不可写 | `mkdir -p ~/.npm-global && npm config set prefix ~/.npm-global && export PATH=~/.npm-global/bin:$PATH` 然后重新运行安装程序。将 `export` 行添加到 `~/.bashrc` 使其永久。 |
| Docker 权限被拒绝 | 用户不在 docker 组中 | `sudo usermod -aG docker $USER`，然后注销并重新登录。 |
| 网关失败，出现 cgroup / "Failed to start ContainerManager" 错误 | DGX Spark 上的 Docker 未配置为主机 cgroup 命名空间 | 运行 cgroup 修复：`sudo python3 -c "import json, os; path='/etc/docker/daemon.json'; d=json.load(open(path)) if os.path.exists(path) else {}; d['default-cgroupns-mode']='host'; json.dump(d, open(path,'w'), indent=2)"` 然后 `sudo systemctl restart docker`。或者，运行 `sudo nemoclaw setup-spark` 自动应用此修复。 |
| 网关失败，出现 "port 8080 is held by container..." 错误 | 另一个 OpenShell 网关或容器正在使用端口 8080 | 停止冲突的容器：`openshell gateway destroy -g <old-gateway-name>` 或 `docker stop <container-name> && docker rm <container-name>`，然后重试 `nemoclaw onboard`。 |
| 沙盒创建失败 | 过时的网关状态或 DNS 未传播 | 运行 `openshell gateway destroy && openshell gateway start`，然后重新运行安装程序或 `nemoclaw onboard`。 |
| CoreDNS 崩溃循环 | 某些 DGX Spark 配置的已知问题 | 从 NemoClaw 存储库目录运行 `sudo ./scripts/fix-coredns.sh`。 |
| 向导期间 "No GPU detected" | DGX Spark GB10 以不同方式报告统一内存 | DGX Spark 上的预期。向导仍然有效并使用 Ollama 进行推理。 |
| 推理超时或挂起 | Ollama 未运行或无法到达 | 检查 Ollama：`curl http://localhost:11434`。如果未运行：`ollama serve &`。如果运行但无法从沙盒到达，请确保 Ollama 配置为监听 `0.0.0.0`（参见操作说明中的步骤 2）。 |
| 代理不回复或非常慢 | 本地运行的 120B 模型正常 | Nemotron 3 Super 120B 每个回复可能需要 30--90 秒。验证推理路由：`nemoclaw my-assistant status`。 |
| 端口 18789 已被使用 | 另一个进程绑定到端口 | `lsof -i :18789` 然后 `kill <PID>`。如果需要，`kill -9 <PID>` 强制终止。 |
| Web UI 端口转发死或仪表板无法访问 | 端口转发未激活 | `openshell forward stop 18789 my-assistant` 然后 `openshell forward start 18789 my-assistant --background`。 |
| Web UI 显示 `origin not allowed` | 通过 `localhost` 而不是 `127.0.0.1` 访问 | 在浏览器中使用 `http://127.0.0.1:18789/#token=...`。网关来源检查需要 `127.0.0.1`。 |
| Telegram 桥未启动 | 缺少环境变量 | 确保在主机上设置了 `TELEGRAM_BOT_TOKEN` 和 `SANDBOX_NAME`。`SANDBOX_NAME` 必须与向导期间的沙盒名称匹配。 |
| Telegram 桥需要重启但 `nemoclaw stop` 不工作 | `nemoclaw stop` 中的已知错误 | 从 `nemoclaw start` 输出中找到 PID，使用 `kill -9 <PID>` 强制终止，然后再次运行 `nemoclaw start`。 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
