# DGX Spark Playbooks 中文版 - 翻译说明

## 翻译文件结构

```
translated-site/
├── docs/nvidia/           # 翻译后的文档
│   ├── comfy-ui.md
│   ├── connect-three-sparks.md
│   └── ...
├── mkdocs.yml             # MkDocs 配置
└── requirements.txt       # Python 依赖
```

## 已翻译的文档

目前已翻译以下文档（共 24 个）：

- Comfy UI
- 连接三个 DGX Spark
- 设置本地网络访问
- 连接两个 Spark
- CUDA-X 数据科学
- DGX Dashboard
- FLUX.1 Dreambooth LoRA 微调
- Isaac Sim 和 Isaac Lab
- 优化 JAX
- Live VLM WebUI
- llama.cpp
- LLaMA Factory
- LM Studio
- 多智能体聊天机器人
- 多模态推理
- 通过交换机连接多个 DGX Spark
- NCCL
- NemoClaw
- NeMo 微调
- Nemotron
- NIM
- NVFP4 量化
- Ollama
- **OpenClaw** 🦞

## 未翻译的文档

以下文档暂未翻译（共 17 个）：

- OpenShell
- Open WebUI
- 投资组合优化
- PyTorch 微调
- RAG 应用
- SGLang
- 单细胞 RNA 测序
- Spark & Reachy 照片亭
- 推测性解码
- Tailscale
- TRT-LLM
- 文本到知识图谱
- Unsloth
- VS Code
- Vibe Coding
- vLLM
- VSS 代理

## 如何添加新的翻译

1. 在 `translated/` 目录中找到对应的文件夹
2. 确保有 `zh-CN.md` 文件
3. 运行 `generate-nav.sh` 重新生成导航配置
4. 提交更改

## 构建和部署

### 本地构建

```bash
mkdocs build
```

### GitHub Pages 部署

本项目配置为通过 GitHub Actions 自动部署到 GitHub Pages。

## 许可证

- 原始内容 © NVIDIA Corporation
- 中文翻译 © 2026 YangFeng

本翻译版在原始内容的基础上进行翻译和本地化。
