# 构建视频搜索和摘要 (VSS) 代理

> 在您的 Spark 上运行 VSS Blueprint

## 目录

- [概述](#概述)
- [安装说明](#安装说明)
- [故障排除](#故障排除)

---

## 概述

## 基本原理

部署 NVIDIA 的视频搜索和摘要 (VSS) AI Blueprint，构建智能视频分析系统，结合视觉语言模型、大语言模型和检索增强生成。该系统将原始视频内容转换为实时可操作见解，包括视频摘要、问答和实时警报。您可以设置完全本地的事件审查员部署或使用远程模型端点的混合部署。

## 您将完成的工作

您将在配备 Blackwell 架构的 NVIDIA Spark 硬件上部署 NVIDIA VSS AI Blueprint，选择两种部署场景之一：VSS 事件审查员（完全本地，带有 VLM 管道）或标准 VSS（使用远程 LLM/嵌入端点的混合部署）。这包括设置警报桥、VLM 管道、警报检查器 UI、视频存储工具包和可选的 DeepStream CV 管道，用于自动视频分析和事件审查。

## 开始前需要了解

- 使用 NVIDIA Docker 容器和容器注册表
- 设置带有共享网络的 Docker Compose 环境
- 管理环境变量和身份验证令牌
- 基本了解视频处理和分析工作流程

## 前置条件

- 具有 ARM64 架构和 Blackwell GPU 的 NVIDIA Spark 设备
- DGX OS（建议：7.4.0 或更高版本）
- 已安装驱动程序版本 580.95.05 或更高：`nvidia-smi | grep "Driver Version"`
- 已安装 CUDA 版本 13.0：`nvcc --version`
- 已安装并运行 Docker：`docker --version && docker compose version`
- 具有 [NGC API 密钥](https://org.ngc.nvidia.com/setup/api-keys) 的 NVIDIA 容器注册表访问权限
- NVIDIA Container Toolkit
- [可选] 用于远程模型端点的 NVIDIA API 密钥（仅混合部署）
- 足够的存储空间用于视频处理（`/tmp/` 中推荐 >10GB）

## 辅助文件

- [VSS Blueprint GitHub 仓库](https://github.com/NVIDIA-AI-Blueprints/video-search-and-summarization) - 主代码库和 Docker Compose 配置
- [VSS 官方文档](https://docs.nvidia.com/vss/latest/index.html) - 完整系统文档

## 时间与风险

* **持续时间：** 初始设置需 30-45 分钟，视频处理验证需额外时间
* **风险：**
  * 容器启动可能资源密集且耗时，尤其是大型模型下载
  * 如果共享网络已存在，网络配置冲突
  * 远程 API 端点可能有速率限制或连接问题（混合部署）
* **回滚：** 使用 `scripts/dev-profile.sh down` 停止所有容器
* **最后更新：** 2026 年 3 月 16 日
  * 更新所需的 OS 和驱动程序版本
  * 支持带有 Cosmos Reason 2 VLM 的 VSS 3.1.0

## 安装说明

## 步骤 1. 验证环境要求

检查您的系统是否满足硬件和软件 [前置条件](https://docs.nvidia.com/vss/latest/prerequisites.html)。

```bash
## 验证驱动程序版本
nvidia-smi | grep "Driver Version"
## 预期输出：Driver Version: 580.126.09 或更高

## 验证 CUDA 版本
nvcc --version
## 预期输出：release 13.0

## 验证 Docker 正在运行
docker --version && docker compose version
```

## 步骤 2. 配置 Docker

为方便管理容器而无需使用 sudo，您必须在 `docker` 组中。如果您选择跳过此步骤，您需要使用 sudo 运行 Docker 命令。打开新终端并测试 Docker 访问。在终端中运行：

```bash
docker ps
```

如果您看到权限被拒绝错误（例如尝试连接到 Docker 守护程序套接字时被拒绝），请将您的用户添加到 docker 组，这样您就不需要使用 sudo 运行该命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

此外，配置 Docker 以使用 NVIDIA Container Runtime。

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

## 运行示例工作负载以验证设置
sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

## 步骤 3. 克隆 VSS 仓库

从 NVIDIA 的公共 GitHub 克隆视频搜索和摘要仓库。

```bash
## 克隆 VSS AI Blueprint 仓库
git clone https://github.com/NVIDIA-AI-Blueprints/video-search-and-summarization.git
cd video-search-and-summarization
```

## 步骤 4. 运行缓存清理脚本

启动系统缓存清理器以优化容器操作期间的内存使用。

在 /usr/local/bin/sys-cache-cleaner.sh 创建缓存清理器脚本

```bash
sudo tee /usr/local/bin/sys-cache-cleaner.sh << 'EOF'
#!/bin/bash
## 如果任何命令失败，立即退出
set -e

## 禁用大页面
echo "禁用 vm/nr_hugepage"
echo 0 | tee /proc/sys/vm/nr_hugepages

## 通知缓存清理器正在运行
echo "启动缓存清理器 - 运行中"
echo "按 Ctrl + C 停止"
## 每 3 秒重复同步并清除缓存
while true; do
     sync && echo 3 | tee /proc/sys/vm/drop_caches > /dev/null
     sleep 3
done
EOF

sudo chmod +x /usr/local/bin/sys-cache-cleaner.sh
```

在后台运行

```bash
## 在另一个终端中，启动缓存清理器脚本。
sudo -b /usr/local/bin/sys-cache-cleaner.sh
```

> [!NOTE]
> 上述仅在当前会话中运行缓存清理器；它不会在重启后持续。要使缓存清理器在重启后持续运行，请创建 systemd 服务。
> 
> 要停止后台缓存清理器：
> ```bash
> sudo pkill -f sys-cache-cleaner.sh
> ```

## 步骤 5. 使用 NVIDIA Container Registry 进行身份验证

使用您的 [NGC API 密钥](https://org.ngc.nvidia.com/setup/api-keys) 登录 NVIDIA 的容器注册表。

> [!NOTE]
> 如果您还没有 NVIDIA 帐户，则需要创建一个帐户并注册 [开发者计划](https://developer.nvidia.com/nvidia-developer-program)。

```bash
## 登录 NVIDIA Container Registry
docker login nvcr.io
## 用户名：$oauthtoken
## 密码：<在此处粘贴 NGC API 密钥>
```

## 步骤 6. 选择部署场景

根据您的需求选择两种部署选项之一：

| 部署场景                       | VLM (Cosmos-Reason2-8B)| LLM                           | 
|-------------------------------------------|------------------------|-------------------------------|
| 标准 VSS (基础)                       | 本地           | 远程                               |
| 标准 VSS (警报验证)         | 本地           | 远程                               |
| 标准 VSS 部署 (实时警报)| 本地           | 远程                               |

## 步骤 7. 标准 VSS 

**[标准 VSS](https://docs.nvidia.com/vss/latest/#architecture-overview) (混合部署)**

在此混合部署中，我们将使用 [build.nvidia.com](https://build.nvidia.com/) 的 NIM。或者，您可以按照 [VSS 远程 LLM 部署指南](https://docs.nvidia.com/vss/latest/vss-agent/configure-llm.html) 中的说明配置自己的托管端点。

**7.1 获取 NVIDIA API 密钥**

- 登录 https://build.nvidia.com/explore/discover。
- 在页面上搜索 **获取 API 密钥** 并点击它。

**7.2 启动标准 VSS 部署**

[标准 VSS 部署 (基础)](https://docs.nvidia.com/vss/latest/quickstart.html#deploy)
[标准 VSS 部署 (警报验证)](https://docs.nvidia.com/vss/latest/agent-workflow-alert-verification.html)
[标准 VSS 部署 (实时警报)](https://docs.nvidia.com/vss/latest/agent-workflow-rt-alert.html#real-time-alert-workflow)

```bash
## 启动标准 VSS (基础)
export NGC_CLI_API_KEY='***'
export LLM_ENDPOINT_URL=https://your-llm-endpoint.com
scripts/dev-profile.sh up -p base -H DGX-SPARK --use-remote-llm --llm <远程 LLM 模型名称>

## 启动标准 VSS (警报验证)
export NGC_CLI_API_KEY='***'
export LLM_ENDPOINT_URL=https://your-llm-endpoint.com
scripts/dev-profile.sh up -p alerts -m verification -H DGX-SPARK --use-remote-llm --llm <远程 LLM 模型名称>

## 启动标准 VSS (实时警报)
export NGC_CLI_API_KEY='***'
export LLM_ENDPOINT_URL=https://your-llm-endpoint.com
scripts/dev-profile.sh up -p alerts -m real-time -H DGX-SPARK --use-remote-llm --llm <远程 LLM 模型名称>
```

> [!NOTE]
> 此步骤将花费几分钟，因为容器正在拉取并且服务正在初始化。VSS 后端需要额外的启动时间。
> 部署前设置以下环境变量：
> • **NGC_CLI_API_KEY** —（必需）用于拉取镜像和部署的 NGC API 密钥
> • **LLM_ENDPOINT_URL** —（使用 `--use-remote-llm` 时必需）远程 LLM 的基本 URL
> • **NVIDIA_API_KEY** —（可选）需要它的远程 LLM/VLM 端点
> • **OPENAI_API_KEY** —（可选）需要它的远程 LLM/VLM 端点
> • **VLM_CUSTOM_WEIGHTS** —（可选）自定义权重目录的绝对路径
> 
> 将以下额外标志传递给 **`scripts/dev-profile.sh`** 用于远程 LLM 模式：
> • **`--use-remote-llm`** —（必需）使用远程 LLM，基本 URL 从环境中的 **`LLM_ENDPOINT_URL`** 读取
> • **`--llm`** —（必需）远程 LLM 模型名称（例如：`nvidia/nvidia-nemotron-nano-9b-v2`）。**强烈推荐**用于警报工作流（验证和实时）：使用 `nvidia/nvidia-nemotron-nano-9b-v2`。省略 `--llm` 可能导致脚本使用远程端点返回的任何模型。
> 
> 运行 **`scripts/dev-profile.sh -h`** 了解支持参数的完整列表。

**7.3 验证标准 VSS 部署**

访问 VSS UI 以确认成功部署。
[常见 VSS 端点](https://docs.nvidia.com/vss/latest/agent-workflow-alert-verification.html#service-endpoints)

```bash
## 测试 Agent UI 可访问性
## 如果在 Spark 设备上本地运行，请使用 localhost：
curl -I http://localhost:3000
## 预期：HTTP 200 响应

## 如果您的 Spark 在远程/配件模式下运行，请将 'localhost' 替换为 Spark 设备的 IP 地址或主机名。
## 要查找 Spark 的 IP 地址，请在 Spark 终端上运行以下命令：
hostname -I
## 或获取主机名：
hostname
## 然后测试可访问性（将 <SPARK_IP_OR_HOSTNAME> 替换为实际值）：
curl -I http://<SPARK_IP_OR_HOSTNAME>:3000
```

在浏览器中打开 `http://localhost:3000` 或 `http://<SPARK_IP_OR_HOSTNAME>:3000` 以访问 Agent 界面。

## 步骤 8. 测试视频处理工作流程

运行基本测试以验证视频分析管道根据您的部署正常运行。UI 随附一些示例视频，用于上传和测试

**对于标准 VSS 部署**

按照 [此处](https://docs.nvidia.com/vss/latest/quickstart.html#deploy) 的步骤导航 VSS Agent UI。
- 在 `http://localhost:3000` 访问 VSS Agent 界面
- 从 NGC [此处](https://docs.nvidia.com/vss/latest/quickstart.html#download-sample-data-from-ngc) 下载示例数据并上传视频进行测试 [此处](https://docs.nvidia.com/vss/latest/quickstart.html#download-sample-data-from-ngc)

## 步骤 9. 清理和回滚

要完全删除 VSS 部署并释放系统资源 [遵循](https://docs.nvidia.com/vss/latest/quickstart.html#step-5-teardown-the-agent)：

> [!WARNING]
> 这将销毁所有处理的视频数据和分析结果。

```bash
## 对于标准 VSS 部署
scripts/dev-profile.sh down
```

## 步骤 10. 后续步骤

部署 VSS 后，您可以：

**标准 VSS 部署：**
- 在端口 3000 访问完整 VSS 功能
- 测试视频摘要和问答功能
- 配置知识图谱和图数据库
- 与现有视频处理工作流程集成

## 故障排除

| 症状 | 原因 | 解决方法 |
|-------|--------|-----|
| 容器启动失败，显示"拉取访问被拒绝" | 缺少或不正确的 nvcr.io 凭证 | 重新运行 `docker login nvcr.io`，使用有效凭证 |
| Web 界面无法访问 | 服务仍在启动或端口冲突 | 等待 2-3 分钟，检查 `docker ps` 了解容器状态 |

> [!NOTE]
> DGX Spark 使用统一内存架构 (UMA)，允许 GPU 和 CPU 之间动态共享内存。
> 许多应用程序仍在更新以利用 UMA，您可能会遇到内存问题，即使在 DGX Spark 的内存容量内。
> 如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

---

*翻译完成*
