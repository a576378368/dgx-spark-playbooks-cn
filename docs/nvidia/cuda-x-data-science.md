# CUDA-X 数据科学

> 安装并使用 NVIDIA cuML 和 NVIDIA cuDF 来加速 UMAP、HDBSCAN、pandas 等，无需修改代码

## 目录

- [概述](#概述)
- [操作说明](#操作说明)

---

## 概述

## 基本概念
本指南包括两个示例笔记本，演示如何使用 CUDA-X Data Science 库加速关键机器学习算法和核心 pandas 操作：

- **NVIDIA cuDF：** 加速数据准备和核心数据处理操作（处理 8GB 字符串数据），无需代码更改。
- **NVIDIA cuML：** 加速 scikit-learn 中流行的、计算密集型机器学习算法（LinearSVC）、UMAP 和 HDBSCAN，无需代码更改。

CUDA-X Data Science（原名 RAPIDS）是一个开源库集合，用于加速数据科学和数据处理生态系统。这些库可以在零代码更改的情况下加速流行的 Python 工具，如 scikit-learn 和 pandas。在 DGX Spark 上，这些库可在您的桌面上使用现有代码实现最佳性能。

## 您将实现的目标
您将加速流行的机器学习算法和数据分析操作。您将了解如何加速流行的 Python 工具，以及在 DGX Spark 上运行数据科学工作流的价值。

## 先决条件
- 熟悉 pandas、scikit-learn、机器学习算法（如支持向量机、聚类和降维算法）。
- 安装 conda
- 生成 Kaggle API 密钥

## 时间与风险
* **持续时间：** 20-30 分钟设置时间，每个笔记本运行需要 2-3 分钟。
* **风险：** 
  * 由于网络问题导致的数据下载缓慢或失败
  * Kaggle API 生成失败，需要重试
* **回滚方案：** 正常使用期间不会进行永久性系统更改。
* **最后更新：** 2025年11月7日
  * 少量文字编辑

---

## 操作说明

## 步骤 1. 验证系统要求
- 使用 `nvcc --version` 或 `nvidia-smi` 验证系统是否已安装 CUDA 13
- 使用 [这些说明](https://docs.anaconda.com/miniconda/install/) 安装 conda
- 使用 [这些说明](https://www.kaggle.com/discussions/general/74235) 创建 Kaggle API 密钥，并将 **kaggle.json** 文件放在笔记本所在的同一文件夹中

## 步骤 2. 安装数据科学库
使用以下命令安装 CUDA-X 库（这将创建一个新的 conda 环境）
  ```bash
    conda create -n rapids-test -c rapidsai -c conda-forge -c nvidia  \
    rapids=25.10 python=3.12 'cuda-version=13.0' \
    jupyter hdbscan umap-learn
  ```
## 步骤 3. 激活 conda 环境
  ```bash
    conda activate rapids-test
  ```
## 步骤 4. 克隆操作指南存储库
- 克隆 github 存储库并进入 **cuda-x-data-science** 文件夹中的 assets 文件夹
  ```bash
    git clone https://github.com/NVIDIA/dgx-spark-playbooks
  ```
- 将步骤 1 中创建的 **kaggle.json** 放在 assets 文件夹中

## 步骤 5. 运行笔记本
GitHub 存储库中有两个笔记本。
一个运行在 GPU 上使用 pandas 代码处理大型字符串数据的工作流示例。
- 运行 **cudf_pandas_demo.ipynb** 笔记本，并在浏览器中使用 `localhost:8888` 访问笔记本
  ```bash
    jupyter notebook cudf_pandas_demo.ipynb
  ```
另一个演示包括 UMAP 和 HDBSCAN 在内的机器学习算法示例。
- 运行 **cuml_sklearn_demo.ipynb** 笔记本，并在浏览器中使用 `localhost:8888` 访问笔记本
  ```bash
    jupyter notebook cuml_sklearn_demo.ipynb
  ```
如果您远程访问 DGX-Spark，请确保转发必要的端口以在本地浏览器中访问笔记本。使用以下说明进行端口转发：
```bash
  ssh -N -L YYYY:localhost:XXXX username@remote_host 
```
- `YYYY`：您想要使用的本地端口（例如 8888）
- `XXXX`：您在远程机器上启动 Jupyter Notebook 时指定的端口（例如 8888）
- `-N`：防止 SSH 执行远程命令
- `-L`：指定本地端口转发
