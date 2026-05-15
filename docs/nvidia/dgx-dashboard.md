# DGX Dashboard

> 监控您的 DGX 系统并启动 JupyterLab

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

DGX Dashboard 是一个运行在 DGX Spark 设备上的本地 Web 应用程序，提供系统更新、资源监控和集成 JupyterLab 环境的图形界面。用户可以从应用程序启动器本地访问仪表板，或通过 NVIDIA Sync 或 SSH 隧道远程访问。当远程工作时，仪表板是更新系统包和固件的最简单方法。

## 您将实现的目标

您将学习如何访问和使用 DGX Spark 设备上的 DGX Dashboard。完成本指南后，您将能够：
- 启动带有预配置 Python 环境的 JupyterLab 实例
- 监控 GPU 性能
- 管理系统更新
- 使用 Stable Diffusion 运行示例 AI 工作负载
- 了解多种访问方法，包括桌面快捷方式、NVIDIA Sync 和手动 SSH 隧道

## 开始前须知

- 基本的终端使用经验，用于 SSH 连接和端口转发
- 了解 Python 环境和 Jupyter 笔记本

## 先决条件

**硬件要求：**
- NVIDIA Grace Blackwell GB10 Superchip 系统

**软件要求：**
- NVIDIA DGX OS
- 已安装 NVIDIA Sync（用于远程访问方法）或已配置 SSH 客户端

## 辅助文件

- 在 GitHub 上找到的 SDXL Python 代码片段：[链接](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/dgx-dashboard/assets/jupyter-cell.py)

## 时间与风险

* **持续时间：** 完整指南需要 15-30 分钟，包括示例 AI 工作负载
* **风险等级：** 低 - Web 界面操作，对系统影响最小
* **回滚方案：** 通过仪表板界面停止 JupyterLab 实例；正常使用期间不会进行永久性系统更改。
* **最后更新：** 2025年11月21日
  * 少量文字编辑

---

## 操作说明

## 步骤 1. 访问 DGX Dashboard

选择以下方法之一访问 DGX Dashboard Web 界面：

**选项 A：桌面快捷方式（本地访问）**

如果您可以本地访问 DGX Spark 设备：

1. 登录 DGX Spark 设备上的 Ubuntu Desktop 环境
2. 点击屏幕左下角打开 Ubuntu 应用程序启动器
3. 点击启动器中的 DGX Dashboard 快捷方式
4. 仪表板将在您的默认 Web 浏览器中打开，地址为 `http://localhost:11000`

**选项 B：NVIDIA Sync（推荐用于远程访问）**

如果您已在本地计算机上安装了 NVIDIA Sync：

1. 点击系统托盘中的 NVIDIA Sync 图标
2. 从设备列表中选择您的 DGX Spark 设备
3. 点击"连接"
4. 点击"DGX Dashboard"启动仪表板
5. 仪表板将在您的默认 Web 浏览器中打开，地址为 `http://localhost:11000`，使用自动 SSH 隧道

没有 NVIDIA Sync？[在此安装](/spark/connect-to-your-spark/sync)

**选项 C：手动 SSH 隧道**

如果您想在没有 NVIDIA Sync 的情况下手动远程访问，您必须首先[手动配置 SSH 隧道](/spark/connect-to-your-spark/manual-ssh)。

如果要远程访问，您必须为 Dashboard 服务器（端口 11000）和 JupyterLab 打开一个隧道。每个用户账户将有不同的 JupyterLab 分配端口号。

1. 通过 SSH 登录到 DGX Spark 并运行以下命令，检查您分配的 JupyterLab 端口：

```bash
cat /opt/nvidia/dgx-dashboard-service/jupyterlab_ports.yaml
```

2. 查找您的用户名并记下分配的端口号。
3. 创建一个包含两个端口的新 SSH 隧道：

```bash
ssh -L 11000:localhost:11000 -L <ASSIGNED_PORT>:localhost:<ASSIGNED_PORT> <USERNAME>@<SPARK_DEVICE_IP>
```
将 `<USERNAME>` 替换为您的 DGX Spark 设备用户名，将 `<SPARK_DEVICE_IP>` 替换为设备的 IP 地址。

将 `<ASSIGNED_PORT>` 替换为 YAML 文件中的端口号。

在 Web 浏览器中打开并导航到 `http://localhost:11000`。

## 步骤 2. 登录 DGX Dashboard

仪表板在浏览器中加载后：

1. 在用户名字段中输入您的 DGX Spark 系统用户名
2. 在密码字段中输入您的系统密码
3. 点击"登录"访问仪表板界面

您应该会看到主仪表板，其中包含 JupyterLab 管理、系统监控和设置面板。

## 步骤 3. 启动 JupyterLab 实例

