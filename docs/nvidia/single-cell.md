# 单细胞 RNA 测序

> 使用 RAPIDS 的端到端 GPU 驱动的 scRNA-seq 工作流

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

单细胞 RNA 测序（scRNA-seq）允许研究人员单独研究每个细胞中的基因活性，揭示批量方法隐藏的变异、细胞类型和细胞状态。但这些大型、高维数据集需要大量计算能力来处理。

本 playbook 演示了一个端到端的 GPU 驱动的 scRNA-seq 工作流，使用 [RAPIDS-singlecell](https://rapids-singlecell.readthedocs.io/en/latest/)，这是一个在 [scverse® 生态系统](https://github.com/scverse) 中的 RAPIDS 驱动的库。它遵循熟悉的 [Scanpy API](https://scanpy.readthedocs.io/en/stable/)，允许研究人员通过直接在 GPU 上处理稀疏计数矩阵，比 CPU 工具更快地运行数据预处理、质量控制（QC）和清理、可视化和调查的步骤。

## 你将实现的目标

1. GPU 加速的数据加载和预处理
2. 可视化 QC 细胞以了解数据
3. 过滤异常细胞
4. 移除不需要的变异来源
5. 聚类和可视化 PCA 和 UMAP 数据
6. 使用 Harmony、k 近邻、UMAP 和 tSNE 进行批次校正和分析
7. 通过差异表达分析和轨迹分析从数据中探索生物学信息

README 详细说明了这些步骤。

## 开始前须知

- rapids-singlecell 库模仿 scverse 的 Scanpy API，允许熟悉标准 CPU 工作流的用户轻松适应通过 cuPy 和 NVIDIA RAPIDS cuML 和 cuGraph 的 GPU 加速。
- 算法精度：与 Scanpy 的 CPU 实现使用近似最近邻搜索不同，此 GPU 实现计算精确图；因此，预期并验证结果中的小差异。
- 参数敏感性：执行 t-SNE 时，最近邻的数量必须至少为 3x 以避免失真

## 先决条件

**硬件要求：**
- NVIDIA Grace Blackwell GB10 Superchip 系统（DGX Spark）
- 至少 40GB 统一内存可用于 Docker 容器和 GPU 加速数据处理
- 至少 30GB 可用存储空间用于 Docker 容器和数据文件
- 高速网络连接
- 推荐高速互联网连接

**软件要求：**
- NVIDIA DGX OS
- Docker

## 辅助文件

所有必需的资产都可以在 [单细胞 RNA 测序存储库](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/single-cell/) 中找到。在运行的 playbook 中，它们都将位于 `playbook` 文件夹下。

- `scRNA_analysis_preprocessing.ipynb` - 主 playbook 笔记本。
- `README.md` - Playbook 环境快速入门指南。它也会在 Jupyter Lab 的主目录中找到。请从这里开始！
- `/setup/start_playbook.sh` - 启动 playbook 在 Docker 容器中安装的脚本
- `/setup/setup_playbook.sh` - 在用户进入 JupyterLab 环境之前配置 Docker 容器
- `/setup/requirements.txt` - 用作 setup_playbook 将安装到 playbook 环境中的库列表

## 时间与风险

* **估计时间：** ~15 分钟用于首次运行

  - 总 Notebook 处理时间：完整管道大约需要 2-3 分钟（在演示中记录为 ~130 秒）。
  - 数据加载：~1.7 秒。
  - 预处理：~21 秒。
  - 后处理（聚类/差异表达）：~104 秒。
  - 数据：互联网访问以下载 Docker 容器、库和演示数据集（dli_census.h5ad）。

* **风险**

  - GPU 内存限制：工作流非常 GPU 内存密集。大型数据集可能会触发内存不足（OOM）错误。
  - 内核管理：你可能需要在工作流阶段之间终止/重启内核以释放 GPU 资源。
  - 回滚：如果发生 OOM 错误，终止所有内核以释放 GPU 内存，然后重启特定笔记本或整个 playbook。

* **最后更新：** 2026年1月2日
  * 首次发布

---

## 操作说明

## 步骤 1. 验证你的环境

让我们首先验证你有一个工作 GPU、git 和 Docker。打开终端，然后复制并粘贴以下命令：

```bash
nvidia-smi
git --version
docker --version
```

- `nvidia-smi` 将输出有关你的 GPU 的信息。如果它没有输出，你的 GPU 没有正确配置。
- `git --version` 将打印类似 `git version 2.43.0` 的内容。如果你收到 git 未安装的错误，请重新安装它。
- `docker --version` 将打印类似 `Docker version 28.3.3, build 980b856` 的内容。如果你收到 Docker 未安装的错误，请重新安装它。如果你看到权限被拒绝错误，通过运行 `sudo usermod -aG docker $USER && newgrp docker` 将你的用户添加到 docker 组。

## 步骤 2. 安装
打开终端，然后复制并粘贴以下命令：

```bash
git clone https://github.com/NVIDIA/dgx-spark-playbooks
cd dgx-spark-playbooks/nvidia/single-cell/assets
bash ./setup/start_playbook.sh
```

start_playbook.sh 将：

1. 拉取 RAPIDS 25.10 笔记本 Docker 容器
2. 使用 setup_playbook.sh 构建 playbook 在容器中所需的所有环境
3. 启动 JupyterLab

使用 playbook 时请保持终端窗口打开。

你可以在两种方式下访问你的 JupyterLab 服务器
1. 在 `http://127.0.0.1:8888` 如果在 DGX Spark 上本地运行。
2. 在 `http://<SPARK_IP>:8888` 如果通过网络使用无头 DGX Spark。

进入 JupyterLab 后，你将看到一个目录，包含 scRNA_analysis_preprocessing.ipynb，以及文件夹 `cuDF`、`cuML`、`cuGraph` 和 `playbook`。

- `scRNA_analysis_preprocessing.ipynb` 是 playbook 笔记本。你将想要通过双击文件打开它。
- `cuDF`、`cuML`、`cuGraph` 文件夹包含标准 RAPIDS 库示例笔记本，帮助你继续探索。
- `playbook` 包含 playbook 文件。此文件夹的内容在无根 Docker 容器内是只读的。

如果你想在自己的系统上安装任何 playbook 笔记本，请查看 accompanying the notebook 的文件夹中的 readme

## 步骤 3. 运行 notebook

进入 JupyterLab 后，你所要做的就是运行 `scRNA_analysis_preprocessing.ipynb`。你将得到这两个 playbook 笔记本以及标准 RAPIDS 库示例笔记本，帮助你开始。

你可以使用 `Shift + Enter` 以自己的节奏手动运行每个单元格，或 `Run > Run All` 运行所有单元格。

完成 `scRNA_analysis_preprocessing` 笔记本的探索后，你可以通过进入文件夹、选择其他笔记本并执行相同操作来探索其他 RAPIDS 笔记本。

## 步骤 4. 下载你的工作

由于 docker 容器无法特权写回主机系统，你可以使用 JupyterLab 下载在 docker 容器关闭后可能想要保留的任何文件。

只需在浏览器中右键单击你想要的文件，然后点击下拉菜单中的 `Download`。

## 步骤 5. 清理

下载所有工作后，回到你开始运行 playbook 的终端窗口。

在终端窗口中，
1. 输入 `Ctrl + C`
2. 快速输入 `y` 然后按 Enter 键，或再次按 `Ctrl + C`
3. Docker 容器将继续关闭

> [!WARNING]
> 这将删除所有尚未从 Docker 容器下载的数据。如果浏览器窗口仍然打开，缓存的文件可能仍然显示。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| Docker 未找到。 | Docker 可能已被卸载，因为它预装在你的 DGX Spark 上 | 请使用他们的便利脚本安装 Docker：`curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh`。系统会提示你输入密码。 |
| Docker 命令意外退出并出现 "permissions" 错误 | 你的用户不是 `docker` 组的成员 | 打开终端并运行这些命令：`sudo groupadd docker && sudo usermod -aG docker $USER`。系统会提示你输入密码。然后，关闭终端，打开一个新的终端，再试一次 |
| Docker 容器下载、环境构建或数据下载失败 | 存在连接问题或资源可能暂时不可用。 | 你可能需要稍后再试。如果问题持续，请在 Spark 用户论坛上发布以获取支持 |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的动态共享。
> 随着许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，你也可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
