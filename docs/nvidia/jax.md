# 优化 JAX

> 优化 JAX 以在 Spark 上运行

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

JAX 让您能够编写 **NumPy 风格的 Python 代码** 并在 GPU 上快速运行，而无需编写 CUDA。它通过以下方式实现：

- **加速器上的 NumPy**：像使用 NumPy 一样使用 `jax.numpy`，但数组位于 GPU 上。
- **函数变换**：
  - `jit` → 将您的函数编译为快速的 GPU 代码
  - `grad` → 提供自动微分
  - `vmap` → 批量向量化您的函数
  - `pmap` → 并行跨多个 GPU 运行
- **XLA 后端**：JAX 将您的代码交给 XLA（加速线性代数编译器），它融合操作并生成优化的 GPU 内核。

## 您将实现的目标

您将设置一个 JAX 开发环境，运行在具有 Blackwell 架构的 NVIDIA Spark 上，能够使用熟悉的 NumPy 类抽象进行高性能机器学习原型设计，具有 GPU 加速和性能优化功能。

## 开始前须知

- 熟练使用 Python 和 NumPy 编程
- 了解机器学习工作流和技术的一般概念
- 具备终端使用经验
- 具备容器使用和构建经验
- 熟悉不同版本的 CUDA
- 基本理解线性代数（高中数学水平足够）

## 先决条件

- 具有 Blackwell 架构的 NVIDIA Spark 设备
- ARM64 (AArch64) 处理器架构
- 已安装 Docker 或容器运行时
- 已配置 NVIDIA 容器工具包
- 验证 GPU 访问：`nvidia-smi`
- 端口 8080 可用于 marimo 笔记本访问

## 辅助文件

所有必需的资源都可以在 [此处的 GitHub](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main) 找到：

- [**JAX 介绍笔记本**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/jax/assets/jax-intro.py) — 涵盖 JAX 编程模型与 NumPy 的差异和性能评估
- [**NumPy SOM 实现**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/jax/assets/numpy-som.py) — NumPy 中自组织映射训练算法的参考实现
- [**JAX SOM 实现**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/jax/assets/som-jax.py) — JAX 中 SOM 算法的多个迭代改进实现
- [**环境配置**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/jax/assets/Dockerfile) — 包依赖和容器设置规范

## 时间与风险

* **持续时间：** 2-3 小时，包括设置、教程完成和验证
* **风险：**
  * Python 环境中的包依赖冲突
  * 性能验证可能需要特定架构的优化
* **回滚方案：** 容器环境提供隔离；移除容器并重启以重置状态。
* **最后更新：** 2025年11月7日
  * 少量文字编辑

---

## 操作说明

## 步骤 1. 验证系统先决条件

确认您的 NVIDIA Spark 系统满足要求并配置了 GPU 访问。

```bash
## 验证 GPU 访问
nvidia-smi

## 验证 ARM64 架构
uname -m

## 检查 Docker GPU 支持
docker run --gpus all --rm nvcr.io/nvidia/cuda:13.0.1-runtime-ubuntu24.04 nvidia-smi
```

如果您看到权限被拒绝错误（类似"在尝试连接到 Docker 守护进程套接字时权限被拒绝"），将您的用户添加到 docker 组，这样就不需要使用 sudo 运行命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## 步骤 2. 克隆操作指南存储库

```bash
git clone https://github.com/NVIDIA/dgx-spark-playbooks
```

## 步骤 3. 构建 Docker 镜像

> [!WARNING]
> 此命令将下载基础镜像并在本地构建容器以支持此环境。

```bash
cd dgx-spark-playbooks/nvidia/jax/assets
docker build -t jax-on-spark .
```

## 步骤 4. 启动 Docker 容器

在 Docker 容器中运行 JAX 开发环境，具有 GPU 支持和 marimo 访问的端口转发。

```bash
docker run --gpus all --rm -it \
    --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 \
    -p 8080:8080 \
    jax-on-spark
```

## 步骤 5. 访问 marimo 界面

连接到 marimo 笔记本服务器以开始 JAX 教程。

```bash
## 通过 Web 浏览器访问
## 导航到：http://localhost:8080
```

界面将加载一个目录表格显示和 marimo 的简要介绍。

## 步骤 6. 完成 JAX 介绍教程

完成入门材料以了解 JAX 编程模型与 NumPy 的差异。

导航到并完成 JAX 介绍笔记本，其中涵盖：
- JAX 编程模型基础
- 与 NumPy 的关键差异
- 性能评估技术

## 步骤 7. 实现 NumPy 基线

完成基于 NumPy 的自组织映射 (SOM) 实现以建立性能基线。

完成 NumPy SOM 笔记本以：
- 了解 SOM 训练算法
- 使用熟悉的 NumPy 操作实现算法
- 记录性能指标以供比较

## 步骤 8. 使用 JAX 实现进行优化

逐步完成迭代优化的 JAX 实现以查看性能改进。

完成 JAX SOM 笔记本部分：
- NumPy 实现的基本 JAX 端口
- 性能优化的 JAX 版本
- GPU 加速的并行 JAX 实现
- 比较所有版本的性能

## 步骤 9. 验证性能提升

笔记本将向您展示如何检查每个 SOM 训练实现的性能；您将看到 JAX 实现相比 NumPy 基线显示性能提升（有些会快很多）。

视觉检查随机颜色数据的 SOM 训练输出以确认算法正确性。

## 步骤 10. 后续步骤

将 JAX 优化技术应用于您自己的基于 NumPy 的机器学习代码。

```bash
## 示例：分析您现有的 NumPy 代码
python -m cProfile your_numpy_script.py

## 然后改编为 JAX 并比较性能
```

尝试将您最喜欢的 NumPy 算法改编为 JAX，并测量在 Blackwell GPU 架构上的性能提升。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| `nvidia-smi` 未找到 | 缺少 NVIDIA 驱动程序 | 为 ARM64 安装 NVIDIA 驱动程序 |
| 容器无法访问 GPU | 缺少 NVIDIA 容器工具包 | 安装 `nvidia-container-toolkit` |
| JAX 仅使用 CPU | CUDA/JAX 版本不匹配 | 重新安装支持 CUDA 的 JAX |
| 端口 8080 不可用 | 端口已被占用 | 使用 `-p 8081:8080` 或终止 8080 上的进程 |
| Docker 构建中的包冲突 | 环境文件过时 | 更新环境文件以支持 Blackwell |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。
> 由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
