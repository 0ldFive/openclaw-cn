# PR: Gateway Dashboard 简体中文与配置页多级汉化 / Gateway Dashboard Simplified Chinese & Config Multi-Level i18n

---

## 中文版

### 摘要

- **问题**：Gateway Dashboard 部分界面与配置页二级/三级仍为英文，中文用户希望完整汉化。
- **范围**：在现有 i18n 框架上扩展：顶栏语言切换、配置区块与字段级翻译键、简体中文文案补全与配置第三级（字段）汉化机制。
- **未改动**：未改网关协议、API、或后端逻辑；仅前端 UI 与 locale 文案及取用方式。

### 修改架构

#### 1. 现有 i18n 架构（沿用）

- **文案来源**：`ui/src/i18n/locales/` 下按语种分文件（`en.ts`, `zh-CN.ts`, `zh-TW.ts`, `pt-BR.ts`），每个导出 `TranslationMap`。
- **运行时**：`ui/src/i18n/lib/translate.ts` 中的 `I18nManager` 单例提供 `t(key)`、`setLocale(locale)`、`getLocale()`；非英文语种按需动态加载对应 locale 模块。
- **与视图联动**：`I18nController`（`lit-controller.ts`）在 locale 变更时通知宿主组件 `requestUpdate()`，保证切换语言后界面重绘。
- **键约定**：点分路径，如 `config.subsections.broadcast`、`tabs.channels`，对应嵌套对象。

#### 2. 本次新增/扩展的架构

- **顶栏语言切换**：在 shell 顶栏（`app-render.ts`）增加语言下拉框，调用 `i18n.setLocale()` 并 `applySettings({ locale })`，语言选择持久化到现有 `openclaw.control.settings.v1`。
- **配置二级**：左侧 section 列表与区块卡片标题/描述优先使用 `config.subsections.<key>` / `config.subsections.<key>Desc`；对 schema 中存在但不在固定 SECTIONS 列表中的“额外”区块，也尝试 `config.subsections.<key>`，缺失时回退到 `humanize(key)` 或 schema。
- **配置三级（字段级）**：新增命名空间 `config.fields`，按**配置路径**生成键：`config.fields.<section>.<subsection>` 为标题，`config.fields.<section>.<subsection>Desc` 为说明。表单在解析字段 meta 时优先使用该翻译，无则用 schema 的 `title`/`description`。

### 修改内容详列

#### A. 顶栏语言切换

| 文件 | 修改说明 |
|------|----------|
| `ui/src/ui/app-render.helpers.ts` | 新增 `renderLanguageSelect(state)`：顶栏下拉框，选项为 en / zh-CN / zh-TW / pt-BR，`@change` 时调用 `i18n.setLocale(v)` 与 `state.applySettings({ ...state.settings, locale: v })`。 |
| `ui/src/ui/app-render.ts` | 在 topbar 中引入并渲染 `renderLanguageSelect(state)`（位于“健康状况”与主题切换之间）。 |
| `ui/src/styles/layout.css` | 为 `.topbar-status .lang-select__select` 增加样式（高度、内边距、圆角、边框、背景/前景变量），与现有 pill/theme-toggle 风格一致。 |

#### B. 配置页二级汉化（区块列表与卡片）

| 文件 | 修改说明 |
|------|----------|
| `ui/src/i18n/locales/zh-CN.ts` | 在 `config.subsections` 中补全与 `SECTION_META` 一致的键：`env`、`update`、`agents`、`auth`、`channels`、`messages`、`commands`、`hooks`、`skills`、`tools`、`gateway`、`wizard` 及其对应 `*Desc`，保证所有 section 卡片标题与描述可被翻译。 |
| `ui/src/ui/views/config.ts` | ① `extraSections` 改为使用 `labelKey: "config.subsections." + k`，便于未在 SECTIONS 列表中的 schema 区块（如 broadcast、audio、plugins）也走 i18n。② `sectionDisplayLabel` 在存在 `labelKey` 时先 `t(labelKey)`，若返回值等于 key 则回退到 `section.label ?? humanize(section.key)`。③ 新增 `subsectionDisplayDesc(key, fallback)`，与既有 `subsectionDisplayLabel` 一致地回退。④ 顶部 hero 的标题与描述改为优先使用 `subsectionDisplayLabel` / `subsectionDisplayDesc`（含对 `config.subsections.*` 的尝试），再回退到 `activeSectionMeta`。 |

#### C. 配置页三级汉化（字段标题与说明）

