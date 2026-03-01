---
summary: "Configure DeepSeek native API (deepseek-chat and deepseek-reasoner)"
read_when:
  - You want to use DeepSeek V3.2 via the official API
  - You need DEEPSEEK_API_KEY and model refs (deepseek/deepseek-chat, deepseek/deepseek-reasoner)
title: "DeepSeek"
---

# DeepSeek (native API)

OpenClaw supports the **DeepSeek API** natively. The API is OpenAI-compatible (`https://api.deepseek.com`). You can use `deepseek-chat` (V3.2, non-thinking) or `deepseek-reasoner` (V3.2, thinking mode).

Model details and pricing: [Models & pricing](https://api-docs.deepseek.com/zh-cn/quick_start/pricing).

## Quick start

**Interactive:**

```bash
openclaw onboard --auth-choice deepseek-api-key
```

**Non-interactive:**

```bash
openclaw onboard --non-interactive --accept-risk --auth-choice deepseek-api-key --deepseek-api-key "sk-..."
```

Or set the environment variable and run onboard; the wizard will offer to reuse `DEEPSEEK_API_KEY`.

## Environment variable

- `DEEPSEEK_API_KEY` — Your API key from [DeepSeek Platform](https://platform.deepseek.com).

## Model refs

- `deepseek/deepseek-chat` — DeepSeek V3.2 (non-thinking), 128K context, default 4K / max 8K output.
- `deepseek/deepseek-reasoner` — DeepSeek V3.2 (thinking mode), 128K context, default 32K / max 64K output.

Default primary model after onboarding: `deepseek/deepseek-chat`.

## Config snippet

```json5
{
  env: { DEEPSEEK_API_KEY: "sk-..." },
  agents: {
    defaults: {
      model: { primary: "deepseek/deepseek-chat" },
      models: {
        "deepseek/deepseek-chat": { alias: "DeepSeek V3.2 (Chat)" },
        "deepseek/deepseek-reasoner": { alias: "DeepSeek V3.2 (Reasoner)" },
      },
    },
  },
  models: {
    mode: "merge",
    providers: {
      deepseek: {
        baseUrl: "https://api.deepseek.com",
        apiKey: "${DEEPSEEK_API_KEY}",
        api: "openai-completions",
        models: [
          {
            id: "deepseek-chat",
            name: "DeepSeek V3.2 (Chat)",
            reasoning: false,
            input: ["text"],
            contextWindow: 128000,
            maxTokens: 8192,
          },
          {
            id: "deepseek-reasoner",
            name: "DeepSeek V3.2 (Reasoner)",
            reasoning: true,
            input: ["text"],
            contextWindow: 128000,
            maxTokens: 65536,
          },
        ],
      },
    },
  },
}
```

Credentials can also be stored in the auth profile store (e.g. after `openclaw onboard`); then `apiKey` may be omitted in `models.providers.deepseek` if the key is resolved from the store.
