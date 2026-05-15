# 安装和使用 Isaac Sim 和 Isaac Lab

> 为 Spark 从源码构建 Isaac Sim 和 Isaac Lab

## 目录

- [概述](#概述)
- [运行 Isaac Sim](#运行-isaac-sim)
- [运行 Isaac Lab](#运行-isaac-lab)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

Isaac Sim 是一个基于 NVIDIA Omniverse 构建的机器人仿真平台，能够实现机器人和环境的逼真、物理精确的仿真。它为机器人开发提供了一套全面的工具包，包括物理仿真、传感器仿真和可视化功能。Isaac Lab 是构建在 Isaac Sim 之上的强化学习框架，专为训练和部署机器人应用的强化学习策略而设计。

Isaac Sim 使用 GPU 加速的物理仿真，实现快速、逼真的机器人仿真，可以实时或更快的速度运行。Isaac Lab 在此基础上增加了预建的强化学习环境、训练脚本和评估工具，用于常见的机器人任务，如运动、操纵和导航。两者 together 提供了一个端到端解决方案，可以在仿真中完全开发、训练和测试机器人应用，然后再部署到真实硬件上。

## 您将实现的目标

您将在 NVIDIA DGX Spark 设备上从源码构建 Isaac Sim，并设置 Isaac Lab 进行强化学习实验。这包括编译 Isaac Sim 引擎、配置开发环境，以及运行示例强化学习训练任务以验证安装。

## 开始前须知

- 使用 CMake 和构建系统从源码构建软件的经验
- 熟悉 Linux 命令行操作和环境变量
- 了解 Git 版本控制和 Git LFS 大文件管理
- 基本的 Python 包管理和虚拟环境知识
- 了解机器人仿真概念（有帮助但非必需）

## 先决条件

**硬件要求：**
- NVIDIA Grace Blackwell GB10 Superchip 系统
- 至少 50GB 可用存储空间用于 Isaac Sim 构建工件和依赖项

**软件要求：**
- NVIDIA DGX OS
- GCC/G++ 11 编译器：`gcc --version` 显示版本 11.x
- 已安装 Git 和 Git LFS：`git --version` 和 `git lfs version` 成功
- 网络访问权限，用于从 GitHub 克隆存储库和下载依赖项

## 辅助文件

所有必需的资源都可以在 GitHub 上的 Isaac Sim 和 Isaac Lab 存储库中找到：
- [Isaac Sim 存储库](https://github.com/isaac-sim/IsaacSim) - 主 Isaac Sim 源代码
- [Isaac Lab 存储库](https://github.com/isaac-sim/IsaacLab) - Isaac Lab 强化学习框架

## 时间与风险

* **预计时间：** 30 分钟（包括构建时间，通常需要 10-15 分钟）
* **风险等级：** 中等
  * 使用 Git LFS 的大型存储库克隆可能因网络问题而失败
  * 构建过程需要显著的编译时间，可能遇到依赖项问题
  * 构建工件消耗大量磁盘空间
* **回滚方案：** 可以删除 Isaac Sim 构建目录以释放空间。如果需要，可以删除并重新克隆 Git 存储库。
* **最后更新：** 2026年1月2日
  * 首次发布

---

## 运行 Isaac Sim

## 步骤 1. 安装 gcc-11 和 git-lfs

在构建之前确认使用的是 GCC/G++ 11，使用以下命令：
```bash
sudo apt update && sudo apt install -y gcc-11 g++-11
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 200
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 200
sudo apt install git-lfs
gcc --version
g++ --version
```

## 步骤 2. 将 Isaac Sim 存储库克隆到您的工作区

从 NVIDIA GitHub 存储库克隆 Isaac Sim 并设置 Git LFS 以拉取大文件。

> **注意：** 对于 Isaac Sim 6.0.0 早期开发者版本，请使用：
> ```bash
> git clone --depth=1 --recursive --branch=develop https://github.com/isaac-sim/IsaacSim
> ```

```bash
git clone --depth=1 --recursive https://github.com/isaac-sim/IsaacSim
cd IsaacSim
git lfs install
git lfs pull
```

## 步骤 3. 构建 Isaac Sim

构建 Isaac Sim 并接受许可证协议。

```bash
./build.sh
```

构建成功时，您会看到以下消息：**BUILD (RELEASE) SUCCEEDED (Took 674.39 seconds)**

## 步骤 4. 让系统识别 Isaac Sim

运行以下命令时，请确保您在 Isaac Sim 目录内。

```bash
export ISAACSIM_PATH="${PWD}/_build/linux-aarch64/release"
export ISAACSIM_PYTHON_EXE="${ISAACSIM_PATH}/python.sh"
```

## 步骤 5. 运行 Isaac Sim

使用提供的 Python 可执行文件启动 Isaac Sim。

```bash
export LD_PRELOAD="$LD_PRELOAD:/lib/aarch64-linux-gnu/libgomp.so.1"
${ISAACSIM_PATH}/isaac-sim.sh
```

---

## 运行 Isaac Lab

## 步骤 1. 安装 Isaac Sim
如果尚未安装，请先安装 [Isaac Sim](build.nvidia.com/spark/isaac/isaac-sim)。

## 步骤 2. 将 Isaac Lab 存储库克隆到您的工作区

从 NVIDIA GitHub 存储库克隆 Isaac Lab。

> **注意：** 对于 Isaac Lab 早期开发者版本，请使用：
> ```bash
> git clone --recursive --branch=develop https://github.com/isaac-sim/IsaacLab
> ```

```bash
git clone --recursive https://github.com/isaac-sim/IsaacLab
cd IsaacLab
```

## 步骤 3. 创建指向 Isaac Sim 安装的符号链接

运行以下命令前，请确保您已经从 [Isaac Sim](build.nvidia.com/spark/isaac/isaac-sim) 安装了 Isaac Sim。

```bash
echo "ISAACSIM_PATH=$ISAACSIM_PATH"
```
创建指向 Isaac Sim 安装目录的符号链接。
```bash
ln -sfn "${ISAACSIM_PATH}" "${PWD}/_isaac_sim"
ls -l "${PWD}/_isaac_sim/python.sh"
```

## 步骤 4. 安装 Isaac Lab

安装 Newton 的依赖项，需要 X11 开发库才能从源码构建 imgui_bundle。

```bash
sudo apt update
sudo apt install -y libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libgl1-mesa-dev
```

然后安装 Isaac Lab。

```bash
./isaaclab.sh --install
```

## 步骤 5. 运行 Isaac Lab 并验证人形强化学习训练

使用提供的 Python 可执行文件启动 Isaac Lab。您可以以下列模式之一运行训练：

**选项 1：无头模式（推荐用于更快的训练）**

在不可视化的情况下运行，并将日志直接输出到终端。

```bash
export LD_PRELOAD="$LD_PRELOAD:/lib/aarch64-linux-gnu/libgomp.so.1"
./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py --task=Isaac-Velocity-Rough-H1-v0 --headless
```

**选项 2：启用可视化**

在 Isaac Sim 中实时可视化运行，允许您交互式监控训练过程。

```bash
export LD_PRELOAD="$LD_PRELOAD:/lib/aarch64-linux-gnu/libgomp.so.1"
./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py --task=Isaac-Velocity-Rough-H1-v0
```

---

## 故障排除

## Isaac Sim 常见问题

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| Isaac Sim 错误编译 | 默认不是 gcc/g++ 11 | 确保 gcc/g++ 11 是默认版本 |
| Isaac Sim 无法执行 | libgomp.so.1 错误 | 添加 export LD_PRELOAD |
| 构建错误 | 旧安装 | 删除 .cache 文件夹 |

## Isaac Lab 常见问题

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| Isaac Lab 无法执行 | libgomp.so.1 错误 | 添加 export LD_PRELOAD |
