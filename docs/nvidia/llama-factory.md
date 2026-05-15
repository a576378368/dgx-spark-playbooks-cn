# LLaMA Factory

> 使用 LLaMA Factory 安装和微调模型

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念
LLaMA Factory 是一个开源框架，简化了训练和微调大型语言模型的过程。它为各种前沿方法（如 SFT、RLHF 和 QLoRA 技术）提供了统一的接口。它还支持广泛的 LLM 架构，如 LLaMA、Mistral 和 Qwen。本操作指南演示了如何在 NVIDIA Spark 设备上使用 LLaMA Factory CLI 微调大型语言模型。

## 您将实现的目标

您将在 NVIDIA Spark 上使用 Blackwell 架构设置 LLaMA Factory，以使用 LoRA、QLoRA 和全微调方法微调大型语言模型。这使得能够高效地进行模型适应以适应专业领域，同时利用硬件特定的优化。

## 开始前须知

- 基本的 Python 知识用于编辑配置文件和故障排除
- 命令行使用用于运行 shell 命令和管理环境
- 熟悉 PyTorch 和 Hugging Face Transformers 生态系统
- GPU 环境设置，包括 CUDA/cuDNN 安装和 VRAM 管理
- 微调概念：了解 LoRA、QLoRA 和全微调之间的权衡
- 数据集准备：将文本数据格式化为 JSON 结构以进行指令调整
- 资源管理：调整批大小和内存设置以适应 GPU 约束

## 先决条件

- NVIDIA Spark 设备，具有 Blackwell 架构

- 已安装 CUDA 12.9 或更高版本：`nvcc --version`

- 已安装 Git：`git --version`

- Python 3，带有 venv 和 pip：`python3 --version && pip3 --version`

- 足够的存储空间（>50GB 用于模型和检查点）：`df -h`

- 用于从 Hugging Face Hub 下载模型的互联网连接

## 辅助文件

- 官方 LLaMA Factory 存储库：https://github.com/hiyouga/LLaMA-Factory

- 带有 CUDA 13 的 PyTorch：通过 `pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130` 安装

- 示例训练配置：`examples/train_lora/qwen3_lora_sft.yaml`（来自存储库）

- 文档：https://llamafactory.readthedocs.io/en/latest/getting_started/data_preparation.html

## 时间与风险

* **持续时间：** 初始设置需要 30-60 分钟，根据模型大小和数据集，训练需要 1-7 小时。
* **风险：** 模型下载需要大量带宽和存储。训练可能消耗大量 GPU 内存，需要调整参数以适应硬件约束。
* **回滚方案：** 停用虚拟环境并删除 `factoryEnv` 和 `LLaMA-Factory` 目录。训练检查点保存在本地，可以删除以回收存储空间。
* **最后更新：** 2026年2月18日
  * 更新为基于 venv 的设置，使用 PyTorch CUDA 13（无 Docker）。Qwen3 LoRA 微调工作流。

---

## 操作说明

## 步骤 1. 验证系统先决条件

检查您的 NVIDIA Spark 系统是否安装并可以访问所需组件。

```bash
nvcc --version
nvidia-smi
python3 --version
git --version
```

## 步骤 2. 创建并激活 Python 虚拟环境

创建虚拟环境并激活它用于 LLaMA Factory 安装。

```bash
python3 -m venv factoryEnv
source ./factoryEnv/bin/activate
```

## 步骤 3. 安装支持 CUDA 13 的 PyTorch

从官方 PyTorch 索引安装支持 CUDA 13.0 的 PyTorch、torchvision 和 torchaudio。

```bash
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130
```

## 步骤 4. 验证 PyTorch CUDA 支持

确认 PyTorch 可以看到 GPU。

```bash
python -c "import torch; print(f'PyTorch: {torch.__version__}, CUDA: {torch.cuda.is_available()}')"
```

## 步骤 5. 克隆 LLaMA Factory 存储库

从官方存储库下载 LLaMA Factory 源代码。

```bash
git clone --depth 1 https://github.com/hiyouga/LLaMA-Factory.git
cd LLaMA-Factory
```

## 步骤 6. 安装 LLaMA Factory 及其依赖项

以可编辑模式安装 LLaMA Factory 并启用指标支持。

```bash
pip install -e ".[metrics]"
```

## 步骤 7. 准备训练配置

检查提供的用于 Qwen3 的 LoRA 微调配置。

```bash
cat examples/train_lora/qwen3_lora_sft.yaml
```

## 步骤 8. 启动微调训练

> [!NOTE]
> 如果模型是闭源的，请登录您的 Hugging Face Hub 以下载模型。

使用预配置的 LoRA 设置执行训练过程。

```bash
hf auth login   # 如果模型是闭源的
llamafactory-cli train examples/train_lora/qwen3_lora_sft.yaml
```

示例输出：
```
***** train metrics *****
  epoch                    =        3.0
  total_flos               = 11076559GF
  train_loss               =     0.9993
  train_runtime            = 0:14:32.12
  train_samples_perSecond =      3.749
  train_steps_per_second   =      0.471
Figure saved at: saves/qwen3-4b/lora/sft/training_loss.png
```

## 步骤 9. 验证训练完成

验证训练是否成功完成并保存了检查点。

```bash
ls -la saves/qwen3-4b/lora/sft/
```

预期输出应显示：
- 最终检查点目录（`checkpoint-411` 或类似）
- 模型配置文件（`adapter_config.json`）
- 训练指标显示损失值递减
- 训练损失图保存为 PNG 文件

## 步骤 10. 使用微调模型测试推理

使用自定义提示测试您的微调模型：

```bash
llamafactory-cli chat examples/inference/qwen3_lora_sft.yaml
## 输入："Hello, how can you help me today?"
## 预期：显示微调行为的响应
```

## 步骤 11. 对于生产部署，导出您的模型

```bash
llamafactory-cli export examples/merge_lora/qwen3_lora_sft.yaml
```

## 步骤 12. 清理和回滚

> [!WARNING]
> 这将删除所有训练进度和检查点。

要删除虚拟环境和克隆的存储库：

```bash
deactivate
cd ..
rm -rf LLaMA-Factory/
rm -rf factoryEnv/
```

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 训练期间 CUDA 内存不足 | 批大小对于 GPU VRAM 太大 | 减少 `per_device_train_batch_size` 或增加 `gradient_accumulation_steps` |
| 无法访问 URL 的闭源仓库 | 某些 HuggingFace 模型有访问限制 | 重新生成您的 [HuggingFace 令牌](https://huggingface.co/docs/hub/en/security-tokens)；并在您的 Web 浏览器上请求访问[闭源模型](https://huggingface.co/docs/hub/en/models-gated#customize-requested-information) |
| 模型下载失败或缓慢 | 网络连接或 Hugging Face Hub 问题 | 检查互联网连接，尝试使用 `HF_HUB_OFFLINE=1` 进行缓存模型 |
| 训练损失不下降 | 学习率过高/过低或数据不足 | 调整 `learning_rate` 参数或检查数据集质量 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），可实现 GPU 和 CPU 之间的动态内存共享。
> 由于许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量范围内，您仍可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
