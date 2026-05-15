#!/bin/bash

# 生成 MkDocs 导航配置

echo "正在生成 MkDocs 导航配置..."

# 创建临时文件
TEMP_FILE=$(mktemp)

# 写入导航开始
echo "  - NVIDIA:" > "$TEMP_FILE"

# 遍历所有翻译文件
for file in /home/yang/workspace/dgx-spark-playbooks-main/translated-site/docs/nvidia/*.md; do
  filename=$(basename "$file" .md)
  
  # 获取中文标题
  zh_file="/home/yang/workspace/dgx-spark-playbooks-main/translated/$filename/zh-CN.md"
  if [ -f "$zh_file" ]; then
    title=$(head -1 "$zh_file" | sed 's/# //')
  else
    # 如果没有中文文件，使用英文标题
    en_file="/home/yang/workspace/dgx-spark-playbooks-main/nvidia/$filename/README.md"
    if [ -f "$en_file" ]; then
      title=$(head -1 "$en_file" | sed 's/# //')
    else
      title="$filename"
    fi
  fi
  
  # 写入导航项
  echo "    - $title: nvidia/${filename}.md" >> "$TEMP_FILE"
done

# 读取 mkdocs.yml 的其余部分
echo "  - 项目信息:" >> "$TEMP_FILE"
echo "    - 关于: about.md" >> "$TEMP_FILE"
echo "    - 贡献指南: contribute.md" >> "$TEMP_FILE"

# 输出结果
echo "生成完成！导航配置已输出到: $TEMP_FILE"
echo "----------------------------------------"
cat "$TEMP_FILE"
