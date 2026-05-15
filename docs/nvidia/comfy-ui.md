# Comfy UI

> 安装并使用 Comfy UI 进行图像生成

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

ComfyUI 是一个开源的 Web 服务器应用程序，用于使用基于扩散模型（如 SDXL、Flux 等）的 AI 进行图像生成。它具有基于浏览器的用户界面，让您能够创建、编辑和运行包含多个步骤的图像生成与编辑工作流。这些生成和编辑步骤（例如加载模型、添加文本或采样）可以在 UI 中配置为节点，并通过连线将节点连接起来形成工作流。

ComfyUI 使用主机的 GPU 进行推理，因此您可以将其安装在 NVIDIA DGX Spark 设备上，直接在您的设备上进行所有图像生成和编辑操作。

工作流以 JSON 文件格式保存，因此您可以对其进行版本控制，以便未来使用、协作和确保可重复性。

## 您将实现的目标

您将安装并配置 ComfyUI，以便利用 DGX Spark 设备上的统一内存来处理大型模型。

## 开始前须知

- 具有使用 Python 虚拟环境和包管理的经验
- 熟悉命令行操作和终端使用
- 具备深度学习模型部署和检查点的基本理解
- 了解容器工作流和 GPU 加速概念
- 掌握网络配置知识，以便访问 Web 服务

## 先决条件

**硬件要求：**
- NVIDIA Grace Blackwell GB10 Superchip 系统
- 稳定扩散模型至少需要 8GB GPU 显存
- 至少需要 20GB 可用存储空间

**软件要求：**
- 已安装 Python 3.8 或更高版本：`python3 --version`
- 可用的 pip 包管理器：`pip3 --version`
- 与 Blackwell 架构兼容的 CUDA 工具包：`nvcc --version`
- Git 版本控制：`git --version`
- 网络访问权限，用于从 Hugging Face 下载模型
- Web 浏览器访问 `<SPARK_IP>:8188` 端口

## 辅助文件

所有必需的资源都可以在 [GitHub 上的 ComfyUI 仓库](https://github.com/comfyanonymous/ComfyUI) 中找到：

- `requirements.txt` - ComfyUI 安装的 Python 依赖项
- `main.py` - ComfyUI 服务器应用程序的主入口点
- `v1-5-pruned-emaonly-fp16.safetensors` - Stable Diffusion 1.5 检查点模型

## 时间与风险

* **预计时间：** 30-45 分钟（包括模型下载）
* **风险等级：** 中等
  * 模型下载较大（约 2GB），可能因网络问题而失败
  * Web 界面功能需要端口 8188 可访问
* **回滚方案：** 可删除虚拟环境以移除所有已安装的包。可从 checkpoints 目录手动删除下载的模型。
* **最后更新：** 2025年11月10日
  * 更新 ComfyUI 的 PyTorch 至 CUDA 13.0

---

## 操作说明

## 步骤 1. 验证系统先决条件

在开始安装之前，请检查您的 NVIDIA DGX Spark 设备是否满足要求。

```bash
python3 --version
pip3 --version
nvcc --version
nvidia-smi
```

预期输出应显示 Python 3.8+、可用的 pip、CUDA 工具包以及 GPU 检测。

## 步骤 2. 创建 Python 虚拟环境

您将在主机系统上安装 ComfyUI，因此应创建一个隔离环境以避免与系统包发生冲突。

```bash
python3 -m venv comfyui-env
source comfyui-env/bin/activate
```

通过检查命令提示符是否显示 `(comfyui-env)` 来验证虚拟环境是否已激活。

## 步骤 3. 安装支持 CUDA 的 PyTorch

安装支持 CUDA 13.0 的 PyTorch。

```bash
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu130
```

此安装针对 CUDA 13.0 与 Blackwell 架构 GPU 的兼容性。

## 步骤 4. 克隆 ComfyUI 仓库

从官方仓库下载 ComfyUI 源代码。

```bash
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI/
```

## 步骤 5. 安装 ComfyUI 依赖项

安装 ComfyUI 运行所需的 Python 包。

```bash
pip install -r requirements.txt
```

这将安装所有必要的依赖项，包括 Web 界面组件和模型处理库。

## 步骤 6. 下载 Stable Diffusion 检查点

导航到 checkpoints 目录并下载 Stable Diffusion 1.5 模型。

```bash
cd models/checkpoints/
wget https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors
cd ../../
```

下载大小约为 2GB，具体时间取决于您的网络速度，可能需要几分钟。

## 步骤 7. 启动 ComfyUI 服务器

启动 ComfyUI Web 服务器并启用网络访问。

```bash
python main.py --listen 0.0.0.0
```

服务器将在所有网络接口的 8188 端口上绑定，使其可以从其他设备访问。

## 步骤 8. 验证安装

检查 ComfyUI 是否正确运行并通过 Web 浏览器访问。

```bash
curl -I http://localhost:8188
```

预期输出应显示 HTTP 200 响应，表示 Web 服务器正在运行。

在 Web 浏览器中打开并导航到 `http://<SPARK_IP>:8188`，其中 `<SPARK_IP>` 是您的设备 IP 地址。

## 步骤 9. 可选 - 清理和回滚

如果您需要完全移除安装，请按照以下步骤操作：

> [!WARNING]
> 这将删除所有已安装的包和下载的模型。

```bash
deactivate
rm -rf comfyui-env/
rm -rf ComfyUI/
```

安装过程中如需回滚，请按 `Ctrl+C` 停止服务器并删除虚拟环境。

## 步骤 10. 可选 - 后续步骤

使用基本的图像生成工作流测试安装：

1. 在 `http://<SPARK_IP>:8188` 访问 Web 界面
2. 加载默认工作流（应自动显示）
3. 点击 "运行" 生成您的第一张图像
4. 在单独的终端中使用 `nvidia-smi` 监控 GPU 使用情况

根据您的硬件配置，图像生成应在 30-60 秒内完成。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| PyTorch CUDA 不可用 | CUDA 版本不正确或缺少驱动 | 验证 `nvcc --version` 是否与 cu129 匹配，重新安装 PyTorch |
| 模型下载失败 | 网络连接问题或存储空间不足 | 检查网络连接，确认可用空间超过 20GB |
| Web 界面无法访问 | 防火墙阻止了端口 8188 | 配置防火墙允许端口 8188，检查 IP 地址 |
| 手动刷新缓冲区缓存后出现 GPU 内存不足错误 | 显存不足以运行模型 | 使用更小的模型或启用 CPU 回退模式 |

> [!NOTE] 
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。 
> 由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
