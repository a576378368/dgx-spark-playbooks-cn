# NVFP4 量化

> 使用 TensorRT Model Optimizer 将模型量化为 NVFP4 以在 Spark 上运行

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

NVFP4 是 NVIDIA Blackwell GPU 引入的 4 位浮点格式，旨在在减少推理工作负载的内存带宽和存储需求的同时保持模型准确性。
与均匀 INT4 量化不同，NVFP4 保留了浮点语义，具有共享指数和紧凑尾数，允许更高的动态范围和更稳定的收敛。
NVIDIA Blackwell 张量核心原生支持 FP16、FP8 和 FP4 的混合精度执行，允许模型在 FP4 中使用权重和激活，同时以更高精度（通常为 FP16）进行累加。
此设计在矩阵乘法期间最小化量化误差，并在 TensorRT-LLM 中支持高效的转换管道，用于逐层量化。

立即优势：
  - 与 FP16 相比，内存使用量减少约 3.5 倍，与 FP8 相比减少约 1.8 倍
  - 保持接近 FP8 的准确性（通常损失 <1%）
  - 提高推理的速度和能源效率

## 您将实现的目标

您将使用 NVIDIA 的 TensorRT Model Optimizer 在 TensorRT-LLM 容器内量化 DeepSeek-R1-Distill-Llama-8B 模型，
生成用于部署在 NVIDIA DGX Spark 上的 NVFP4 量化模型。

示例使用 NVIDIA FP4 量化模型，通过减少模型层的精度帮助将模型大小减少约 2 倍。
这种量化方法旨在在提供显著吞吐量改进的同时保持准确性。但是，重要的是要注意量化可能会影响模型准确性 - 我们建议运行评估以验证量化模型是否保持您用例所需的可接受性能。

## 开始前须知

- 使用 Docker 容器和 GPU 加速工作负载
- 了解模型量化概念及其对推理性能的影响
- 有 NVIDIA TensorRT 和 CUDA 工具包环境的经验
- 熟悉 Hugging Face 模型存储库和身份验证

## 先决条件

- 具有 Blackwell 架构 GPU 的 NVIDIA Spark 设备
- 安装了 GPU 支持的 Docker
- 配置了 NVIDIA Container Toolkit
- 可用存储用于模型文件和输出
- 具有目标模型访问权限的 Hugging Face 帐户

验证您的设置：
```bash
## 检查 Docker GPU 访问
docker run --rm --gpus all nvcr.io/nvidia/tensorrt-llm/release/spark-single-gpu-dev nvidia-smi

## 验证足够的磁盘空间
df -h .
```

## 时间与风险

* **预计持续时间**：45-90 分钟，具体取决于网络速度和模型大小
* **风险：**
  * 模型下载可能因网络问题或 Hugging Face 身份验证问题而失败
  * 量化过程是内存密集型的，可能在 GPU 内存不足的系统上失败
  * 输出文件很大（几个 GB），需要足够的存储空间
* **回滚方案**：删除输出目录和任何拉取的 Docker 镜像以恢复原始状态。
* **最后更新：** 2025年12月15日
  * 修复步骤 8 中的中断客户端 CURL 请求
  * 更新 ModelOptimizer 项目名称

---

## 操作说明

## 步骤 1. 配置 Docker 权限

要轻松管理容器而不使用 sudo，您必须在 `docker` 组中。如果您选择跳过此步骤，则需要使用 sudo 运行 Docker 命令。

打开一个新终端并测试 Docker 访问。在终端中，运行：

```bash
docker ps
```

如果您看到权限被拒绝错误（类似于尝试连接到 Docker 守护进程套接字时权限被拒绝），将您的用户添加到 docker 组，这样您就不需要使用 sudo 运行该命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## 步骤 2. 准备环境

创建一个本地输出目录，其中将存储量化模型文件。此目录将挂载到容器中，以便在容器退出后保留结果。

```bash
mkdir -p ./output_models
chmod 755 ./output_models
```

## 步骤 3. 使用 Hugging Face 身份验证

[此处省略剩余部分，由于文件较大]

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| `docker run` 权限被拒绝 | 用户不在 docker 组中 | `sudo usermod -aG docker $USER`，然后注销并重新登录 |
| Hugging Face 身份验证失败 | API 密钥无效或过期 | 从 [Hugging Face](https://huggingface.co/settings/tokens) 获取新密钥 |
| 容器启动失败 | 磁盘空间不足 | 检查磁盘空间 `df -h ~` 并清理 |
| GPU 内存不足 | 模型太大，无法获得可用的 GPU 内存 | 使用较小的模型或减少量化配置 |
| 量化失败 | 系统内存不足 | 检查系统内存并增加交换空间 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的灵活共享。一些软件仍在赶上 UMA 行为。如果您意外遇到内存压力，您可以尝试刷新页面缓存（在共享系统上小心使用）：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的平台问题，请参阅 [DGX Spark 已知问题](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html) 文档。
