# DGX Spark Playbooks 中文版

NVIDIA DGX Spark 中文使用指南

## 📖 关于

本项目是 [DGX Spark Playbooks](https://github.com/NVIDIA/dgx-spark-playbooks) 的中文翻译版本，提供详细的中文文档来帮助用户设置和使用 DGX Spark 设备。

## 🚀 快速开始

### 前提条件

- Python 3.8+
- pip 包管理器

### 安装依赖

```bash
cd translated-site
pip install -r requirements.txt
```

### 本地预览

```bash
mkdocs serve
```

然后在浏览器中访问 http://localhost:8000

### 构建静态站点

```bash
mkdocs build
```

构建后的文件将在 `site/` 目录中。

## 📁 项目结构

```
translated-site/
├── docs/               # 文档源文件
│   ├── index.md       # 首页
│   ├── about.md       # 关于页面
│   ├── contribute.md  # 贡献指南
│   └── nvidia/        # NVIDIA相关文档（翻译版）
├── images/            # 图片资源
├── mkdocs.yml         # MkDocs 配置文件
├── requirements.txt   # Python 依赖
└── README.md          # 本文件
```

## 🤝 贡献

欢迎贡献！请查看 [贡献指南](docs/contribute.md) 了解详情。

## 📄 许可证

本项目遵循与原始项目相同的许可证。详情请参阅 [LICENSE](../LICENSE) 文件。

## 💖 致谢

- 原始项目: [NVIDIA/dgx-spark-playbooks](https://github.com/NVIDIA/dgx-spark-playbooks)
- 文档框架: [MkDocs Material](https://squidfunk.github.io/mkdocs-material/)

## 🌐 在线访问

访问我们的 GitHub Pages 页面：[https://yangfeng.github.io/dgx-spark-playbooks-cn](https://yangfeng.github.io/dgx-spark-playbooks-cn)

---

**注意**: 本翻译版力求准确，但如有任何歧义，请以英文原版为准。
