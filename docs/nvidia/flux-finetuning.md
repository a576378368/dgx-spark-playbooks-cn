# FLUX.1 Dreambooth LoRA 微调

> 使用 Dreambooth LoRA 对 FLUX.1-dev 12B 模型进行微调，实现自定义图像生成

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

本指南演示如何在 DGX Spark 上使用多概念 Dreambooth LoRA（低秩自适应）对 FLUX.1-dev 12B 模型进行微调，以实现自定义图像生成。
DGX Spark 配备 128GB 统一内存和强大的 GPU 加速，为训练图像生成模型提供了理想环境，可将多个模型同时加载到内存中，例如扩散Transformer、CLIP 文本编码器、T5 文本编码器和自编码器。

多概念 Dreambooth LoRA 微调允许您教导 FLUX.1 新的概念、角色和风格。训练后的 LoRA 权重可以轻松集成到现有的 ComfyUI 工作流中，非常适合原型设计和实验。
此外，本指南还演示了 DGX Spark 不仅可以将多个模型加载到内存中，还可以训练和生成高分辨率图像，例如 1024px 及更高。

## 您将实现的目标

您将拥有一款经过微调的 FLUX.1 模型，能够生成带有自定义概念的图像，随时可用于 ComfyUI 工作流。
设置包括：
- 使用 Dreambooth LoRA 技术对 FLUX.1-dev 模型进行微调
- 在自定义概念（"tjtoy" 玩具和 "sparkgpu" GPU）上进行训练
- 高分辨率 1K 扩散训练和推理
- ComfyUI 集成，用于直观的视觉工作流
- Docker 容器化，确保环境可重复性

## 先决条件

- DGX Spark 设备已设置且可访问
- DGX Spark GPU 上没有其他进程在运行
- 有足够的磁盘空间用于模型下载
- 已安装并配置 NVIDIA Docker

## 时间与风险

* **持续时间**：
  * 30-45 分钟用于初始设置和模型下载时间
  * 1-2 小时用于 dreambooth LoRA 训练
* **风险**：
  * Docker 权限问题可能需要更改用户组并重启会话
  * 该配方需要超参数调整和高质量数据集以获得最佳效果
* **回滚方案**：停止并删除 Docker 容器，如有需要可删除下载的模型。
* **最后更新：** 2025年11月7日
  * 少量文字编辑

---

## 操作说明

## 步骤 1. 配置 Docker 权限

为了无需 sudo 即可轻松管理容器，您必须在 `docker` 组中。如果选择跳过此步骤，则需要使用 sudo 运行 Docker 命令。

打开一个新终端并测试 Docker 访问。在终端中，运行：

```bash
docker ps
```

如果您看到权限被拒绝错误（类似"在尝试连接到 Docker 守护进程套接字时权限被拒绝"），将您的用户添加到 docker 组，这样就不需要使用 sudo 运行命令。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## 步骤 2. 克隆存储库

在终端中，克隆存储库并导航到 flux-finetuning 目录。

```bash
git clone https://github.com/NVIDIA/dgx-spark-playbooks
```

## 步骤 3. 模型下载

