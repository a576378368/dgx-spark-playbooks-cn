# TRT LLM 用于推理

> 在 DGX Spark 上安装和使用 TensorRT-LLM

## 目录

- [概述](#概述)
- [单个 Spark](#单个-spark)
- [在两个 Sparks 上运行](#在两个-sparks-上运行)
  - [步骤 1. 配置网络连接](#步骤-1-配置网络连接)
  - [步骤 2. 配置 Docker 权限](#步骤-2-配置-docker-权限)
  - [步骤 3. 创建 OpenMPI 主机文件](#步骤-3-创建-openmpi-主机文件)
  - [步骤 4. 在两个节点上启动容器](#步骤-4-在两个节点上启动容器)
  - [步骤 5. 验证容器正在运行](#步骤-5-验证容器正在运行)
  - [步骤 6. 将主机文件复制到主容器](#步骤-6-将主机文件复制到主容器)
  - [步骤 7. 保存容器参考](#步骤-7-保存容器参考)
  - [步骤 8. 生成配置文件](#步骤-8-生成配置文件)
  - [步骤 9. 下载模型](#步骤-9-下载模型)
  - [步骤 10. 提供模型服务](#步骤-10-提供模型服务)
  - [步骤 11. 验证 API 服务器](#步骤-11-验证-api-服务器)
  - [步骤 12. 清理和回滚](#步骤-12-清理和回滚)
  - [步骤 13. 下一步](#步骤-13-下一步)
- [用于 TensorRT-LLM 的 Open WebUI](#用于-tensorrt-llm-的-open-webui)
  - [步骤 1. 设置使用 Open WebUI 与 TRT-LLM 的先决条件](#步骤-1-设置使用-open-webui-与-trt-llm-的先决条件)
  - [步骤 2. 启动 Open WebUI 容器](#步骤-2-启动-open-webui-容器)
  - [步骤 3. 访问 Open WebUI 界面](#步骤-3-访问-open-webui-界面)
  - [步骤 4. 清理和回滚](#步骤-4-清理和回滚)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

**NVIDIA TensorRT-LLM (TRT-LLM)** 是一个用于在 NVIDIA GPU 上优化和加速大型语言模型（LLM）推理的开源库。

它提供了高效内核、内存管理和并行策略——如张量并行、流水线并行和序列并行——使开发人员能够以更低的延迟和更高的吞吐量提供 LLM。

TRT-LLM 与 Hugging Face 和 PyTorch 等框架集成，使大规模部署前沿模型变得更加容易。

## 你将实现的目标

你将在 DGX Spark 上设置 TensorRT-LLM 以优化和部署大型语言模型，通过内核级优化、高效内存布局和高级量化，实现比标准 PyTorch 推理显著更高的吞吐量和更低的延迟。

## 开始前须知

- Python 熟练程度及 PyTorch 或类似 ML 框架的经验
- 命令行熟练度，用于运行 CLI 工具和 Docker 容器
- GPU 概念的基本理解，包括 VRAM、批处理和量化（FP16/INT8）
- 熟悉 NVIDIA 软件栈（CUDA 工具包、驱动程序）
- 具有推理服务器和容器化环境的经验

## 先决条件

- DGX Spark 设备
- 与 CUDA 12.x 兼容的 NVIDIA 驱动程序：`nvidia-smi`
- 安装 Docker 并配置 GPU 支持：`docker run --rm --gpus all nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc13 nvidia-smi`
- 带有模型访问令牌的 Hugging Face 账户：`echo $HF_TOKEN`
- 足够的 GPU VRAM（70B 模型建议 40GB+）
- 用于下载模型和容器镜像的互联网连接
- 网络：主机上打开 TCP 端口 8355（LLM）和 8356（VLM）以支持 OpenAI 兼容服务

## 辅助文件

所有必需资产可在 [此处的 GitHub 上找到](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main)

- [**trtllm-mn-entrypoint.sh**](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/trt-llm/assets/trtllm-mn-entrypoint.sh) — 多节点设置的容器入口点脚本

## 模型支持矩阵

以下模型支持在 Spark 上使用 TensorRT-LLM。所有列出的模型均可使用：

| 模型 | 量化 | 支持状态 | HF Handle |
|------|------|----------|-----------|
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | BF16 | ✅ | `nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16` |
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | FP8 | ✅ | `nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-FP8` |
| **Nemotron-3-Nano-Omni-30B-A3B-Reasoning** | NVFP4 | ✅ | `nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4` |
| **Nemotron-3-Super-120B** | NVFP4 | ✅ | `nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4` |
| **GPT-OSS-20B** | MXFP4 | ✅ | `openai/gpt-oss-20b` |
| **GPT-OSS-120B** | MXFP4 | ✅ | `openai/gpt-oss-120b` |
| **Llama-3.1-8B-Instruct** | FP8 | ✅ | `nvidia/Llama-3.1-8B-Instruct-FP8` |
| **Llama-3.1-8B-Instruct** | NVFP4 | ✅ | `nvidia/Llama-3.1-8B-Instruct-FP4` |
| **Llama-3.3-70B-Instruct** | NVFP4 | ✅ | `nvidia/Llama-3.3-70B-Instruct-FP4` |
| **Qwen3-8B** | FP8 | ✅ | `nvidia/Qwen3-8B-FP8` |
| **Qwen3-8B** | NVFP4 | ✅ | `nvidia/Qwen3-8B-FP4` |
| **Qwen3-14B** | FP8 | ✅ | `nvidia/Qwen3-14B-FP8` |
| **Qwen3-14B** | NVFP4 | ✅ | `nvidia/Qwen3-14B-FP4` |
| **Qwen3-32B** | NVFP4 | ✅ | `nvidia/Qwen3-32B-FP4` |
| **Phi-4-multimodal-instruct** | FP8 | ✅ | `nvidia/Phi-4-multimodal-instruct-FP8` |
| **Phi-4-multimodal-instruct** | NVFP4 | ✅ | `nvidia/Phi-4-multimodal-instruct-FP4` |
| **Phi-4-reasoning-plus** | FP8 | ✅ | `nvidia/Phi-4-reasoning-plus-FP8` |
| **Phi-4-reasoning-plus** | NVFP4 | ✅ | `nvidia/Phi-4-reasoning-plus-FP4` |
| **Qwen3-30B-A3B** | NVFP4 | ✅ | `nvidia/Qwen3-30B-A3B-FP4` |
| **Llama-4-Scout-17B-16E-Instruct** | NVFP4 | ✅ | `nvidia/Llama-4-Scout-17B-16E-Instruct-FP4` |
| **Qwen3-235B-A22B (仅两个 Sparks)** | NVFP4 | ✅ | `nvidia/Qwen3-235B-A22B-FP4` |

> [!NOTE]
> 你可以使用 NVFP4 量化文档为你的最爱模型生成自己的 NVFP4 量化检查点。这使你能够享受 NVFP4 量化带来的性能和内存优势，即使对于 NVIDIA 尚未发布的模型也是如此。

提醒：并非所有模型架构都支持 NVFP4 量化。

## 时间与风险

* **持续时间**：45-60 分钟用于设置和 API 服务器部署
* **风险级别**：中等 - 由于网络问题，容器拉取和模型下载可能失败
* **回滚**：停止推理服务器并删除下载的模型以释放资源。
* **最后更新**：2026年4月28日
  * Docker 镜像 1.3.0rc13；Nemotron Omni 推理 BF16、FP8、NVFP4 在矩阵中
