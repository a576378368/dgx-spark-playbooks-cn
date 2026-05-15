# Spark 上的 NIM

> 部署 Spark 上的 NIM

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

### 基本概念

NVIDIA NIM 是用于在 NVIDIA GPU 上快速、可靠地提供 AI 模型服务和推理的容器化软件。本操作指南演示如何在 DGX Spark 设备上运行 LLM 的 NIM 微服务，通过简单的 Docker 工作流实现本地 GPU 推理。您将使用 NVIDIA 的注册表进行身份验证，启动 NIM 推理微服务，并执行基本推理测试以验证功能。

### 您将实现的目标

您将在您的 DGX Spark 设备上启动一个 NIM 容器，以公开用于文本补全的 GPU 加速 HTTP 端点。虽然这些说明侧重于使用 Llama 3.1 8B NIM，但 DGX Spark 还有其他 NIM，包括 [Qwen3-32 NIM](https://catalog.ngc.nvidia.com/orgs/nim/teams/qwen/containers/qwen3-32b-dgx-spark)（在[此处](https://docs.nvidia.com/nim/large-language-models/1.14.0/release-notes.html#new-language-models)查看它们）。

### 开始前须知

- 在终端环境中工作
- 使用 Docker 命令和 GPU 启用容器
- 基本了解 REST API 和 curl 命令
- 了解 NVIDIA GPU 环境和 CUDA

## 先决条件

- 安装了 NVIDIA 驱动程序的 DGX Spark 设备
  ```bash
  nvidia-smi
  ```
- 配置了 NVIDIA Container Toolkit 的 Docker，说明[在此](https://docs.nvidia.com/dgx/dgx-spark/nvidia-container-runtime-for-docker.html)
  ```bash
  docker run -it --gpus=all nvcr.io/nvidia/cuda:13.0.1-devel-ubuntu24.04 nvidia-smi
  ```
- 从[此处](https://ngc.nvidia.com/setup/api-key)获取的 NGC 帐户和 API 密钥
  ```bash
  echo $NGC_API_KEY | grep -E '^[a-zA-Z0-9]{86}=='
  ```
- 用于模型缓存的足够磁盘空间（因模型而异，通常为 10-50GB）
  ```bash
  df -h ~
  ```


### 时间与风险

* **预计时间：** 15-30 分钟用于设置和验证
* **风险：**
  * 大型模型下载可能需要大量时间，具体取决于网络速度
  * GPU 内存要求因模型大小而异
  * 容器启动时间取决于模型加载
* **回滚方案：** 使用 `docker stop <CONTAINER_NAME> && docker rm <CONTAINER_NAME>` 停止并删除容器。如果需要回收磁盘空间，请从 `~/.cache/nim` 删除缓存的模型。
* **最后更新：** 2025年12月22日
  * 更新 docker 容器版本到 cuda:13.0.1-devel-ubuntu24.04
  * 添加 docker 容器权限设置说明

---

## 操作说明

## 步骤 1. 验证环境先决条件

检查您的系统是否满足运行 GPU 启用容器的基本要求。

```bash
nvidia-smi
docker --version
docker run --rm --gpus all nvcr.io/nvidia/cuda:13.0.1-devel-ubuntu24.04 nvidia-smi
```

如果您在 `docker` 上看到权限被拒绝错误（类似于尝试连接到 Docker 守护进程套接字时权限被拒绝），将您的用户添加到 docker 组，这样您就不需要使用 sudo 运行该命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 步骤 2. 配置 NGC 身份验证

使用您的 NGC API 密钥设置对 NVIDIA 容器注册表的访问权限。

```bash
export NGC_API_KEY="<YOUR_NGC_API_KEY>"
echo "$NGC_API_KEY" | docker login nvcr.io --username '$oauthtoken' --password-stdin
```

[此处省略剩余部分，由于文件较大]

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| `docker run` 权限被拒绝 | 用户不在 docker 组中 | `sudo usermod -aG docker $USER`，然后注销并重新登录 |
| NGC 身份验证失败 | API 密钥无效或过期 | 从 [NGC](https://ngc.nvidia.com/setup/api-key) 获取新密钥 |
| 容器启动失败 | 磁盘空间不足 | 检查磁盘空间 `df -h ~` 并清理 `~/.cache/nim` |
| 模型加载超时 | 网络问题或 NGC 访问问题 | 检查网络连接和 NGC API 密钥 |
| GPU 未检测到 | CUDA 驱动程序问题 | 验证 `nvidia-smi` 和驱动程序安装 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的灵活共享。一些软件仍在赶上 UMA 行为。如果您意外遇到内存压力，您可以尝试刷新页面缓存（在共享系统上小心使用）：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的平台问题，请参阅 [DGX Spark 已知问题](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html) 文档。