由于 FLUX.1-dev 模型受保护，您需要获得访问权限。前往其[模型卡片](https://huggingface.co/black-forest-labs/FLUX.1-dev)接受条款并获得检查点的访问权限。
如果您还没有 `HF_TOKEN`，请按照[此处](https://huggingface.co/docs/hub/en/security-tokens)的说明生成一个。通过在以下命令中替换您生成的令牌来验证您的系统。

```bash
export HF_TOKEN=<YOUR_HF_TOKEN>
cd dgx-spark-playbooks/nvidia/flux-finetuning/assets
sh download.sh
```
下载脚本根据您的网速可能需要大约 30-45 分钟完成。

如果您已经有微调的 LoRAs，请将它们放在 `models/loras` 中。如果您还没有，请继续 `步骤 6. 训练` 部分了解详细信息。

## 步骤 4. 基础模型推理

让我们首先使用基础 FLUX.1 模型生成我们感兴趣的两个概念（Toy Jensen 和 DGX Spark）的图像。

```bash
## 构建推理 docker 镜像
docker build -f Dockerfile.inference -t flux-comfyui .

## 启动 ComfyUI 容器（确保您在 flux-finetuning/assets 内）
## 您可以忽略 `torchaudio` 的任何导入错误
sh launch_comfyui.sh
```
在 `http://localhost:8188` 访问 ComfyUI，使用基础模型生成图像。不要选择任何预设模板。

在 ComfyUI 左侧面板中找到工作流部分（或按 `w`）。打开后，您应该会发现两个已加载的工作流。对于基础 Flux 模型，让我们加载 `base_flux.json` 工作流。加载 json 后，您应该看到 ComfyUI 加载了工作流。

在 `CLIP 文本编码器（提示）`块中提供您的提示。例如，我们将使用 `Toy Jensen holding a DGX Spark in a datacenter`（Toy Jensen 在数据中心拿着一个 DGX Spark）。由于创建高分辨率 1024px 图像计算量很大，您可以期待生成需要大约 3 分钟。

使用基础模型进行一些实验后，您有两种可能的后续步骤。
* 如果您已经在 `models/loras/` 中放置了微调的 LoRAs，请跳到 `步骤 7. 微调模型推理` 部分。
* 如果您希望为您的自定义概念训练 LoRA，请首先确保在继续训练之前关闭 ComfyUI 推理容器。您可以通过使用 `Ctrl+C` 键中断终端来关闭它。

> [!NOTE]
> 要清除系统中占用的任何额外内存，请在中断 ComfyUI 服务器后在容器外执行以下命令。
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

## 步骤 5. 数据集准备

让我们准备数据集，对 FLUX.1-dev 12B 模型执行 Dreambooth LoRA 微调。

对于本指南，我们已经准备好了两个概念的数据集 - Toy Jensen 和 DGX Spark。此数据集是可通过 Google 图像访问的公共资产集合。如果您想使用这些概念生成图像，则不需要修改 `data.toml` 文件。

**TJToy 概念**
- **触发短语**：`tjtoy toy`
- **训练图像**：6 张高质量的 Toy Jensen 人物图像，可在公共领域获取
- **用例**：生成包含特定玩具角色的各种场景图像

**SparkGPU 概念**
- **触发短语**：`sparkgpu gpu`
- **训练图像**：7 张可在公共领域获取的 DGX Spark GPU 图像
- **用例**：在不同上下文中生成包含特定 GPU 设计的图像

如果您希望使用自定义概念生成图像，则需要准备所有您想要生成的概念的数据集，每个概念大约 5-10 张图像。

为每个概念创建一个以其对应名称命名的文件夹，并将其放在 `flux_data` 目录内。在本例中，我们使用了 `sparkgpu` 和 `tjtoy` 作为我们的概念，并在每个概念中放置了几张图像。

现在，让我们修改 `flux_data/data.toml` 文件以反映所选的概念。确保通过修改 `[[datasets.subsets]]` 下的 `image_dir` 和 `class_tokens` 字段来更新/创建每个概念的条目。为了更好地微调性能，建议在概念名称后附加类标记（如 `toy` 或 `gpu`）。

## 步骤 6. 训练

通过执行以下命令启动训练。训练脚本使用默认配置，在大约 90 分钟的训练后生成有效捕获您 DreamBooth 概念的图像。此 train 命令将自动将检查点存储在 `models/loras/` 目录中。

```bash
## 构建推理 docker 镜像
docker build -f Dockerfile.train -t flux-train .

## 触发训练
sh launch_train.sh
```

## 步骤 7. 微调模型推理

现在让我们使用我们的微调 LoRAs 生成图像！

```bash
## 启动 ComfyUI 容器（确保您在 flux-finetuning/assets 内）
## 您可以忽略 `torchaudio` 的任何导入错误
sh launch_comfyui.sh
```
在 `http://localhost:8188` 访问 ComfyUI，使用微调模型生成图像。不要选择任何预设模板。

在 ComfyUI 左侧面板中找到工作流部分（或按 `w`）。打开后，您应该会发现两个已加载的工作流。对于微调 Flux 模型，让我们加载 `finetuned_flux.json` 工作流。加载 json 后，您应该看到 ComfyUI 加载了工作流。

在 `CLIP 文本编码器（提示）`块中提供您的提示。现在让我们将我们的自定义概念融入到微调模型的提示中。例如，我们将使用 `tjtoy toy holding sparkgpu gpu in a datacenter`（tjtoy 玩具在数据中心拿着 sparkgpu GPU）。由于创建高分辨率 1024px 图像计算量很大，您可以期待生成需要大约 3 分钟。

与基础模型不同，我们可以看到微调模型可以在单张图像中生成多个概念。此外，ComfyUI 暴露了多个字段来调整和更改生成图像的外观。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 无法访问 URL 的闭源仓库 | 某些 HuggingFace 模型有访问限制 | 重新生成您的 [HuggingFace 令牌](https://huggingface.co/docs/hub/en/security-tokens)；并在您的 Web 浏览器上请求访问[闭源模型](https://huggingface.co/docs/hub/en/models-gated#customize-requested-information) |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。
> 由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
