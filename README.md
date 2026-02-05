<div align="center">
  <img src="https://gitee.com/OpenClaw-CN/openclaw-website/raw/master/docs/public/logo.png" width="200" alt="OpenClaw CN Logo">
  <h1>OpenClaw 中国社区 (CN)</h1>
  <p>
    <b> 🦞 你的私人 AI 助手 (Personal AI Assistant)</b>
  </p>
  <p>
    <code>Based on OpenClaw v2026.2.2</code>
  </p>
  <p>
    更安全 · 更懂中文 · 适配 DeepSeek 的 Local Agent 基础设施
  </p>
  <p>
    <a href="https://open-claw.org.cn">🌐 官方文档</a> • 
    <a href="./README_EN.md">English README</a>
  </p>
</div>

> **OpenClaw CN (中国社区版)** 是 OpenClaw 的本地化维护版本，针对国内网络环境进行了深度优化，**源码级原生支持** DeepSeek/Qwen 等国产大模型，致力于让中国开发者拥有最顺滑的 Agent 开发体验。

---

## 🇨🇳 社区版特性 (Features)

本项目是 OpenClaw (原Clawdbot) 的**中国本土化维护版本**，针对国内网络与使用习惯进行了深度优化：

* 🧠 **国产大脑**：源码内置 **DeepSeek-V3** / **Qwen** 支持，开箱即用，告别昂贵的 Claude。
* 🛡️ **安全审计**：代码经社区人工审计，剔除潜在风险与不必要的遥测。
* ⚡ **极速下载**：预配置 pnpm 国内镜像源，安装依赖“飞”一般的感觉。
* 🔌 **生态落地**：正在开发飞书 (Feishu)、企业微信连接器。

## 🚀 快速开始 (Quick Start)

请访问我们的文档站查看保姆级教程：
👉 **[https://open-claw.org.cn/guide/getting-started](https://open-claw.org.cn/guide/getting-started)**

---

## ⚡️ 源码安装与开发 (中国网络优化)

为了确保在国内网络环境下依赖能快速下载，我们**强制推荐**使用 `pnpm` 并配置国内镜像源。

### 1. 准备环境
确保你的 Node.js 版本 `≥22`。如果未安装 pnpm，请运行：
```bash
npm install -g pnpm
```

### 2. 配置国内高速镜像 (关键步骤)
在开始安装前，请务必设置 pnpm 的镜像源，否则下载速度会很慢：
```bash
# 设置淘宝/阿里云镜像
pnpm config set registry https://registry.npmmirror.com/
```

### 3. 安装与启动
```bash
# 1. 克隆仓库
git clone https://gitee.com/OpenClaw-CN/openclaw-cn.git
cd openclaw-cn

# 1.1 选择已发布版本分支，例如：v2026.2.2-cn
git tag
git checkout v2026.2.2-cn

# 1.2 保持当前分支：master

# 2. 安装依赖 (速度飞快 🚀)
pnpm install

# 3. 首次构建 UI 依赖
pnpm ui:build

# 4. 构建项目
pnpm build

# 5. 启动初始化向导
pnpm openclaw onboard --install-daemon

# 6. 使用初始化向导安装完毕后，再次启动网关（关闭后再次启动）
node openclaw.mjs gateway --port 18789 --verbose

# 6.1 再次启动网关后，如何再次打开管理页面（管理页面已关闭的前提下）
node openclaw.mjs dashboard
```

> **💡 开发模式**: 如果你想修改源码并实时预览，请使用 `pnpm gateway:watch` 启动。

---

## 🧠 模型配置 (DeepSeek 原生支持)

得益于 OpenClaw CN 的源码改造，DeepSeek 已成为系统的一级公民，配置极其简单。

### 方法一：通过向导配置 (最推荐)
在运行 `pnpm openclaw onboard` 时：

1.  **Select Provider**: 在列表中直接选择 👉 **`DeepSeek (Recommended for CN)`**
2.  **API Key**: 输入您的 DeepSeek Key (`sk-xxxxxxxx`)。
3.  **Model**: 系统会自动为您配置 `deepseek-chat` (V3) 为默认模型。

### 方法二：手动修改配置文件
如果您需要手动干预配置，请修改 `~/.openclaw/openclaw.json`。得益于原生集成，您只需关注 `auth` 和 `agents` 部分：

```json
{
  "auth": {
    "profiles": {
      "deepseek:default": {
        "provider": "deepseek",
        "mode": "api_key",
        "apiKey": "sk-你的Key"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "deepseek/deepseek-chat"
      }
    }
  }
}
```

> **注意**：无需再手动配置 `baseUrl`，系统源码已内置 DeepSeek 官方节点 (`https://api.deepseek.com`)。

---

## 🤝 参与贡献 (Contributing)

OpenClaw CN 是一个纯粹的、由开发者驱动的开源项目。

**🚫 我们暂时不接受任何形式的资金捐赠 (No Donations Needed)。**

我们相信，对于现阶段的社区而言，资金并不是瓶颈。**一行高质量的代码、一个完善的文档 PR、或者一次详尽的 Bug 报告，比金钱更有价值。**

我们需要你：
1.  **代码贡献**：特别是 **飞书/钉钉连接器**、**中文搜索增强** 等本地化插件的开发。
2.  **文档完善**：帮助我们将更多英文文档翻译为中文，或撰写实战教程。
3.  **测试反馈**：在 Windows/Mac/Linux 不同环境下测试 DeepSeek 的表现并提交 Issue。

👉 **查看详细贡献指南**: [https://open-claw.org.cn/plugins/contribution](https://open-claw.org.cn/plugins/contribution)

---

## ⚠️ 免责声明

本项目基于 [OpenClaw Official](https://github.com/openclaw/openclaw) 构建。
原项目版权归原作者所有，遵循 MIT 协议。我们致力于让优秀的开源项目在中国更好地落地。

---
<div align="center">
  <sub>OpenClaw-CN Community © 2026</sub>
</div>