# OpenClaw 汉化方案（zh-CN 中文本地化）

本文档说明如何对 OpenClaw 的**启动初始化向导**、**Gateway 管理面板（Dashboard）**及相关界面进行汉化，并兼顾**版本升级友好**与**运行稳定**。

---

## 一、现状概览

### 1.1 各模块文案与 i18n 情况

| 模块 | 位置 | 当前语言 | 是否已有 i18n | 说明 |
|------|------|----------|----------------|------|
| **CLI 初始化向导** | `src/wizard/`, `src/commands/onboard*.ts`, `src/commands/onboard-helpers.ts` | 英文硬编码 | 否 | `pnpm openclaw onboard` 全部英文 |
| **Gateway Dashboard（Web UI）** | `ui/src/` | 英文 + 部分 t() | 是 | 已有 `ui/src/i18n/locales/en.ts`、`zh-CN.ts` 等，按 `navigator.language` 选 zh-CN |
| **macOS 应用（含 Onboarding）** | `apps/macos/Sources/OpenClaw/` | 英文硬编码 | 否 | 无 `Localizable.strings`，Swift 内联 `Text("...")` |
| **iOS 应用** | `apps/ios/Sources/` | 英文硬编码 | 否 | 同上 |
| **文档** | `docs/`, `docs/zh-CN/` | 英文 + 生成 zh-CN | 有流程 | 按 AGENTS.md 的 docs i18n 流程，不在此汉化范围内 |

### 1.2 Dashboard 已有 zh-CN 行为

- **语言解析**：`ui/src/i18n/lib/translate.ts` 中 `resolveInitialLocale()` 已根据 `navigator.language` 将 `zh`、`zh-CN` 等解析为 `zh-CN`，将 `zh-TW`、`zh-HK` 解析为 `zh-TW`。
- **已翻译键**：`zh-CN.ts` 与 `en.ts` 结构一致，覆盖 `common`、`nav`、`tabs`、`subtitles`、`overview`、`chat`、`languages` 等，Overview 页与侧栏等已用 `t()` 的文案在中文环境下会显示中文。
- **未走 i18n 的硬编码**：Config 配置页的 SECTIONS 标签（如 "Environment"、"Setup Wizard"）、会话/主题等处的部分 fallback 文案（如 "Main Session"、"Subagent:"、"Theme"）仍为英文，需改为使用 `t()` 并补全 zh-CN 键。

---

## 二、汉化范围与优先级

1. **CLI 初始化向导**（`pnpm openclaw onboard`）  
   - 引导语、选项说明、错误提示、确认句等全部改为在“中文环境”下输出中文。  
   - 涉及：`src/wizard/onboarding.ts`、`onboarding.finalize.ts`、`onboarding.gateway-config.ts`、`onboarding.completion.ts`、`src/commands/onboard-helpers.ts`、`onboard-channels.ts`、各 channel 的 onboarding（whatsapp、telegram、slack 等）、以及 doctor/configure 中与向导相关的提示。

2. **Gateway 管理面板（Dashboard）**  
   - 菜单、按钮、状态描述、配置节名称、会话/主题等 UI 文案为准确、通顺的中文。  
   - 涉及：补全并统一使用 `t()`，消除 Config、会话列表、主题切换等处的硬编码英文；保证 zh-CN 与 en 键一致且无缺键。

3. **macOS / iOS 原生界面（可选或分阶段）**  
   - 欢迎页、Onboarding 向导、设置项、菜单等。  
   - 涉及：Swift 中使用 `String(localized:)` 或等价方式，并增加 `zh-Hans.lproj/Localizable.strings`；或先做 CLI + Dashboard，再迭代 App。

---

## 三、升级策略（如何适配原版持续更新）

目标：**汉化要能适用每个版本的更新，且升级成本最低**。

### 3.1 推荐：以“键 + 英文默认 + 中文包”为主，少改逻辑

- **CLI**  
  - 在仓库内增加**一层薄 i18n**：  
    - 环境变量或配置：如 `OPENCLAW_LANG=zh-CN` 或沿用 `LANG`（仅当为 `zh*` 时启用中文）。  
    - 代码中**不直接写死中文**，而是调用 `getText(key)` 或 `t(key)`，默认实现返回英文（与当前硬编码一致）。  
    - 单独维护一份 **zh-CN 文案表**（如 `src/cli/i18n/zh-CN.json` 或 `strings/onboarding-zh-CN.ts`），只包含 key → 中文文案。  
  - 这样：  
    - 上游合并时，**仅新增/修改的 key** 需要补翻或沿用英文；  
    - 冲突集中在“新增 key 的翻译”和“zh-CN 文件”，不会散落在几十个业务文件里，**最容易用 git 做升级**。