| 文件 | 修改说明 |
|------|----------|
| `ui/src/ui/views/config-form.node.ts` | 在 `resolveFieldMeta()` 中：根据 `path` 生成 `pathKey`（仅保留字符串段并 `join(".")`），尝试 `t("config.fields." + pathKey)` 与 `t("config.fields." + pathKey + "Desc")`；若返回值不等于键本身则用作 `label`/`help`，否则仍用 `hint ?? schema.title ?? humanize(...)` 与 `hint ?? schema.description`。 |
| `ui/src/ui/views/config-form.render.ts` | ① 新增 `getFieldLabel(sectionKey, subsectionKey, fallback)` 与 `getFieldDesc(sectionKey, subsectionKey, fallback)`，内部使用 `config.fields.<section>.<subsection>` 与 `...Desc`，缺失时返回 fallback。② 在“subsection 单卡片”分支中，卡片标题与描述改为先调用上述两函数（fallback 为原有 section meta / node.title / node.description），使插件等子区块的卡片标题与说明可汉化。 |
| `ui/src/i18n/locales/zh-CN.ts` | 在 `config` 下新增 `fields.plugins`：`allowlist`、`denylist`、`enablePlugins`、`entries`、`installRecords`、`loader`、`slots` 及各键的 `*Desc`，对应“插件白名单”“启用插件”等标题与说明。 |
| `ui/src/i18n/locales/en.ts` | 同步增加 `config.fields.plugins` 的英文条目，保持键一致、便于维护与回退。 |

### 涉及文件清单

- `ui/src/i18n/locales/zh-CN.ts` — 补全 subsections，新增 fields.plugins
- `ui/src/i18n/locales/en.ts` — 新增 config.fields.plugins
- `ui/src/ui/views/config.ts` — 二级列表/hero 使用 subsections 与 subsectionDisplayDesc
- `ui/src/ui/views/config-form.render.ts` — getFieldLabel/getFieldDesc，subsection 卡片用 fields
- `ui/src/ui/views/config-form.node.ts` — resolveFieldMeta 中 config.fields 查找
- `ui/src/ui/app-render.helpers.ts` — renderLanguageSelect
- `ui/src/ui/app-render.ts` — 顶栏挂载语言选择器
- `ui/src/styles/layout.css` — .lang-select__select 样式

### 验证建议

1. 本仓库执行 `pnpm ui:build`，使用本仓库启动网关（如 `node openclaw.mjs gateway --port 18789`）。
2. 打开 Dashboard，在顶栏将语言选为「简体中文」。
3. 检查：侧栏、概览、配置等页的导航与标题为中文；配置页左侧区块列表（如 广播、音频、媒体、插件 等）及顶部 hero 为中文。
4. 进入 配置 → 插件：子区块卡片（如 启用插件、插件白名单）及字段标题/说明为中文。
5. 切换回 English，确认英文显示正常且无缺失键导致的占位符。

---

## English Version

### Summary

- **Problem**: Parts of the Gateway Dashboard and the second- and third-level content of the Config page remained in English; users requested full Simplified Chinese support.
- **Scope**: Extend the existing i18n setup: topbar language switcher, config section- and field-level translation keys, completion of zh-CN copy, and a mechanism for third-level (field) translations.
- **Out of scope**: No changes to gateway protocol, API, or backend logic; only front-end UI and locale copy and how it is consumed.

### Architecture of Changes

#### 1. Existing i18n (unchanged)

- **Copy**: Locale files under `ui/src/i18n/locales/` (e.g. `en.ts`, `zh-CN.ts`) export a `TranslationMap` per locale.
- **Runtime**: `I18nManager` in `ui/src/i18n/lib/translate.ts` provides `t(key)`, `setLocale(locale)`, `getLocale()`; non-English locales are loaded on demand.
- **Reactivity**: `I18nController` triggers `requestUpdate()` on locale change so the UI re-renders.
- **Keys**: Dot-separated paths (e.g. `config.subsections.broadcast`, `tabs.channels`) over nested objects.

#### 2. Additions in this PR

- **Topbar language switcher**: A dropdown in the shell topbar that calls `i18n.setLocale()` and persists the choice via `applySettings({ locale })` (stored in `openclaw.control.settings.v1`).
- **Config second level**: Section list and section card titles/descriptions prefer `config.subsections.<key>` and `config.subsections.<key>Desc`. “Extra” sections (present in schema but not in the fixed SECTIONS list) also use `config.subsections.<key>` with fallback to `humanize(key)` or schema.
- **Config third level (field-level)**: New namespace `config.fields` keyed by **config path**: `config.fields.<section>.<subsection>` for labels and `config.fields.<section>.<subsection>Desc` for descriptions. The form’s field meta resolution uses these when present, otherwise schema `title`/`description`.

