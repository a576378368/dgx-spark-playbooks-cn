# 投资组合优化

> 使用 cuOpt 和 cuML 进行 GPU 加速的投资组合优化

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

本 playbook 演示了一个端到端的 GPU 加速工作流，使用 NVIDIA cuOpt 和 NVIDIA cuML 来解决大规模投资组合优化问题，使用均值-条件风险价值（CVaR）模型，实现在近实时环境中进行。

投资组合优化（PO）涉及解决高维、非线性数值优化问题以平衡风险和回报。现代投资组合通常包含数千种资产，使得传统的 CPU 基础求解器对于高级工作流来说太慢。通过将计算密集型任务移到 GPU，该解决方案显著减少了计算时间。

## 你将实现的目标

你将实现一个提供性能评估、策略回测、基准测试和可视化工具的管道。工作流包括：
- **GPU 加速优化：** 利用 NVIDIA cuOpt LP/MILP 求解器
- **数据驱动风险建模：** 将 CVaR 实现为基于场景的风险度量，建模尾部风险而不对资产回报分布做出假设。
- **场景生成：** 使用 NVIDIA cuML 的 GPU 加速核密度估计（KDE）来建模回报分布。
- **现实世界约束管理：** 实施约束，包括集中度限制、杠杆约束、周转率限制和基数约束。
- **全面回测：** 使用特定工具评估投资组合性能，测试再平衡策略。

## 开始前须知

- **所需技能（你会获得）：**
  - 基本使用终端和 Linux 命令行
  - 基本了解 Docker 容器
  - 基本了解使用 Jupyter Notebook 和 Jupyter Lab
  - 基本 Python 知识
  - 基本的数据科学和机器学习概念知识
  - 基本了解股票市场和股票是什么

- **可选技能（你会享受的）：**
  - 金融服务背景，特别是在定量金融和投资组合管理方面
  - 中等水平的编程算法和策略知识，使用机器学习概念的 Python

- **需要了解的术语：**
  - **CVaR 与均值-方差：** 与传统的均值-方差模型不同，此工作流使用条件风险价值（CVaR）来捕捉风险的细微差别，特别是尾部风险或特定场景压力。
  - **线性规划：** CVaR 将风险-回报权衡重新表述为基于场景的线性规划，其中问题规模随场景数量扩展，这就是 GPU 加速至关重要的原因。
  - **基准测试：** 管道包括内置工具，以简化与标准 CPU 基础库的基准测试过程，验证性能提升。

## 先决条件

**硬件要求：**
- NVIDIA Grace Blackwell GB10 Superchip 系统（DGX Spark）
- 至少 40GB 统一内存可用于 Docker 容器和 GPU 加速数据处理
- 至少 30GB 可用存储空间用于 Docker 容器和数据文件
- 推荐高速互联网连接

**软件要求：**
- 带有工作 NVIDIA 和 CUDA 驱动程序的 NVIDIA DGX OS
- Docker
- Git

## 辅助文件

所有必需的资产都可以在 [投资组合优化存储库中](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/portfolio-optimization/assets/) 找到。在运行的 playbook 中，它们都将位于 `playbook` 文件夹下。

- `cvar_basic.ipynb` - 主 playbook 笔记本。
- `/setup/README.md` - Playbook 环境快速入门指南。
- `/setup/start_playbook.sh` - 启动 playbook 在 Docker 容器中安装的脚本
- `/setup/setup_playbook.sh` - 在用户进入 jupyterlab 环境之前配置 Docker 容器
- `/setup/pyproject.toml` - 用作 setup_playbook 将安装到 playbook 环境中的库列表
- `cuDF、cuML 和 cuGraph 文件夹` - 更多示例笔记本，继续你的 GPU 加速数据科学之旅。这些将成为 Docker 容器的一部分当你启动它时。

## 时间与风险

* **估计时间** ~20 分钟用于首次运行
  - 总 Notebook 处理时间：完整管道大约需要 7 分钟。

- **风险：**
  - 最小，因为这在 Docker 容器中运行。

- **回滚：** 停止 Docker 容器并删除克隆的存储库以完全删除安装。

- **最后更新：** 2026年1月21日
  * 使用正确的项目路径更新 `git clone` 命令。

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
- `docker --version` 将打印类似 `Docker version 28.3.3, build 980b856` 的内容。如果你收到 Docker 未安装的错误，请重新安装它。

## 步骤 2. 安装
打开终端，然后复制并粘贴以下命令：

```bash
git clone https://github.com/NVIDIA/dgx-spark-playbooks
cd dgx-spark-playbooks/nvidia/portfolio-optimization/assets
bash ./setup/start_playbook.sh
```

start_playbook.sh 将：

1. 拉取 RAPIDS 25.10 笔记本 Docker 容器
2. 使用 `setup_playbook.sh` 构建 playbook 所需的所有环境
3. 启动 Jupyterlab

使用 playbook 时请保持终端窗口打开。