- **Dashboard**  
  - 已具备 i18n 与 zh-CN；升级时只需：  
    - 每次合并后对比 `en.ts` 与 `zh-CN.ts` 的 key，**补全 zh-CN 中缺失的键**（可脚本或人工）；  
    - 若上游新增了未用 `t()` 的文案，在合并后一次性改为 `t("new.key")` 并补 en/zh-CN。

- **macOS/iOS**  
  - 若采用系统本地化（`Localizable.strings`）：  
    - 英文在 `Base.lproj` 或 `en.lproj`，中文在 `zh-Hans.lproj`；  
    - 升级时只需合并/更新 `.strings` 与少量 Swift 中新增的 key，**不推荐**在 Swift 里直接写中文，否则每次合并都要改 Swift。

### 3.2 不推荐：每次发版“重新汉化”整份代码

- 若每次从原版拉取后，用脚本或人工把源码里英文字符串全部替换成中文：  
  - 会导致**大量与上游的 diff**，每次合并都要解决冲突，且容易漏改或改错逻辑。  
  - 仅适合“一次性 fork、不打算再跟上游合并”的分支；若希望**容易升级**，不推荐这种方式。

### 3.3 小结

- **最容易升级的方式**：  
  - CLI：薄 i18n 层 + 单一 zh-CN 文案文件，业务代码只认 key。  
  - Dashboard：保持现有 i18n，合并后补全 zh-CN 键、把新增英文改为 `t()`。  
  - App：用系统本地化 + `.strings`，不在源码里写中文。  
- 这样每次上游更新后，只需：**合并 → 对照 en 补 zh-CN 键 → 跑测试**，无需整库“重新汉化”。

---

## 四、保证汉化后运行正常

1. **不改变逻辑与类型**  
   - 只做字符串替换或通过 key 查表返回字符串；不修改控制流、配置键名、API 契约。  
   - CLI 的 key 与现有英文一一对应，避免 key 拼写错误导致未定义。

2. **CLI 测试**  
   - 保留并跑通现有 `src/wizard/onboarding.test.ts`、`onboarding.completion.test.ts` 等；mock 的 prompter 仍按“英文”断言可改为对 key 或对“当前语言”的预期。  
   - 建议增加：在 `OPENCLAW_LANG=zh-CN` 下跑一次 onboard 的 smoke（或 E2E），仅验证“无报错、关键步骤有中文输出”。

3. **Dashboard 测试**  
   - 已有 `ui/src/i18n/test/translate.test.ts`；合并后确保 zh-CN 加载与 fallback 正常。  
   - 手动或自动化：在浏览器语言为 zh-CN 时打开 Dashboard，检查侧栏、Overview、Config、Chat 等无缺键、无乱码、无布局溢出。

4. **UI 布局**  
   - 中文略长于英文的按钮/标签需检查：  
     - 使用 `min-width`、`flex`、`text-overflow: ellipsis` 等，避免溢出或挤坏布局；  
     - 必要时在 zh-CN 中适当缩短文案以保证同一布局下正常显示。

5. **文档与链接**  
   - 汉化后的提示中若包含链接（如 docs.openclaw.ai），保持 URL 不变；仅展示文案可翻译为“文档”等。

---

## 五、验收标准

在“中文环境”下（CLI：`OPENCLAW_LANG=zh-CN` 或 `LANG=zh_CN.UTF-8`；Dashboard：浏览器语言为 zh-CN），需满足：

1. **启动初始化向导（`pnpm openclaw onboard`）**  
   - 引导语、步骤说明、选项（如 QuickStart / Manual）、风险确认、配置说明等均为**中文**。  
   - 错误提示（如配置无效、Tailscale 警告等）为**中文**。  
   - 不影响现有交互流程与退出码。

2. **Gateway 管理面板（Dashboard）**  
   - 侧栏菜单、各 Tab（概览、频道、实例、会话、使用情况、定时任务、技能、节点、聊天、配置、调试、日志）及副标题为**准确、通顺的中文**。  
   - 概览页：网关访问、快照、统计、备注、连接/刷新按钮、语言选择等为**中文**。  
   - 配置页：节名称（环境、更新、代理、认证、频道、消息、命令、钩子、技能、工具、网关、设置向导）等为**中文**。  
   - 会话列表、主题切换（系统/浅色/深色）等已有或新增的 UI 文案为**中文**（或通过 t() 从 zh-CN 取值）。

3. **UI 布局与稳定性**  
   - 中文环境下**不乱码、不溢出**；按钮和标签在合理宽度内换行或省略。  
   - 所有使用 `t()` 的键在 zh-CN 中均有定义，或明确 fallback 到英文，**不出现 raw key 暴露给用户**。

