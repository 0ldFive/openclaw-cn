/**
 * CLI i18n: resolve locale from OPENCLAW_LANG or LANG and return translated string.
 * Use getText(key, fallbackEn, params?) so upstream can stay English-only;
 * zh-CN bundle is maintained separately for easy merge.
 */

export type CliLocale = "en" | "zh-CN";

let cachedLocale: CliLocale | null = null;

export function resolveCliLocale(): CliLocale {
  if (cachedLocale !== null) {
    return cachedLocale;
  }
  const raw =
    process.env.OPENCLAW_LANG?.trim() ||
    process.env.LANG?.trim() ||
    process.env.LC_ALL?.trim() ||
    "";
  const lower = raw.toLowerCase();
  if (lower.startsWith("zh_cn") || lower.startsWith("zh-cn") || lower === "zh") {
    cachedLocale = "zh-CN";
    return "zh-CN";
  }
  if (lower.startsWith("zh_tw") || lower.startsWith("zh-tw")) {
    // Keep English for zh-TW unless we add a bundle later
    cachedLocale = "en";
    return "en";
  }
  cachedLocale = "en";
  return "en";
}

function interpolate(template: string, params?: Record<string, string>): string {
  if (!params) {
    return template;
  }
  return template.replace(/\{(\w+)\}/g, (_, k) => params[k] ?? `{${k}}`);
}

/** zh-CN CLI strings (onboarding, wizard, etc.). Key = getText key. */
const ZH_CN: Record<string, string> = {
  "onboarding.intro": "OpenClaw 初始化向导",
  "onboarding.risk.title": "安全",
  "onboarding.risk.body": [
    "安全提示 — 请阅读。",
    "",
    "OpenClaw 为兴趣项目，目前仍为 beta 版本，可能存在不完善之处。",
    "启用工具后，本机器人可读取文件并执行操作。恶意提示可能诱导其执行危险操作。",
    "",
    "若您不熟悉基本安全与访问控制，请勿运行 OpenClaw。",
    "在启用工具或对外暴露前，建议请有经验者协助。",
    "",
    "建议基线：",
    "- 配对/白名单 + 提及门控。",
    "- 沙箱 + 最小权限工具。",
    "- 勿将密钥放在代理可访问的文件系统中。",
    "- 对具备工具或不可信收件箱的机器人使用当前最强模型。",
    "",
    "请定期执行：",
    "openclaw security audit --deep",
    "openclaw security audit --fix",
    "",
    "必读：https://docs.openclaw.ai/gateway/security",
  ].join("\n"),
  "onboarding.risk.continue": "我理解其功能强大且存在固有风险。是否继续？",
  "onboarding.config.invalid.title": "配置无效",
  "onboarding.config.issues.title": "配置问题",
  "onboarding.config.outro": "配置无效。请先执行 `{command}` 修复后再重新运行初始化。",
  "onboarding.flow.message": "初始化模式",
  "onboarding.flow.quickstart": "快速开始",
  "onboarding.flow.quickstart.hint": "后续可通过 {command} 配置细节。",
  "onboarding.flow.manual": "手动",
  "onboarding.flow.manual.hint": "配置端口、网络、Tailscale 与认证等。",
  "onboarding.flow.invalid": "无效的 --flow（请使用 quickstart、manual 或 advanced）。",
  "onboarding.quickstart.remote_switch": "快速开始仅支持本地网关，已切换为手动模式。",
  "onboarding.existing.title": "检测到已有配置",
  "onboarding.config_handling.message": "配置处理方式",
  "onboarding.config_handling.keep": "沿用现有值",
  "onboarding.config_handling.modify": "更新数值",
  "onboarding.config_handling.reset": "重置",
  "onboarding.reset_scope.message": "重置范围",
  "onboarding.reset_scope.config": "仅配置",
  "onboarding.reset_scope.config_creds_sessions": "配置 + 凭据 + 会话",
  "onboarding.reset_scope.full": "完全重置（配置 + 凭据 + 会话 + 工作区）",
  "onboarding.helpers.setup_cancelled": "初始化已取消。",
  "onboarding.helpers.no_settings": "未检测到关键设置。",
  "onboarding.helpers.gateway.port": "网关端口",
  "onboarding.helpers.gateway.mode": "网关模式",
  "onboarding.helpers.gateway.bind": "网关绑定",
  "onboarding.helpers.gateway.remote.url": "远程网关 URL",
};

/**
 * Return translated string for key when locale is zh-CN, otherwise fallbackEn.
 * params are used to replace {name} placeholders in the string.
 */
export function getText(
  key: string,
  fallbackEn: string,
  params?: Record<string, string>,
): string {
  const locale = resolveCliLocale();
  if (locale === "en") {
    return interpolate(fallbackEn, params);
  }
  const value = ZH_CN[key];
  if (typeof value === "string") {
    return interpolate(value, params);
  }
  return interpolate(fallbackEn, params);
}
