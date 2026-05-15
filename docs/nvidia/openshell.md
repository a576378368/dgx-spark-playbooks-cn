# 在 DGX Spark 上使用 OpenShell 运行安全的长期 AI 代理

> 在 NVIDIA OpenShell 沙箱中运行 OpenClaw，使用本地模型

## 目录

- [概述](#概述)
  - [通知和免责声明](#通知和免责声明)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

OpenClaw 是一个本地优先的 AI 代理，运行在你的机器上，将内存、文件访问、工具使用和社区技能组合成一个持久的助手。直接在系统上运行它意味着代理可以访问你的文件、凭证和网络——这会带来真实的安全风险。

**NVIDIA OpenShell** 解决了这个问题。它是一个开源的沙箱运行时，用内核级隔离和声明式 YAML 策略包装代理。OpenShell 控制代理在磁盘上可以读取什么、可以连接哪些网络端点，以及拥有哪些权限——同时保留使其有用的代理功能。

通过在 DGX Spark 上将 OpenClaw 与 OpenShell 结合，你将获得本地 AI 代理的全部功能，同时获得 128GB 统一内存支持大型模型，并强制执行对文件系统访问、网络外发和凭证处理的显式控制。

### 通知和免责声明

#### 快速入门安全检查

仅使用干净的环境。在没有个人数据、机密信息或敏感凭证的新设备或 VM 上运行此 playbook。把它想象成一个沙箱——保持隔离。

通过安装此 playbook，你将承担所有第三方组件的责任，包括审查其许可证、条款和安全状况。安装或使用前请阅读并接受。

---

#### 你将获得什么

此 playbook 展示了实验性 AI 代理功能。即使在你的工具包中有像 OpenShell 这样的尖端开源工具，你也需要为你的特定威胁模型分层适当的安全措施。

---

#### AI 代理的关键风险

注意 AI 代理的这些风险：

1. 数据泄露 - 代理访问的任何材料都可能被泄露、泄露或被盗。

2. 恶意代码执行 - 代理或其连接的工具可能使你的系统面临恶意软件或网络攻击。

3. 意外操作 - 代理可能会修改或删除文件、发送消息或在没有明确批准的情况下访问服务。

4. 提示注入和操作 - 外部输入或连接的内容可能以意外方式劫持代理的行为。

---

#### 安全最佳实践

没有系统是完美的，但这些实践有助于保护你的信息和系统安全。

1. 隔离环境 - 在干净的 PC 或隔离的虚拟机上运行。仅提供代理需要访问的特定数据。

2. 永远不要使用真实账户 - 不要连接个人、机密或生产账户。创建具有最小权限的专用测试账户。

3. 审查你的技能/插件 - 仅启用受信任来源的技能，最好是经过社区审查的技能。

4. 限制访问 - 确保你的 OpenClaw UI 或消息渠道在网络中不可访问，除非有适当的认证。

5. 限制网络访问 - 在可行的情况下，限制代理的互联网连接。

6. 及时清理 - 完成后，删除 OpenClaw 并撤销你授予的所有凭证、API 密钥和账户访问权限。

---

## 你将实现的目标

你将安装 OpenShell CLI (`openshell`)，在你的 DGX Spark 上部署网关，并使用预构建的 OpenClaw 社区沙箱在沙箱环境中启动 OpenClaw。沙箱默认强制执行文件系统、网络和进程隔离。你还将配置本地推理路由，以便 OpenClaw 使用你的 Spark 上运行的模型，而不需要外部 API 密钥。

## 流行用例

- **安全的代理实验**：测试 OpenClaw 技能和集成，而无需将你的主文件系统或凭证暴露给代理。

- **私有企业开发**：将所有推理路由到 DGX Spark 上的本地模型。除非你在策略中明确允许，否则数据不会离开机器。

- **可审计的代理访问**：将策略 YAML 与你的项目一起版本控制。在授予访问权限之前，准确审查代理可以访问的内容。

- **迭代策略调整**：使用 `openshell term` 实时监控被拒绝的连接，然后热重载更新的策略，而无需重新创建沙箱。

## 开始前须知

- 熟悉 Linux 终端和 SSH
- 基本了解 Docker（OpenShell 在 Docker 中运行 k3s 集群）
- 熟悉 Ollama 进行本地模型服务
- 了解安全模型：OpenShell 通过隔离降低风险，但无法消除所有风险。查看 [OpenShell 文档](https://pypi.org/project/openshell/) 和 [OpenClaw 安全指南](https://docs.openclaw.ai/gateway/security)。

## 先决条件

**硬件要求：**
- NVIDIA DGX Spark，128GB 统一内存
- 至少 70GB 可用内存用于大型本地模型（例如 gpt-oss:120b 约 65GB 加上开销），或 25GB+ 用于较小模型（例如 gpt-oss-20b）

**软件要求：**
- NVIDIA DGX OS（基于 Ubuntu 24.04）
- 正在运行的 Docker Desktop 或 Docker Engine：`docker info`
- Python 3.12 或更高版本：`python3 --version`
- `uv` 包管理器：`uv --version`（使用 `curl -LsSf https://astral.sh/uv/install.sh | sh` 安装）
- Ollama 0.17.0 或更高版本（推荐最新版本以获得 gpt-oss MXFP4 支持）：`ollama --version`
- 从 PyPI 下载 Python 包和从 Ollama 下载模型权重的网络访问权限
- 已安装并配置 [NVIDIA Sync](https://build.nvidia.com/spark/connect-to-your-spark) 用于你的 DGX Spark

## 时间与风险

* **估计时间：** 20-30 分钟（加上模型下载时间，取决于模型大小和网络速度）。

> [!CAUTION] **风险级别：** 中等
  * OpenShell 沙箱强制执行内核级隔离，与直接在主机上运行 OpenClaw 相比，显著降低了风险。
  * 沙箱默认策略拒绝所有未明确允许的出站流量。配置不当的策略可能阻止合法的代理流量；使用 `openshell logs` 进行诊断。
  * 不稳定的网络可能导致大型模型下载失败。
* **回滚：** 使用 `openshell sandbox delete <sandbox-name>` 删除沙箱，使用 `openshell gateway stop` 停止网关，必要时使用 `openshell gateway destroy` 销毁它。可以使用 `ollama rm <model>` 删除 Ollama 模型。
* **最后更新：** 2026年3月13日

---

## 操作说明

## 步骤 1. 确认你的环境

在安装任何内容之前，验证操作系统、GPU、Docker 和 Python 是否可用。

```bash
head -n 2 /etc/os-release
nvidia-smi
docker info --format '{{.ServerVersion}}'
python3 --version
```

确保 [NVIDIA Sync](https://build.nvidia.com/spark/connect-to-your-spark/sync) 使用自定义端口进行配置：将 "OpenClaw" 作为名称，将 "18789" 作为端口。

预期输出应显示 Ubuntu 24.04（DGX OS）、检测到的 GPU、Docker 服务器版本和 Python 3.12+。

## 步骤 2. Docker 配置

首先，使用以下命令验证本地用户是否具有 Docker 权限。
```bash
docker ps
```

如果你得到权限被拒绝错误（`permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`），将你的用户添加到系统的 Docker 组中。这将使你能够运行 Docker 命令而无需 `sudo`。执行此操作的命令如下：

```bash
sudo usermod -aG docker $USER
newgrp docker
```

注意，你应该在将用户添加到组后重新启动 Spark，以便此更改对所有终端会话持久生效。

现在我们已经验证了用户的 Docker 权限，我们必须配置 Docker，使其可以使用 NVIDIA 容器运行时。
```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

运行示例工作负载以验证设置：

```bash
docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

## 步骤 3. 安装 OpenShell CLI

创建虚拟环境并安装 `openshell` CLI。

```bash
cd ~
uv venv openshell-env && source openshell-env/bin/activate
uv pip install openshell 
openshell --help
```

如果你还没有安装 `uv`：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
```

预期输出应显示带有子命令如 `gateway`、`sandbox`、`provider` 和 `inference` 的 `openshell` 命令树。

## 步骤 4. 在 DGX Spark 上部署 OpenShell 网关

网关是管理沙箱的控制平面。由于你直接在 Spark 上运行，它会在 Docker 内部本地部署。

```bash
openshell gateway start
openshell status
```

`openshell status` 应该报告网关为 **Connected**（已连接）。第一次运行可能需要几分钟，因为 Docker 拉取所需的镜像，内部 k3s 集群进行引导。

> [!NOTE]
> 远程网关部署需要无密码 SSH 访问。确保在使用 `--remote` 标志之前，你的 SSH 公钥已添加到 `~/.ssh/authorized_keys` on the DGX Spark.

> [!TIP]
> 如果你想从单独的工作站管理 Spark 网关，请从该工作站运行 `openshell gateway start --remote <username>@<spark-ssid>.local`。所有后续命令将通过 SSH 隧道路由。

## 步骤 5. 安装 Ollama 并拉取模型

安装 Ollama（如果尚未安装）并下载模型以进行本地推理。

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama --version
```

DGX Spark 的 128GB 内存可以运行大型模型：

| 可用 GPU 内存 | 推荐模型 | 模型大小 | 注意 |
|--------------|---------|---------|------|
| 25-48 GB | nemotron-3-nano | ~24GB | 较低延迟，适合交互式使用 |
| 48-80 GB | gpt-oss:120b | ~65GB | 质量和速度的良好平衡 |
| 128 GB | nemotron-3-super:120b | ~86GB | DGX Spark 上的最佳质量 |

验证 Ollama 正在运行（安装后自动作为服务启动）。如果未启动，请手动启动：

```bash
ollama serve &
```

配置 Ollama 监听所有接口，以便 OpenShell 网关容器可以访问它：

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
printf '[Service]\nEnvironment="OLLAMA_HOST=0.0.0.0"\n' | sudo tee /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

验证 Ollama 正在运行并可以在所有接口上访问：

```bash
curl http://0.0.0.0:11434
```

预期：`Ollama is running`。如果没有，请使用 `sudo systemctl start ollama` 启动它。

接下来，从 Ollama 运行一个模型（调整模型名称以匹配你在步骤 5 中的选择）。`ollama run` 命令将在模型不存在时自动拉取模型。在此处运行模型可确保它在你使用 OpenClaw 时已加载并准备就绪，减少以后超时的可能性。例如：

```bash
ollama run nemotron-3-super:120b
```

输入 `/bye` 退出。

验证模型可用：

```bash
ollama list
```

## 步骤 6. 创建推理提供者

我们将创建一个 OpenShell 提供者，指向你的本地 Ollama 服务器。这允许 OpenShell 将推理请求路由到你的 Spark 托管模型。

首先，找到你的 DGX Spark 的 IP 地址：

```bash
hostname -I | awk '{print $1}'
```

然后创建提供者，将 `{Machine_IP}` 替换为上述命令中的 IP 地址（例如 `10.110.106.169`）：

```bash
openshell provider create \
    --name local-ollama \
    --type openai \
    --credential OPENAI_API_KEY=not-needed \
    --config OPENAI_BASE_URL=http://{Machine_IP}:11434/v1
```

> [!IMPORTANT]
> **不要**在此处使用 `localhost` 或 `127.0.0.1`。OpenShell 网关在 Docker 容器内运行，因此无法通过 `localhost` 到达主机。使用主机的实际 IP 地址。

验证创建了提供者：

```bash
openshell provider list
```

## 步骤 7. 配置推理路由

将 `inference.local` 端点（对每个沙箱可用）指向你的 Ollama 模型。将模型名称替换为你在步骤 5 中的选择：

```bash
openshell inference set \
    --provider local-ollama \
    --model nemotron-3-super:120b
```

输出应确认路由并显示经过验证的端点 URL，例如：`http://10.110.106.169:11434/v1/chat/completions (openai_chat_completions)`。

> [!NOTE]
> 如果你看到 `failed to verify inference endpoint` 或 `failed to connect`（例如因为网关无法从其容器内到达主机 IP），添加 `--no-verify` 跳过端点验证：`openshell inference set --provider local-ollama --model nemotron-3-super:120b --no-verify`。确保 Ollama 正在运行并监听所有接口（参见步骤 5）。

验证配置：

```bash
openshell inference get
```

预期输出应显示 `provider: local-ollama` 和 `model: nemotron-3-super:120b`（或你选择的任何模型）。

## 步骤 8. 部署 OpenShell 沙箱

使用预构建的 OpenClaw 社区沙箱创建沙箱。这从 OpenShell 社区目录中拉取 OpenClaw Dockerfile、默认策略和启动脚本：

```bash
openshell sandbox create \
  --keep \
  --forward 18789 \
  --name dgx-demo \
  --from openclaw \
  -- openclaw-start
```

> [!NOTE]
> 使用 `--from openclaw` 时，**不要**使用本地文件路径（例如 `openclaw-policy.yaml`）传递 `--policy`。策略与社区沙箱捆绑在一起；本地文件路径可能导致 "file not found"。

`--keep` 标志在初始进程退出后保持沙箱运行，以便你以后可以重新连接。这是默认行为。要使沙箱在初始进程退出时终止，请使用 `--no-keep` 标志。

CLI 将：
1. 根据社区目录解析 `openclaw`
2. 拉取并构建容器镜像
3. 应用捆绑的沙箱策略
4. 在沙箱内启动 OpenClaw

## 步骤 9. 在 OpenShell 沙箱内配置 OpenClaw

沙箱容器将启动，OpenClaw 入门向导将自动在你的终端中启动。

> [!IMPORTANT]
> 入门向导是**完全交互式**的——它需要箭头键导航和 Enter 键选择选项。它无法从非交互式会话（例如脚本或自动化工具）完成。你必须从具有完整 TTY 支持的终端运行 `openshell sandbox create`。
>
> 如果向导未在沙箱创建期间完成，重新连接到沙箱以重新运行它：
> ```bash
> openshell sandbox connect dgx-demo
> ```

使用箭头键和 Enter 键与安装进行交互。
- 如果你理解并同意，使用你的键盘的箭头键选择 'Yes' 并按 Enter 键。
- 快速入门与手动：选择快速入门并按 Enter 键。
- 模型/身份验证提供者：选择 **Custom Provider**（自定义提供者），倒数第二个选项。
- API 基 URL：更新为 https://inference.local/v1
- 你希望如何提供此 API 密钥？：暂时选择粘贴 API 密钥。
- API 密钥：请输入 "ollama"。
- 端点兼容性：选择 **OpenAI-compatible**（OpenAI 兼容）并按 Enter 键。
- 模型 ID：输入你在步骤 5 中选择的模型名称（例如 `nemotron-3-super:120b`）。
    - 这可能需要 1-2 分钟，因为 Ollama 模型在后台启动。
- 端点 ID：保留默认值。
- 别名：输入相同的模型名称（可选）。
- 频道：选择 **Skip for now**（暂时跳过）。
- 搜索提供者：选择 **Skip for now**。
- 技能：暂时选择 **No**。
- 启用钩子：按空格键选择 **Skip for now** 并按 Enter 键。

最终阶段可能需要 1-2 分钟。之后，你应该看到一个 URL 和一个令牌，你可以用它连接到网关。预期的输出将相似，但令牌是唯一的。

```bash
OpenClaw 网关在后台启动。
  日志: /tmp/gateway.log
  UI:   http://127.0.0.1:18789/?token=9b4c9a9c9f6905131327ce55b6d044bd53e0ec423dd6189e
```

现在我们已经在 OpenShell 沙箱内配置了 OpenClaw，让我们将 openshell 沙箱的名称设置为环境变量。这将使未来的命令更容易运行。请注意，沙箱的名称是在 `openshell sandbox create` 命令中设置的。

```bash
export SANDBOX_NAME=dgx-demo
```

为了验证为你的沙箱启用的默认策略，请运行以下命令：

```bash
openshell sandbox get $SANDBOX_NAME
```

> [!NOTE]
> 步骤 8 中的 `--forward 18789` 已经设置了从 OpenShell 网关到沙箱的端口转发。通常情况下，你**不需要**手动使用 `ssh` 命令与 `openshell ssh-proxy`。

为了验证转发是否处于活动状态，请使用以下命令：

```bash
openshell forward list
```

你应该看到你的沙箱名称（例如 `dgx-demo`）和端口 `18789`。如果缺少或 `dead`（已停止），请启动它：

```bash
openshell forward start --background 18789 $SANDBOX_NAME
```

**路径 A：** 如果你将 Spark 作为主要设备使用，右键单击 UI 部分中的 URL 并选择打开链接。

**路径 B：** 如果你使用的是 Spark 以外的笔记本电脑或工作站（例如你仅通过 SSH 连接到 Spark）：在**该**机器上安装 OpenShell CLI。

> [!IMPORTANT]
> **在此机器到 Spark 之间必须可以使用 SSH。**运行 `ssh nvidia@<spark-ip>`（或你的用户/主机）并确认你获得一个 shell 而没有 `Permission denied (publickey)`。如果失败，将你的公钥添加到 Spark：`ssh-copy-id nvidia@<spark-ip>`（从同一台机器），或将你的 `~/.ssh/id_ed25519.pub`（或 `id_rsa.pub`）粘贴到 Spark 上的 `~/.ssh/authorized_keys`。OpenShell 使用此 SSH 会话到达远程 Docker API 并提取网关 TLS 证书。如果使用非默认密钥，将 `--ssh-key ~/.ssh/your_key` 传递给 `gateway add`（与步骤 4 的远程网关说明相同）。

注册 Spark 的**已运行**网关。**不要**单独使用 `openshell gateway add user@ip`—这被解析为云 URL，不会写入 `mtls/ca.crt`。

根据 [OpenShell 网关文档](https://docs.nvidia.com/openshell/latest/sandboxes/manage-gateways.html)，使用 **hostname `openshell`** 而不是原始 Spark IP 进行 HTTPS。

> [!WARNING]
> 网关 TLS 证书仅对 `openshell`、`localhost` 和 `127.0.0.1` 有效——**不**适用于你的 Spark 的 LAN IP。如果你使用 `https://10.x.x.x:8080` 或 `ssh://user@10.x.x.x:8080`，`openshell status` 可能会因 **certificate not valid for name "10.x.x.x"** 而失败。

**在你的笔记本电脑/WSL 上**，将 `openshell` 映射到 Spark（每台机器一次）：

```bash
## 替换为你的 Spark 的 IP。需要 Linux/WSL 上的 sudo。
echo "<spark-ip> openshell" | sudo tee -a /etc/hosts
## 例如：echo "10.110.17.10 openshell" | sudo tee -a /etc/hosts
```

然后添加网关（SSH 目标保持真实 IP 或主机名；HTTPS URL 使用 `openshell`）：

```bash
openshell gateway add https://openshell:8080 --remote <user>@<spark-ip>
```

例如：

```bash
openshell gateway add https://openshell:8080 --remote nvidia@10.110.17.10
```

如果你已经使用 IP 注册并看到证书错误，请删除该条目并重新添加：

```bash
openshell gateway destroy 
openshell gateway add https://openshell:8080 --remote nvidia@10.110.17.10
```

（使用 `openshell gateway select` 如果销毁名称不同。）

完成任何浏览器或 CLI 提示直到命令完成（不要过早按 Ctrl+C）。然后：

```bash
openshell status   # 应该显示 Connected，而不是 TLS CA 错误
openshell forward start --background 18789 dgx-demo
```

然后在**笔记本电脑**浏览器中打开（使用 `#token=` 以便 UI 接收网关令牌）：

`http://127.0.0.1:18789/#token=<your-token>`

使用来自 Spark 上 OpenClaw 向导输出的令牌值。路径 B 需要从笔记本电脑到 Spark 的 SSH，以便 CLI 可以在 `:8080` 上到达网关。

**NVIDIA Sync：** 右键单击 UI 中的 URL 并选择复制链接。在 Sync 中连接到你的 Spark，打开 OpenClaw 条目，并将 URL 粘贴到浏览器地址栏中。

从此页面，你现在可以**聊天**与你的 OpenClaw 代理，在 OpenShell 提供的受保护环境中。

## 步骤 10. 在沙箱内进行推理

#### 连接到沙箱（终端）

现在 OpenClaw 已在 OpenShell 受保护的运行时内配置，你可以直接通过以下方式连接到沙箱环境：

```bash
openshell sandbox connect $SANDBOX_NAME
```

加载到沙箱终端后，你可以使用此命令测试与 Ollama 模型的连接：
```bash
curl https://inference.local/v1/responses \
          -H "Content-Type: application/json" \
          -d '{
        "instructions": "You are a helpful assistant.",
        "input": "Hello!"
      }'
```

## 步骤 11. 验证沙箱隔离

打开第二个终端并检查沙箱状态和实时日志：

```bash
source ~/openshell-env/bin/activate
openshell term
```

终端仪表板显示：
- **沙箱状态** — 名称、阶段、镜像、提供者和端口转发
- **实时日志流** — 出站连接、策略决策 (`allow`、`deny`、`inspect_for_inference`) 和推理拦截

验证 OpenClaw 代理是否可以到达 `inference.local` 进行模型请求，以及未授权的出站流量是否被拒绝。

> [!TIP]
> 按 `f` 跟随实时输出，`s` 按源过滤，`q` 退出终端仪表板。

## 步骤 12. 重新连接到沙箱

如果你退出沙箱会话，随时可以重新连接：

```bash
openshell sandbox connect $SANDBOX_NAME
```

> [!NOTE]
> `openshell sandbox connect` 是交互式独占的——它在沙箱内打开一个终端会话。无法传递命令进行非交互式执行。使用 `openshell sandbox upload`/`download` 进行文件传输，或使用 `openshell sandbox ssh-config` 进行脚本 SSH（参见步骤 14）。

要将文件上传或下载出沙箱，请使用以下命令：

```bash
openshell sandbox upload $SANDBOX_NAME ./local-file /sandbox/destination
openshell sandbox download $SANDBOX_NAME /sandbox/file ./local-destination
```

## 步骤 13. 清理

停止并删除沙箱：

```bash
openshell sandbox delete $SANDBOX_NAME
```

删除你在步骤 6 中创建的推理提供者：

```bash
openshell provider delete local-ollama
```

停止网关（保留状态以备以后使用）：

```bash
openshell gateway stop
```

> [!WARNING]
> 以下命令永久删除网关集群及其所有数据。

```bash
openshell gateway destroy
```

还要删除 Ollama 模型：

```bash
ollama rm nemotron-3-super:120b
```

## 步骤 14. 下一步

- **添加更多提供者**：使用 `openshell provider create` 附加 GitHub 令牌、GitLab 令牌或云 API 密钥作为提供者。创建沙箱时，使用 `--provider <name>`（例如 `--provider my-github`）将这些凭证注入沙箱中安全使用。

- **尝试其他社区沙箱**：运行 `openshell sandbox create --from base` 或 `--from sdg` 以获得其他预构建环境。

- **连接 VS Code**：使用 `openshell sandbox ssh-config <sandbox-name>` 并将输出附加到 `~/.ssh/config` 以直接将 VS Code Remote-SSH 连接到沙箱。

- **监控和审核**：使用 `openshell logs <sandbox-name> --tail` 或 `openshell term` 持续监控代理活动和策略决策。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| `openshell gateway start` 因 "connection refused" 或 Docker 错误而失败 | Docker 未运行 | 使用 `sudo systemctl start docker` 启动 Docker 或启动 Docker Desktop，然后重试 `openshell gateway start` |
| `openshell status` 显示网关不健康 | 网关容器崩溃或初始化失败 | 运行 `openshell gateway destroy` 然后 `openshell gateway start` 重新创建它。使用 `docker ps -a` 和 `docker logs <container-id>` 检查 Docker 日志获取详情 |
| `openshell sandbox create --from openclaw` 无法构建 | 拉取社区沙箱或 Dockerfile 构建失败的网络问题 | 检查互联网连接。重试命令。如果构建在特定包上失败，请检查基础镜像是否与你的 Docker 版本兼容 |
| 创建后沙箱处于 `Error` 阶段 | 策略验证失败或容器启动崩溃 | 运行 `openshell logs <sandbox-name>` 查看错误详情。常见原因：无效的策略 YAML、缺少的提供者凭证或端口冲突 |
| 代理无法在沙箱内到达 `inference.local` | 未配置推理路由或提供者无法访问 | 运行 `openshell inference get` 验证提供者和模型是否已设置。测试主机上 Ollama 是否可访问：`curl http://localhost:11434/api/tags`。确保提供者 URL 使用 `host.docker.internal` 而不是 `localhost` |
| 503 验证失败或网关/沙箱访问主机上的 Ollama 时超时 | Ollama 仅绑定到 localhost，或主机防火墙阻止端口 11434 | 使 Ollama 监听所有接口，以便网关容器（例如在 Docker 网络 172.17.x.x 上）可以访问它：`OLLAMA_HOST=0.0.0.0 ollama serve &`。允许端口 11434 通过主机防火墙：`sudo ufw allow 11434/tcp comment 'Ollama for OpenShell Gateway'`（然后 `sudo ufw reload` 如果需要） |
| 代理的所有出站连接都被拒绝 | 默认策略不包括所需的端点 | 使用 `openshell logs <sandbox-name> --tail --source sandbox` 监控拒绝。使用 `openshell policy get <sandbox-name> --full` 拉取当前策略，在 `network_policies` 下添加所需的主机/端口，并使用 `openshell policy set <sandbox-name> --policy <file> --wait` 推送 |
| "Permission denied" 或沙箱内的 Landlock 错误 | 代理尝试访问文件系统策略中未包含的路径 | 拉取当前策略并在 `read_write`（或如果读访问足够则在 `read_only`）中添加路径。推送更新的策略。注意：文件系统策略是静态的，需要重新创建沙箱 |
| Ollama OOM 或推理非常缓慢 | 模型太大，无法在可用内存或 GPU 竞争中运行 | 释放 GPU 内存（关闭其他 GPU 工作负载）、尝试较小的模型（例如 `gpt-oss:20b`）或减少上下文长度。使用 `nvidia-smi` 监控 |
| `openshell sandbox connect` 挂起或超时 | 沙箱未处于 `Ready` 阶段 | 运行 `openshell sandbox get <sandbox-name>` 检查阶段。如果卡在 `Provisioning`，请等待或检查日志。如果处于 `Error`，请删除并重新创建沙箱 |
| 策略推送返回退出码 1（验证失败） | 格式错误的 YAML 或无效的策略字段 | 检查 YAML 语法。常见问题：路径不以 `/` 开头、路径中的 `..` 遍历、`root` 作为 `run_as_user`，或缺少所需 `host`/`port` 字段的端点。修复并重新推送 |
| `openshell gateway start` 因 "K8s namespace not ready" / 等待命名空间超时而失败 | Docker 容器内的 k3s 集群比 CLI 超时时间需要更长的时间进行引导。内部组件（TLS 密钥、Helm 图表、命名空间创建）可能需要额外的时间，尤其是在首次运行时在容器内拉取镜像时。 | 首先，检查容器是否仍在运行并进展：`docker ps --filter name=openshell`（查看 `health: starting`）。检查容器内的 k3s 状态：`docker exec <container> sh -c "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get ns"` 和 `kubectl get pods -A`。如果 pod 处于 `ContainerCreating` 且 TLS 密钥丢失（`navigator-server-tls`、`openshell-server-tls`），集群仍在引导——等待几分钟并再次运行 `openshell status`。如果它没有恢复，请使用 `openshell gateway destroy`（和 `docker rm -f <container>` 如果需要）销毁并重试 `openshell gateway start`。确保 Docker 有足够的资源（内存和磁盘）用于 k3s 集群。 |
| `openshell status` 显示 "No gateway configured" 即使 Docker 容器正在运行 | `gateway start` 命令失败或在保存网关配置之前超时 | 容器可能仍然健康——使用 `docker ps --filter name=openshell` 检查。如果容器正在运行且健康，请再次尝试 `openshell gateway start`（它应该检测到现有的容器）。如果容器不健康或卡住，请使用 `docker rm -f <container>` 删除它，然后 `openshell gateway destroy`，然后 `openshell gateway start`。 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），启用 GPU 和 CPU 内存之间的动态共享。
> 随着许多应用程序仍在更新以利用 UMA，你可能会在 DGX Spark 的内存容量内遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