4. **升级与回归**  
   - 合并上游后，按本文“升级策略”补全 zh-CN 即可恢复完整汉化；**不要求**修改上游核心逻辑。  
   - `pnpm test`（含 wizard/onboarding 相关）、Dashboard 相关测试通过；`pnpm openclaw onboard` 在 zh-CN 下可走通关键路径。

（若后续增加 macOS/iOS 汉化，可在此补充“App 欢迎页与 Onboarding 为中文”等验收项。）

---

## 六、实施顺序建议

1. **Phase 1：Dashboard 补全**  
   - 为 Config 的 SECTIONS、会话 fallback（Main Session、Subagent、Cron 等）、主题切换等增加 i18n 键并补全 `zh-CN.ts`；  
   - 将仍硬编码的英文改为 `t(...)`；  
   - 验证浏览器 zh-CN 下全页无缺键、布局正常。

2. **Phase 2：CLI 薄 i18n + 中文向导**  
   - 引入 `OPENCLAW_LANG`（或 LANG 解析）和 `getText(key)`，默认返回当前英文；  
   - 新增 `zh-CN` 文案表，覆盖 onboarding、onboard-helpers、finalize、gateway-config、completion、onboard-channels 及主要 channel onboarding 的提示；  
   - 将上述模块中的用户可见字符串改为 `getText("key")`；  
   - 跑通现有 wizard 测试并做一次 zh-CN 下的 onboard smoke。

3. **Phase 3（可选）：macOS/iOS**  
   - 增加 `Localizable.strings`（en + zh-Hans），Swift 使用 `String(localized:)` 等；  
   - 先覆盖 Onboarding、欢迎页、设置入口等高频界面。

---

## 七、关键文件索引（便于查找与补翻）

- **CLI 向导入口与帮助**  
  - `src/cli/i18n.ts`：CLI 薄 i18n 层，`resolveCliLocale()`（读 `OPENCLAW_LANG` 或 `LANG`）、`getText(key, fallbackEn, params?)`，内联 zh-CN 文案。  
  - `src/wizard/onboarding.ts`：已接入 `getText`（风险提示、intro、配置无效、流程选择、重置范围等）。  
  - `src/commands/onboard-helpers.ts`：`guardCancel`、`summarizeExistingConfig` 的“初始化已取消”“未检测到关键设置”已接入 `getText`。  
  - `src/wizard/onboarding.finalize.ts`  
  - `src/wizard/onboarding.gateway-config.ts`  
  - `src/wizard/onboarding.completion.ts`  
  - `src/commands/onboard-channels.ts`  
  - `src/channels/plugins/onboarding/*.ts`（whatsapp, telegram, slack, signal, discord, imessage 等）

- **Dashboard i18n**  
  - `ui/src/i18n/lib/translate.ts`（语言解析、t()）  
  - `ui/src/i18n/locales/en.ts`、`zh-CN.ts`  
  - `ui/src/ui/views/overview.ts`（已大量使用 t()）  
  - `ui/src/ui/views/config.ts`（SECTIONS 等需改为 t()）  
  - `ui/src/ui/app-render.helpers.ts`（会话 fallback、主题等需改为 t()）  
  - `ui/src/ui/app-render.ts`（侧栏、版本、健康状态等）

**可选：Dashboard 键一致性**  
升级后可用脚本对比 en 与 zh-CN 的键树，确保 zh-CN 包含 en 的所有键（递归比较对象 key），缺键时输出列表便于补翻。

- **macOS 界面（若做 App 汉化）**  
  - `apps/macos/Sources/OpenClaw/Onboarding.swift`、`OnboardingView+*.swift`  
  - `apps/macos/Sources/OpenClaw/MenuContentView.swift`  
  - `apps/macos/Sources/OpenClaw/ChannelsSettings+View.swift`、`ConfigSettings.swift`  
  - 各 Settings、Alert 的 `messageText` / `informativeText`

---

## 八、总结

- **汉化范围**：CLI 初始化向导 + Gateway Dashboard 全面中文；macOS/iOS 可后续按需做。  
- **升级友好**：CLI 用“键 + 英文默认 + 单独 zh-CN 文件”，Dashboard 保持 i18n 并随上游补全 zh-CN 键；避免在业务代码中直接写死中文，以便 git 合并时冲突最少。  
- **运行稳定**：仅改文案与 i18n 接入，不改逻辑；测试覆盖 wizard 与 Dashboard，并检查中文下的布局与缺键。  
- **验收**：onboard 引导语与 Dashboard 菜单/按钮/状态为准确通顺的中文，UI 无乱码、无溢出，且升级后补全翻译即可保持汉化效果。
