# DGX Spark 上的文本到知识图谱

> 使用 LLM 推理和图形可视化将非结构化文本转换为交互式知识图谱

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

本 playbook 演示了如何构建和部署一个全面的知识图谱生成和可视化解决方案，作为知识图谱提取的参考。
统一内存架构使你可以运行更大、更准确的模型，生成更高质量的知识图谱，并提供卓越的下游 GraphRAG 性能。

此 txt2kg playbook 使用以下技术将非结构化文本文档转换为结构化知识图谱：
- **知识三元组提取**：使用带有 GPU 加速的 Ollama 进行本地 LLM 推理，提取主语-谓语-宾语关系
- **图数据库存储**：ArangoDB 用于存储和查询知识三元组及关系遍历
- **GPU 加速可视化**：Three.js WebGPU 渲染用于交互式 2D/3D 图探索

> **未来增强功能**：计划增强功能包括向量嵌入和 GraphRAG 功能。

## 你将实现的目标

你将拥有一个功能齐全的系统，能够处理文档、生成和编辑知识图谱，并提供查询功能，可通过交互式 Web 界面访问。
设置包括：
- **本地 LLM 推理**：Ollama 用于 GPU 加速的 LLM 推理，无需 API 密钥
- **图数据库**：ArangoDB 用于存储和查询三元组及关系遍历
- **交互式可视化**：GPU 加速的图渲染，使用 Three.js WebGPU
- **现代 Web 界面**：Next.js 前端，具有文档管理和查询界面
- **完全容器化**：使用 Docker Compose 和 GPU 支持的可重现部署

## 先决条件

- 带有最新 NVIDIA 驱动程序的 DGX Spark
- 已安装并配置 NVIDIA Container Toolkit 的 Docker
- Docker Compose

## 时间与风险

- **持续时间**：
  - 2-3 分钟用于初始设置和容器部署
  - 5-10 分钟用于 Ollama 模型下载（取决于模型大小）
  - 立即进行文档处理和知识图谱生成

- **风险**：
  - GPU 内存要求取决于所选 Ollama 模型大小
  - 文档处理时间随文档大小和复杂性而扩展

- **回滚**：停止并删除 Docker 容器，必要时删除下载的模型
- **最后更新**：2025年1月8日
  - 从 Pinecone 迁移到 Qdrant 以实现 ARM64 兼容性
  - 添加带有 Neo4j 的 vLLM 支持
  - 添加带有可访问性改进的 Palette UI 组件
  - 添加用于开发的 CPU 仅模式 (`./start.sh --cpu`)
  - 使用确定性键和 BM25 搜索优化 ArangoDB
  - 添加用于知识图谱训练的 GNN 预处理脚本

---

## 操作说明

## 步骤 1. 克隆仓库

在终端中，克隆 txt2kg 仓库并导航到项目目录。

```bash
git clone https://github.com/NVIDIA/dgx-spark-playbooks
cd dgx-spark-playbooks/nvidia/txt2kg/assets
```

## 步骤 2. 启动 txt2kg 服务

使用提供的启动脚本启动所有必需的服务。这将设置 Ollama、ArangoDB 和 Next.js 前端：

```bash
./start.sh
```

脚本将自动：
- 检查 GPU 可用性
- 启动 Docker Compose 服务
- 设置 ArangoDB 数据库
- 启动 Web 界面

## 步骤 3. 拉取 Ollama 模型（可选）

下载用于知识提取的语言模型。默认加载的模型是 Llama 3.1 8B：

```bash
docker exec ollama-compose ollama pull <model-name>
```

浏览可用模型：[https://ollama.com/search](https://ollama.com/search)

> [!NOTE]
> 统一内存架构使你可以运行像 70B 参数这样更大的模型，从而生成更准确的知识三元组。

## 步骤 4. 访问 Web 界面

在浏览器中打开并导航到：

```
http://localhost:3001
```

你还可以访问各个服务：
- **ArangoDB Web 界面**：http://localhost:8529 
- **Ollama API**：http://localhost:11434

## 步骤 5. 上传文档并构建知识图谱

#### 5.1. 文档上传
- 使用 Web 界面上传文本文档（支持 markdown、text、CSV）
- 文档会自动分块并处理三元组提取

#### 5.2. 知识图谱生成
- 系统使用 Ollama 提取主语-谓语-宾语三元组
- 三元组存储在 ArangoDB 中进行关系查询

#### 5.3. 交互式可视化
- 使用 GPU 加速渲染在 2D 或 3D 中查看知识图谱
- 交互式探索节点和关系

#### 5.4. 基于图的查询
- 使用查询界面询问有关文档的问题
- 图遍历通过 ArangoDB 中的实体关系增强上下文
- LLM 使用增强的图上下文生成响应

> **未来增强**：计划使用基于向量的 KNN 搜索进行实体检索的 GraphRAG 功能。

## 步骤 6. 清理和回滚

停止所有服务并可选地删除容器：

```bash
## 停止服务
docker compose down

## 删除容器和卷（可选）
docker compose down -v

## 删除下载的模型（可选）
docker exec ollama-compose ollama rm llama3.1:8b
```

## 步骤 7. 下一步

- 尝试使用不同的 Ollama 模型进行不同的提取质量
- 自定义三元组提取提示以获取特定领域的知识
- 探索高级图查询和可视化功能

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| Ollama 性能问题 | DGX Spark 的设置不佳 | 设置环境变量：<br>`OLLAMA_FLASH_ATTENTION=1`（启用闪存注意力以提高性能）<br>`OLLAMA_KEEP_ALIVE=30m`（将模型保持加载 30 分钟）<br>`OLLAMA_MAX_LOADED_MODELS=1`（避免 VRAM 竞争）<br>`OLLAMA_KV_CACHE_TYPE=q8_0`（减少 KV 缓存 VRAM，性能影响最小） |
| VRAM 耗尽或内存压力（例如在 Ollama 模型之间切换时） | Linux 缓冲区缓存消耗 GPU 内存 | 刷新缓冲区缓存：`sudo sync; sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'` |
| 三元组提取缓慢 | 大模型或大上下文窗口 | 减小文档块大小或使用更快的模型 |
| ArangoDB 连接被拒绝 | 服务未完全启动 | 在 start.sh 后等待 30 秒，使用 `docker ps` 验证 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的动态共享。
> 随着许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，你也可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```
