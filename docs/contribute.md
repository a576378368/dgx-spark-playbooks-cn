# 贡献指南

感谢你对本项目感兴趣并希望贡献！

## 如何贡献

### 1. Fork 项目

点击页面右上角的 "Fork" 按钮，将项目 fork 到你的 GitHub 账号下。

### 2. 克隆项目

```bash
git clone https://github.com/your-username/dgx-spark-playbooks-cn.git
cd dgx-spark-playbooks-cn/translated-site
```

### 3. 创建分支

```bash
git checkout -b feature/your-feature-name
```

### 4. 修改内容

- 翻译文档：在 `docs/nvidia/` 目录中找到对应的 `.md` 文件
- 更新导航：修改 `mkdocs.yml` 中的 `nav` 部分

### 5. 预览更改

```bash
mkdocs serve
```

在浏览器中查看更改效果。

### 6. 提交更改

```bash
git add .
git commit -m "describe your changes"
git push origin feature/your-feature-name
```

### 7. 创建 Pull Request

在 GitHub 上创建 Pull Request，并描述你的更改。

## 翻译规范

- 保持专业术语的一致性
- 参考 NVIDIA 官方中文文档的术语
- 保持 Markdown 格式不变
- 不要修改代码块中的内容

## 问题反馈

如果你发现翻译错误或有改进建议，欢迎创建 Issue。
