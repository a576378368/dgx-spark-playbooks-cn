# DGX Spark Playbooks 中文版 - GitHub Pages 部署指南

## 项目概述

本项目使用 MkDocs Material 构建文档网站，并部署到 GitHub Pages。

## 本地开发

### 安装依赖

```bash
cd translated-site
pip install -r requirements.txt
```

### 本地预览

```bash
mkdocs serve
```

访问 http://localhost:8000 查看实时预览。

## 构建静态站点

```bash
mkdocs build
```

构建后的文件将输出到 `site/` 目录。

## GitHub Pages 部署

### 手动部署

1. 构建站点：
   ```bash
   mkdocs build
   ```

2. 将 `site/` 目录推送到 `gh-pages` 分支：
   ```bash
   git checkout -b gh-pages
   git add site/
   git commit -m "Build site"
   git push origin gh-pages
   ```

### 自动部署（推荐）

可以使用 GitHub Actions 自动部署。创建 `.github/workflows/deploy.yml`：

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches:
      - main
    paths:
      - 'translated-site/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.x'
          
      - name: Install dependencies
        run: |
          cd translated-site
          pip install -r requirements.txt
          
      - name: Build site
        run: |
          cd translated-site
          mkdocs build
          
      - name: Deploy
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./translated-site/site
```

## 配置说明

### mkdocs.yml 配置

- `site_name`: 站点名称
- `site_url`: GitHub Pages URL
- `repo_url`: 项目仓库地址
- `edit_uri`: 编辑链接

### 主题配置

- `theme.name`: 使用 Material 主题
- `theme.language`: 设置为中文
- `theme.palette`: 支持亮色和暗色主题

## 自定义域名

如果需要使用自定义域名：

1. 在仓库设置中添加自定义域名
2. 在 `translated-site/docs/` 目录下创建 `CNAME` 文件：
   ```
   your-domain.com
   ```

## 注意事项

- 确保 `mkdocs.yml` 中的 `repo_url` 和 `site_url` 正确配置
- 构建前确保所有依赖已安装
- 首次部署需要启用 GitHub Pages（设置 > Pages > Build and deployment）