### Detailed Changes

#### A. Topbar language switcher

| File | Change |
|------|--------|
| `ui/src/ui/app-render.helpers.ts` | Add `renderLanguageSelect(state)`: topbar dropdown for en / zh-CN / zh-TW / pt-BR; on change call `i18n.setLocale(v)` and `state.applySettings({ ...state.settings, locale: v })`. |
| `ui/src/ui/app-render.ts` | Render `renderLanguageSelect(state)` in the topbar (between health pill and theme toggle). |
| `ui/src/styles/layout.css` | Style `.topbar-status .lang-select__select` (height, padding, radius, border, CSS vars) to match existing pill/theme-toggle. |

#### B. Config second-level (section list and cards)

| File | Change |
|------|--------|
| `ui/src/i18n/locales/zh-CN.ts` | In `config.subsections`, add keys aligned with `SECTION_META`: `env`, `update`, `agents`, `auth`, `channels`, `messages`, `commands`, `hooks`, `skills`, `tools`, `gateway`, `wizard` and their `*Desc`. |
| `ui/src/ui/views/config.ts` | ① `extraSections` now use `labelKey: "config.subsections." + k` so schema-only sections (e.g. broadcast, audio, plugins) use i18n. ② `sectionDisplayLabel` uses `t(labelKey)` when present and falls back to `section.label ?? humanize(section.key)` when the result equals the key. ③ Add `subsectionDisplayDesc(key, fallback)`. ④ Hero title and description use `subsectionDisplayLabel` / `subsectionDisplayDesc` with fallback to `activeSectionMeta`. |

#### C. Config third-level (field labels and descriptions)

| File | Change |
|------|--------|
| `ui/src/ui/views/config-form.node.ts` | In `resolveFieldMeta()`: build `pathKey` from `path` (string segments only, joined by `.`); try `t("config.fields." + pathKey)` and `t("config.fields." + pathKey + "Desc")`; use as `label`/`help` when the result is not the key itself, else keep `hint ?? schema.title ?? humanize(...)` and `hint ?? schema.description`. |
| `ui/src/ui/views/config-form.render.ts` | ① Add `getFieldLabel(sectionKey, subsectionKey, fallback)` and `getFieldDesc(sectionKey, subsectionKey, fallback)` using `config.fields.<section>.<subsection>` and `...Desc`. ② In the single-subsection card branch, use these for card title and description (fallback to existing section meta / node.title / node.description). |
| `ui/src/i18n/locales/zh-CN.ts` | Under `config` add `fields.plugins`: `allowlist`, `denylist`, `enablePlugins`, `entries`, `installRecords`, `loader`, `slots` and their `*Desc` (e.g. “插件白名单”, “启用插件”). |
| `ui/src/i18n/locales/en.ts` | Add the same `config.fields.plugins` keys in English for consistency. |

### Files touched

- `ui/src/i18n/locales/zh-CN.ts` — subsections completion, `config.fields.plugins`
- `ui/src/i18n/locales/en.ts` — `config.fields.plugins`
- `ui/src/ui/views/config.ts` — second-level list/hero using subsections and subsectionDisplayDesc
- `ui/src/ui/views/config-form.render.ts` — getFieldLabel/getFieldDesc, subsection card uses fields
- `ui/src/ui/views/config-form.node.ts` — config.fields lookup in resolveFieldMeta
- `ui/src/ui/app-render.helpers.ts` — renderLanguageSelect
- `ui/src/ui/app-render.ts` — topbar language selector
- `ui/src/styles/layout.css` — .lang-select__select styles

### Verification

1. Run `pnpm ui:build` in the repo and start the gateway from this repo (e.g. `node openclaw.mjs gateway --port 18789`).
2. Open the dashboard and set the topbar language to “简体中文 (Simplified Chinese)”.
3. Confirm: nav, overview, config tabs and titles in Chinese; config left-hand section list (e.g. 广播, 音频, 媒体, 插件) and hero in Chinese.
4. Open Config → Plugins: subsection cards (e.g. 启用插件, 插件白名单) and field labels/descriptions in Chinese.
5. Switch back to English and confirm no missing keys or raw key placeholders.

---

*This document can be used as the PR description body (use either the Chinese or English section, or both).*
