# 多模态推理

> 使用 TensorRT 设置多模态推理

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

多模态推理将不同类型的数据（如**文本、图像和音频**）组合到单个模型管道中，以生成或解释更丰富的输出。
多模态系统具有共享表示，而不是一次处理一种输入类型，这可以实现**文本到图像生成**、**图像描述**或**视觉语言推理**。

在 GPU 上，这使得**跨模态并行处理**成为可能，从而更快、更保真地完成结合语言和视觉的任务。

## 您将实现的目标

您将使用 TensorRT 在 NVIDIA Spark 上部署 GPU 加速的多模态推理能力，
以优化性能跨多种精度格式（FP16、FP8、FP4）运行 Flux.1 和 SDXL 扩散模型。

## 开始前须知

- 使用 Docker 容器和 GPU 直通
- 使用 TensorRT 进行模型优化
- Hugging Face 模型中心认证和下载
- GPU 工作负载的命令行工具
- 基本了解扩散模型和图像生成

## 先决条件

- 具有 Blackwell GPU 架构的 NVIDIA Spark 设备
- 已安装 Docker 并且当前用户可访问
- 已配置 NVIDIA Container Runtime
- 具有 Hugging Face 账户，可访问 Black Forest Labs 模型 [FLUX.1-dev](https://huggingface.co/black-forest-labs/FLUX.1-dev) 和 [FLUX.1-dev-onnx](https://huggingface.co/black-forest-labs/FLUX.1-dev-onnx)
- 具有访问两个 FLUX.1 模型存储库的 Hugging Face [令牌](https://huggingface.co/settings/tokens)
- 至少 48GB VRAM 可用于 FP16 Flux.1 Schnell 操作
- 验证 GPU 访问：`nvidia-smi`
- 检查 Docker GPU 集成：`docker run --rm --gpus all nvcr.io/nvidia/pytorch:25.11-py3 nvidia-smi`

## 辅助文件

所有必要文件可以在 TensorRT 存储库 [GitHub 上找到](https://github.com/NVIDIA/TensorRT)
- [**requirements.txt**](https://github.com/NVIDIA/TensorRT/blob/main/demo/Diffusion/requirements.txt) - TensorRT 演示环境的 Python 依赖项
- [**demo_txt2img_flux.py**](https://github.com/NVIDIA/TensorRT/blob/main/demo/Diffusion/demo_txt2img_flux.py) - Flux.1 模型推理脚本
- [**demo_txt2img_xl.py**](https://github.com/NVIDIA/TensorRT/blob/main/demo/Diffusion/demo_txt2img_xl.py) - SDXL 模型推理脚本
- **TensorRT 存储库** - 包含扩散演示代码和优化工具

## 时间与风险

- **持续时间**：45-90 分钟，具体取决于模型下载和优化步骤

- **风险**：
  - 大型模型下载可能超时
  - 高 VRAM 要求可能导致 OOM 错误
  - 量化模型可能显示质量下降

- **回滚方案**：
  - 从 HuggingFace 缓存中删除下载的模型
  - 然后退出容器环境

* **最后更新：** 2025年12月22日
  * 升级到最新的 pytorch 容器版本 nvcr.io/nvidia/pytorch:25.11-py3
  * 添加 HuggingFace 令牌设置说明以访问模型
  * 添加 Docker 容器权限设置说明

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

## 步骤 2. 启动 TensorRT 容器环境

启动具有 GPU 访问权限和 HuggingFace 缓存挂载的 NVIDIA PyTorch 容器。这提供了带有所有必需依赖项预安装的 TensorRT 开发环境。

```bash
docker run --gpus all --ipc=host --ulimit memlock=-1 \
--ulimit stack=67108864 -it --rm --ipc=host \
-v $HOME/.cache/huggingface:/root/.cache/huggingface \
nvcr.io/nvidia/pytorch:25.11-py3
```

## 步骤 3. 克隆并设置 TensorRT 存储库

下载 TensorRT 存储库并为扩散模型演示配置环境。

```bash
git clone https://github.com/NVIDIA/TensorRT.git -b main --single-branch && cd TensorRT
export TRT_OSSPATH=/workspace/TensorRT/
cd $TRT_OSSPATH/demo/Diffusion
```

## 步骤 4. 安装所需依赖项

安装 NVIDIA ModelOpt 和其他依赖项用于模型量化和优化。

```bash
## 安装 OpenGL 库
apt update
apt install -y libgl1 libglu1-mesa libglib2.0-0t64 libxrender1 libxext6 libx11-6 libxrandr2 libxss1 libxcomposite1 libxdamage1 libxfixes3 libxcb1

pip install nvidia-modelopt[torch,onnx]
sed -i '/^nvidia-modelopt\[.*\]=.*/d' requirements.txt
pip3 install -r requirements.txt
pip install onnxconverter_common
```

设置您的 HuggingFace 令牌以访问开放模型。
```bash
export HF_TOKEN = <YOUR_HUGGING_FACE_TOKEN>
```

## 步骤 5. 运行 Flux.1 Dev 模型推理

使用不同的精度格式测试 Flux.1 Dev 模型的多模态推理。

**子步骤 A. BF16 量化精度**

```bash
python3 demo_txt2img_flux.py "a beautiful photograph of Mt. Fuji during cherry blossom" \
  --hf-token=$HF_TOKEN --download-onnx-models --bf16
```

**子步骤 B. FP8 量化精度**

```bash
python3 demo_txt2img_flux.py "a beautiful photograph of Mt. Fuji during cherry blossom" \
  --hf-token=$HF_TOKEN --quantization-level 4 --fp8 --download-onnx-models
```

**子步骤 C. FP4 量化精度**

```bash
python3 demo_txt2img_flux.py "a beautiful photograph of Mt. Fuji during cherry blossom" \
  --hf-token=$HF_TOKEN --fp4 --download-onnx-models
```

## 步骤 6. 运行 Flux.1 Schnell 模型推理

使用不同的精度格式测试更快的 Flux.1 Schnell 变体。

> [!WARNING]
> FP16 Flux.1 Schnell 需要 >48GB VRAM 用于原生导出

**子步骤 A. FP16 精度（高 VRAM 要求）**

```bash
python3 demo_txt2img_flux.py "a beautiful photograph of Mt. Fuji during cherry blossom" \
  --hf-token=$HF_TOKEN --version="flux.1-schnell"
```

**子步骤 B. FP8 量化精度**

```bash
python3 demo_txt2img_flux.py "a beautiful photograph of Mt. Fuji during cherry blossom" \
  --hf-token=$HF_TOKEN --version="flux.1-schnell" \
  --quantization-level 4 --fp8 --download-onnx-models
```

**子步骤 C. FP4 量化精度**

```bash
python3 demo_txt2img_flux.py "a beautiful photograph of Mt. Fuji during cherry blossom" \
  --hf-token=$HF_TOKEN --version="flux.1-schnell" \
  --fp4 --download-onnx-models
```

## 步骤 7. 运行 SDXL 模型推理

测试 SDXL 模型以进行不同精度格式的比较。

**子步骤 A. BF16 精度**

```bash
python3 demo_txt2img_xl.py "a beautiful photograph of Mt. Fuji during cherry blossom" \
  --hf-token=$HF_TOKEN --version xl-1.0 --download-onnx-models
```

**子步骤 B. FP8 量化精度**

```bash
python3 demo_txt2img_xl.py "a beautiful photograph of Mt. Fuji during cherry blossom" \
  --hf-token=$HF_TOKEN --version xl-1.0 --download-onnx-models --fp8
```

## 步骤 8. 验证推理输出

检查模型是否成功生成图像并测量性能差异。

```bash
## 检查输出目录中生成的图像
ls -la *.png *.jpg 2>/dev/null || echo "No image files found"

## 验证 CUDA 可访问性
nvidia-smi

## 检查 TensorRT 版本
python3 -c "import tensorrt as trt; print(f'TensorRT version: {trt.__version__}')"
```

## 步骤 9. 清理和回滚

删除下载的模型并退出容器环境以释放磁盘空间。

> [!WARNING]
> 这将删除所有缓存的模型和生成的图像

```bash
## 退出容器
exit

## 删除 HuggingFace 缓存（可选）
rm -rf $HOME/.cache/huggingface/
```

## 步骤 10. 后续步骤

使用验证的设置生成自定义图像或将多模态推理集成到您的应用程序中。
尝试不同的提示或使用建立的 TensorRT 环境探索模型微调。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| "CUDA out of memory" 错误 | VRAM 不足以用于模型 | 使用 FP8/FP4 量化或更小的模型 |
| "Invalid HF token" 错误 | 缺少或过期的 HuggingFace 令牌 | 设置有效令牌：`export HF_TOKEN=<YOUR_TOKEN>` |
| 无法访问 URL 的闭源仓库 | 某些 HuggingFace 模型有访问限制 | 重新生成您的 [HuggingFace 令牌](https://huggingface.co/docs/hub/en/security-tokens)；并在您的 Web 浏览器上请求访问[闭源模型](https://huggingface.co/docs/hub/en/models-gated#customize-requested-information) |
| 模型下载超时 | 网络问题或速率限制 | 重试命令或预先下载模型 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。
> 由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
