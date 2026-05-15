# DGX Spark 上的 Unsloth

> 使用 Unsloth 进行优化的微调

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

- **性能优先**：它声称可以加速训练（例如单 GPU 上快 2 倍，多 GPU 设置中高达 30 倍），并减少内存使用。
- **内核级优化**：核心计算使用自定义内核（例如使用 Triton）和手工优化的数学运算构建，以提升吞吐量和效率。
- **量化和模型格式**：支持动态量化（4 位、16 位）和 GGUF 格式以减少占用，同时旨在保持准确性。
- **广泛的模型支持**：适用于许多 LLM（LLaMA、Mistral、Qwen、DeepSeek 等），并允许训练、微调、导出到 Ollama、vLLM、GGUF、Hugging Face 等格式。
- **简化界面**：提供易于使用的笔记本和工具，使用户能够使用最少的样板代码进行模型微调。

## 你将实现的目标

你将在 NVIDIA Spark 设备上为大型语言模型设置 Unsloth 进行优化微调，
通过高效的参数高效微调方法（如 LoRA 和 QLoRA），实现高达 2 倍的训练速度提升和减少内存使用。

## 开始前须知

- 使用 pip 和虚拟环境进行 Python 包管理
- Hugging Face Transformers 库基础知识（加载模型、分词器、数据集）
- GPU 基础知识（CUDA/GPU 与 CPU、VRAM 约束、设备可用性）
- LLM 训练概念的基本理解（损失函数、检查点）
- 熟悉提示工程和基本模型交互
- 可选：LoRA/QLoRA 参数高效微调知识

## 先决条件

- 带有 Blackwell GPU 架构的 NVIDIA Spark 设备
- `nvidia-smi` 显示 GPU 信息摘要
- 已安装 CUDA 13.0：`nvcc --version`
- 用于下载模型和数据集的互联网访问

## 辅助文件

Python 测试脚本可在 [此处的 GitHub 上找到](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/unsloth/assets/test_unsloth.py)

## 时间与风险

* **持续时间**：30-60 分钟用于初始设置和测试运行
* **风险**：
  * Triton 编译器版本不匹配可能导致编译错误
  * CUDA 工具包配置问题可能阻止内核编译
  * 较小模型的内存约束需要调整批量大小
* **回滚**：使用 `pip uninstall unsloth torch torchvision` 卸载包。
* **最后更新**：2025年12月15日
  * 将 pytorch 容器和 python 依赖项升级到最新版本

---

## 操作说明

## 步骤 1. 验证先决条件

确认你的 NVIDIA Spark 设备具有所需的 CUDA 工具包和 GPU 资源。

```bash
nvcc --version
```
输出应显示 CUDA 13.0。

```bash
nvidia-smi
```
输出应显示 GPU 信息摘要。

## 步骤 2. 获取容器镜像
```bash
docker pull nvcr.io/nvidia/pytorch:25.11-py3
```

## 步骤 3. 启动 Docker
```bash
docker run --gpus all --ulimit memlock=-1 -it --ulimit stack=67108864 --entrypoint /usr/bin/bash --rm nvcr.io/nvidia/pytorch:25.11-py3
```

## 步骤 4. 在 Docker 中安装依赖项

```bash
pip install transformers peft hf_transfer "datasets==4.3.0" "trl==0.26.1"
pip install --no-deps unsloth unsloth_zoo bitsandbytes
```

## 步骤 5. 创建 Python 测试脚本

将测试脚本 [此处](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/unsloth/assets/test_unsloth.py) 拉入容器。

```bash
curl -O https://raw.githubusercontent.com/NVIDIA/dgx-spark-playbooks/refs/heads/main/nvidia/unsloth/assets/test_unsloth.py
```

我们将使用此测试脚本通过简单的微调任务验证安装。

## 步骤 6. 运行验证测试

执行测试脚本以验证 Unsloth 是否正常工作。

```bash
python test_unsloth.py
```

终端窗口中的预期输出：
- "Unsloth: Will patch your computer to enable 2x faster free finetuning"（Unsloth：将修补您的计算机以启用 2 倍更快的免费微调）
- 显示损失随 60 步减少的训练进度条
- 显示完成的最终训练指标

## 步骤 7. 下一步

通过更新 `test_unsloth.py` 文件，使用你自己的模型和数据集进行测试：

```python
## 将第 32 行替换为你的模型选择
model_name = "unsloth/Meta-Llama-3.1-8B-bnb-4bit"

## 在第 8 行加载你的自定义数据集
dataset = load_dataset("your_dataset_name")

## 在第 61 行调整训练参数 args
per_device_train_batch_size = 4
max_steps = 1000
```

访问 https://github.com/unslothai/unsloth/wiki
获取高级使用说明，包括：
- [保存为 GGUF 格式以用于 vLLM](https://github.com/unslothai/unsloth Wiki#saving-to-gguf)
- [从检查点继续训练](https://github.com/unslothai/unsloth Wiki#loading-lora-adapters-for-continued-finetuning)
- [使用自定义聊天模板](https://github.com/unslothai/unsloth Wiki#chat-templates)
- [运行评估循环](https://github.com/unslothai/unsloth Wiki#evaluation-loop---also-fixes-oom-or-crashing)

---

## 故障排除

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的动态共享。
> 随着许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，你也可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