你可以在三种方式下访问你的 Jupyterlab 服务器
1. 在 `http://127.0.0.1:8888` 如果在 DGX Spark 上本地运行。
2. 在 `http://<SPARK_IP>:8888` 如果通过网络使用无头 DGX Spark。
3. 通过使用 `ssh -L 8888:localhost:8888 username@spark-IP` 创建 SSH 隧道，然后在主机机器上的浏览器中访问 `http://127.0.0.1:8888`

进入 Jupyterlab 后，你将看到一个包含 `cvar_basic.ipynb` 的目录，以及文件夹 `cudf`、`cuml` 和 `cugraph`。

- `cvar_basic.ipynb` 是 playbook 笔记本。你将想要通过双击文件打开它。
- `cudf`、`cuml`、`cugraph` 文件夹包含标准 RAPIDS 库示例笔记本，帮助你继续探索。
- `playbook` 包含 playbook 文件。此文件夹的内容在无根 Docker 容器内是只读的。

如果你想在自己的系统上安装任何 playbook 笔记本，请查看 accompanying the notebook 的文件夹中的 readme

## 步骤 3. 运行 notebook

进入 jupyterlab 后，你所要做的就是运行 `cvar_basic.ipynb`。

在开始运行 notebook 中的单元格之前，**请按照 notebook 中的说明将内核更改为 "Portfolio Optimization"**。否则会在第二个代码单元格中导致错误。如果你已经开始了，你将需要设置正确的内核，然后重启内核，再试一次。

你可以使用 `Shift + Enter` 以自己的节奏手动运行每个单元格，或 `Run > Run All` 运行所有单元格。

完成 `cvar_basic` 笔记本的探索后，你可以通过进入文件夹、选择其他笔记本并执行相同操作来探索其他 RAPIDS 笔记本。

## 步骤 4. 下载你的工作

由于 docker 容器没有特权且无法写回主机系统，你可以使用 Jupyterlab 下载在 docker 容器关闭后可能想要保留的任何文件。

只需在浏览器中右键单击你想要的文件，然后点击下拉菜单中的 `Download`。

## 步骤 5. 清理

下载所有工作后，回到你开始运行 playbook 的终端窗口。

在终端窗口中：
1. 输入 `Ctrl + C`
2. 快速输入 `y` 然后按 Enter 键，或再次按 `Ctrl + C`
3. Docker 容器将继续关闭

> [!WARNING]
> 这将删除所有尚未从 Docker 容器下载的数据。如果浏览器窗口仍然打开，缓存的文件可能仍然显示。

## 步骤 6. 下一步

一旦你熟悉了这个基础工作流，请按照以下顺序探索这些高级投资组合优化主题 **[NVIDIA AI Blueprints](https://github.com/NVIDIA-AI-Blueprints/quantitative-portfolio-optimization/)**：

* **[`efficient_frontier.ipynb`](https://github.com/NVIDIA-AI-Blueprints/quantitative-portfolio-optimization/tree/main/notebooks/efficient_frontier.ipynb)** - 有效前沿分析

  本笔记本演示如何：
  - 通过解决多个优化问题生成有效前沿
  - 可视化不同投资组合配置的风险-回报权衡
  - 比较沿有效前沿的投资组合
  - 利用 GPU 加速快速计算多个最优投资组合

* **[`rebalancing_strategies.ipynb`](https://github.com/NVIDIA-AI-Blueprints/quantitative-portfolio-optimization/tree/main/notebooks/rebalancing_strategies.ipynb)** - 动态投资组合再平衡

  本笔记本介绍动态投资组合管理技术：
  - 时间序列回测框架
  - 测试各种再平衡策略（定期、基于阈值等）
  - 评估交易成本对投资组合性能的影响
  - 分析不同市场条件下的策略性能
  - 比较多种再平衡方法

* 如果你想进一步学习如何使用类似的风险-回报框架制定投资组合优化问题，请查看 **[DLI 课程：加速投资组合优化](https://learn.nvidia.com/courses/course-detail?course_id=course-v1:DLI+S-DS-09+V1)**

## 步骤 7. 进一步支持

有关问题或问题，请访问：
- [GitHub Issues](https://github.com/NVIDIA-AI-Blueprints/quantitative-portfolio-optimization/issues)

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| Docker 未找到。 | Docker 可能已被卸载，因为它预装在你的 DGX Spark 上 | 请按照此处的便利脚本安装 Docker：`curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh`。系统会提示你输入密码。 |
| Docker 命令意外退出并出现 "permissions" 错误 | 你的用户不是 `docker` 组的成员 | 打开终端并运行这些命令：`sudo groupadd docker && sudo usermod -aG docker $USER`。系统会提示你输入密码。然后，关闭终端，打开一个新的终端，再试一次 |
| Docker 容器下载、环境构建或数据下载失败 | 存在连接问题或资源可能暂时不可用。 | 你可能需要稍后再试。如果问题持续，请联系我们！ |

> [!NOTE]
> DGX Spark 使用统一内存架构（UMA），允许 GPU 和 CPU 内存之间的动态共享。
> 随着许多应用程序仍在更新以利用 UMA，即使在 DGX Spark 的内存容量内，你也可能遇到内存问题。如果发生这种情况，请手动刷新缓冲区缓存：
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
