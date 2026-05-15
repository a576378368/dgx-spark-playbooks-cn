# AI Workbench 中的 RAG 应用

> 安装并使用 AI Workbench 克隆并运行可重现的 RAG 应用

## 目录

- [概述](#概述)
- [操作说明](#操作说明)
- [故障排除](#故障排除)

---

## 概述

## 基本概念

本指南演示如何使用 NVIDIA AI Workbench 设置和运行代理检索增强生成（RAG）项目。
你将使用 AI Workbench 克隆并运行一个预构建的代理 RAG 应用，该应用智能地路由查询，
评估响应的相关性和幻觉，并在评估和生成循环中迭代。该项目使用 Gradio Web 界面，
可以与 NVIDIA 托管的 API 端点或自托管模型配合使用。

## 你将实现的目标

你将在 NVIDIA AI Workbench 中运行一个功能齐全的代理 RAG 应用，带有 Web 界面，
你可以在其中提交查询并接收智能响应。系统将演示高级 RAG 功能，包括查询路由、
响应评估和迭代优化，给你提供关于 AI Workbench 开发环境和高级 RAG 架构的实践经验。

## 开始前须知

- 基本了解检索增强生成（RAG）概念
- 了解 API 密钥以及如何生成它们
- 熟悉使用 Web 应用程序和浏览器界面
- 基本了解容器化开发环境

## 先决条件

**硬件要求：**
- NVIDIA Grace Blackwell GB10 Superchip 系统

**软件要求：**
- NVIDIA AI Workbench 已安装或准备安装
- 免费的 NVIDIA API 密钥：在 [NGC API 密钥](https://org.ngc.nvidia.com/setup/api-keys) 生成
- 免费的 Tavily API 密钥：在 [Tavily](https://tavily.com/) 生成
- 用于克隆仓库和访问 API 的互联网连接
- 用于访问 Gradio 界面的 Web 浏览器

## 验证命令

- 验证 NVIDIA AI Workbench 应用程序存在于你的 DGX Spark 系统上
- 验证你的 API 密钥有效且是最新的

## 时间与风险

* **估计时间：** 30-45 分钟（如果需要包括 AI Workbench 安装）
* **风险级别：** 低 - 使用预构建容器和已建立的 API
* **回滚：** 只需从 AI Workbench 删除克隆的项目即可删除所有组件。AI Workbench 环境外没有进行系统更改。
* **最后更新：** 2025年10月28日
  * 小幅文字编辑

---

## 操作说明

## 步骤 1. 安装 NVIDIA AI Workbench

在你的 DGX Spark 系统上安装 AI Workbench 并完成初始设置向导。

在你的 DGX Spark 上，打开 **NVIDIA AI Workbench** 应用程序并点击 "Begin Installation"（开始安装）。

1. 安装向导将提示你进行身份验证
2. 等待自动安装完成（几分钟）
3. 安装完成后点击 "Let's Get Started"（让我们开始）

> [!NOTE]
> 如果你遇到以下错误消息，请重启你的 DGX Spark 然后重新打开 NVIDIA AI Workbench：
> "An error occurred ... container tool failed to reach ready state. try again: docker is not running"
> （发生错误...容器工具未能达到就绪状态。重试：docker 未运行）

## 步骤 2. 验证 API 密钥要求

接下来，你应该确保在继续项目设置之前拥有两个必需的 API 密钥。请妥善保存这些密钥！

* Tavily API 密钥：https://tavily.com/
* NVIDIA API 密钥：https://org.ngc.nvidia.com/setup/api-keys 
* 确保此密钥具有 `Public API Endpoints`（公共 API 端点）权限

在下一步中保留两个密钥。

## 步骤 3. 克隆代理 RAG 项目

你将从 GitHub 将预构建的代理 RAG 项目克隆到你的 AI Workbench 环境中。

从 AI Workbench 登录页面，选择 **Local**（本地）位置（如果尚未选择），然后从右上角点击 "Clone Project"（克隆项目）。

在克隆对话框中粘贴此 Git 仓库 URL：https://github.com/NVIDIA/workbench-example-agentic-rag

点击 "Clone"（克隆）开始克隆和构建过程。

## 步骤 4. 配置项目密钥

然后，你可以配置代理 RAG 应用正常运行所需的 API 密钥。

在项目构建时，使用出现的黄色警告横幅配置 API 密钥：

1. 点击黄色横幅中的 "Configure"（配置）
2. 输入你的 `NVIDIA_API_KEY`
3. 输入你的 `TAVILY_API_KEY`
4. 保存配置

等待项目构建完成后再继续。

## 步骤 5. 启动聊天应用

你现在可以启动 Web-based 聊天界面，与代理 RAG 系统交互。

导航到 **Environment**（环境）> **Project Container**（项目容器）> **Apps**（应用）> **Chat**（聊天）并启动 Web 应用。

将自动打开一个浏览器窗口，并加载 Gradio 聊天界面。

## 步骤 6. 测试基本功能

通过提交示例查询验证代理 RAG 系统是否正常工作。

在聊天应用中，点击或输入示例查询，例如：`How do I add an integration in the CLI?`（如何在 CLI 中添加集成？）

等待代理系统处理并响应。响应虽然是一般性的，但应该展示智能路由和评估。

## 步骤 7. 验证项目

通过测试核心功能确认你的设置是否正常工作。

验证以下组件是否正常运行：

* Web 应用程序无错误加载
* 示例查询返回响应
* 没有 API 身份验证错误出现
* "Monitor"（监控）选项卡中可以看到代理推理过程

## 步骤 8. 完成可选快速入门

你可以通过上传数据、检索上下文和测试自定义查询来评估高级功能。

**子步骤 A：上传示例数据集**
完成应用内的快速入门说明以上传示例数据集并测试改进的基于 RAG 的响应。

**子步骤 B：测试自定义数据集（可选）**
上传自定义数据集，调整 Router 提示，并提交自定义查询以测试自定义。

## 步骤 10. 清理和回滚

如果需要，你可以删除项目。

> [!WARNING]
> 这将永久删除项目和所有关联数据。

要完全删除项目：

1. 在 AI Workbench 中，点击项目旁边的三个点
2. 选择 "Delete Project"（删除项目）
3. 确认删除

> [!NOTE]
> 所有更改都包含在 AI Workbench 内。AI Workbench 环境外没有进行系统级修改。

## 步骤 11. 下一步

你还可以使用代理 RAG 系统探索更高级的功能和开发选项：

* 修改项目代码中的组件提示
* 上传不同的文档以测试路由和自定义
* 尝试不同类型的查询和复杂级别
* 在 "Monitor"（监控）选项卡中查看代理推理日志以了解决策过程

考虑自定义 Gradio UI 或将代理 RAG 组件集成到你自己的项目中。

---

## 故障排除

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| Tavily API 错误 | 互联网连接或 DNS 问题 | 等待后重试查询 |
| 401 未授权 | 密钥错误或格式错误 | 在项目密钥中替换密钥并重启 |
| 403 未授权 | API 密钥缺少权限 | 生成具有适当访问权限的新密钥 |
| 代理循环超时 | 复杂查询超过时间限制 | 尝试更简单的查询或重试 |

有关最新的已知问题，请查看 [DGX Spark 用户指南](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)。
