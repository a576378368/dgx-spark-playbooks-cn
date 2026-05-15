#!/bin/bash

# 检查是否安装了 mkdocs
if ! command -v mkdocs &> /dev/null; then
    echo "请先安装 MkDocs:"
    echo "  pip install mkdocs mkdocs-material"
    exit 1
fi

# 检查依赖
if [ ! -f "requirements.txt" ]; then
    echo "找不到 requirements.txt 文件"
    exit 1
fi

echo "正在启动本地服务器..."
echo "访问 http://localhost:8000 查看文档"
echo "按 Ctrl+C 停止服务器"

mkdocs serve