创建并启动 JupyterLab 环境：

1. 点击右侧面板中的"启动"按钮
2. 监控状态转换：启动 → 准备中 → 运行中
3. 等待状态显示为"运行中"（首次启动可能需要几分钟）
4. 一旦"运行中"，如果 JupyterLab 没有自动在您的浏览器中打开（弹出窗口被阻止），您可以点击"在浏览器中打开"按钮

启动时，会自动创建一个默认工作目录（/home/<USERNAME>/jupyterlab）并设置一个虚拟环境。您可以通过查看工作目录中创建的 `requirements.txt` 文件来检查安装的包。

将来，您可以通过点击"停止"按钮，将路径更改为新工作目录，然后再次点击"启动"按钮来更改工作目录，从而创建一个新的隔离环境。

## 步骤 4. 使用示例 AI 工作负载进行测试

通过运行简单的 Stable Diffusion XL 图像生成示例来验证您的设置：

1. 在 JupyterLab 中，创建一个新的笔记本：文件 → 新建 → 笔记本
2. 点击"Python 3 (ipykernel)"创建笔记本
3. 添加一个新单元格并粘贴以下代码：

```python
import warnings
warnings.filterwarnings('ignore', message='.*cuda capability.*')
import tqdm.auto
tqdm.auto.tqdm = tqdm.std.tqdm

from diffusers import DiffusionPipeline
import torch
from PIL import Image
from datetime import datetime
from IPython.display import display

## --- 模型设置 ---
MODEL_ID = "stabilityai/stable-diffusion-xl-base-1.0"
dtype = torch.float16 if torch.cuda.is_available() else torch.float32

pipe = DiffusionPipeline.from_pretrained(
    MODEL_ID,
    torch_dtype=dtype,
    variant="fp16" if dtype==torch.float16 else None,
)
pipe = pipe.to("cuda" if torch.cuda.is_available() else "cpu")

## --- 提示设置 ---
prompt = "a cozy modern reading nook with a big window, soft natural light, photorealistic"
negative_prompt = "low quality, blurry, distorted, text, watermark"

## --- 生成设置 ---
height = 1024
width = 1024
steps = 30
guidance = 7.0

## --- 生成 ---
result = pipe(
    prompt=prompt,
    negative_prompt=negative_prompt,
    num_inference_steps=steps,
    guidance_scale=guidance,
    height=height,
    width=width,
)

## --- 保存到文件 ---
image: Image.Image = result.images[0]
display(image)
image.save(f"sdxl_output.png")
print(f"Saved image as sdxl_output.png")
```

4. 运行单元格（Shift+Enter 或点击运行按钮）
5. 笔记本将下载模型并生成图像（首次运行可能需要几分钟）

## 步骤 5. 监控 GPU 利用率

当图像生成正在运行时：

1. 切换回浏览器中的 DGX Dashboard 标签页
2. 观察监控面板中的 GPU 遥测数据

## 步骤 6. 停止 JupyterLab 实例

完成会话后：

1. 返回主 DGX Dashboard 标签页
2. 点击 JupyterLab 面板中的"停止"按钮
3. 确认状态从"运行中"更改为"已停止"

## 步骤 7. 管理系统更新

如果系统更新可用，将通过横幅或设置页面指示。

在设置页面的"更新"标签页下：

1. 点击"更新"打开确认对话框
2. 点击"立即更新"启动更新过程
3. 等待更新完成和设备重启

> [!WARNING]
> 系统更新将升级包、固件（如果可用）并触发重启。继续之前请保存您的工作。

## 步骤 8. 清理和回滚

清理资源并将系统恢复到原始状态：

1. 通过仪表板停止任何正在运行的 JupyterLab 实例
2. 删除 JupyterLab 工作目录

> [!WARNING]
> 如果您运行了系统更新，则唯一的回滚方法是恢复系统备份或恢复媒体。

正常仪表板使用期间不会对系统进行永久性更改。

## 步骤 9. 后续步骤

现在您已经配置了 DGX Dashboard，您可以：

- 为不同项目创建额外的 JupyterLab 环境
- 使用仪表板管理系统维护和更新

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| 用户无法运行更新 | 用户不在 sudo 组 | 将用户添加到 sudo 组：`sudo usermod -aG sudo <USERNAME>`；然后运行 `newgrp docker` |
| JupyterLab 无法启动 | 当前虚拟环境存在问题 | 更改 JupyterLab 面板中的工作目录并启动新实例 |
| SSH 隧道连接被拒绝 | IP 或端口不正确 | 验证 Spark 设备 IP 并确保 SSH 服务正在运行 |
| 监控中看不到 GPU | 驱动程序问题 | 使用 `nvidia-smi` 检查 GPU 状态 |

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
