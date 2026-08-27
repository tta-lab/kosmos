# DeepSeek V4 Flash Vision in OpenClaw

Research date: 2026-08-27. This note uses first-party DeepSeek and OpenClaw
sources only.

## Conclusion

`deepseek-v4-flash-vision-exp` is a real DeepSeek model and accepts images as
well as text. It has a 1,000,000-token context window and a 384,000-token
maximum output. It uses DeepSeek's OpenAI-compatible Chat Completions endpoint
at `https://api.deepseek.com`.

The current official OpenClaw DeepSeek plugin does **not** yet statically
declare that model. Updating from the installed `2026.8.1-beta.2` plugin to
the latest beta (`2026.8.1-beta.3`) is sensible, but is not sufficient by
itself: beta.3 still lists only `deepseek-v4-flash` and
`deepseek-v4-pro`, both text-only. An explicit `models.providers.deepseek`
overlay is therefore needed today to make OpenClaw pass image attachments to
the model as native image input.

## Required configuration

Keep the official `@openclaw/deepseek-provider` installed and enabled. Add
this declarative overlay and select its canonical model reference:

```json5
{
  models: {
    // Preserve the plugin's normal catalog entries too.
    mode: "merge",
    providers: {
      deepseek: {
        // Explicit on this host: an empty persisted baseUrl previously made
        // this custom row take OpenAI's default route rather than DeepSeek.
        baseUrl: "https://api.deepseek.com",
        api: "openai-completions",
        models: [
          {
            id: "deepseek-v4-flash-vision-exp",
            name: "DeepSeek V4 Flash Vision Exp",
            reasoning: true,
            input: ["text", "image"],
            contextWindow: 1000000,
            maxTokens: 384000,
          },
        ],
      },
    },
  },
  agents: {
    defaults: {
      model: { primary: "deepseek/deepseek-v4-flash-vision-exp" },
    },
  },
}
```

`id` and `name` are required by OpenClaw's model schema. `input: ["text",
"image"]` is the operative capability declaration: OpenClaw documents that
it lets WebChat and node-origin attachment paths pass images natively instead
of as text-only media references. `reasoning`, context, and max-output values
come from DeepSeek's model table.

The official plugin owns the `deepseek` provider and its normal route is the
same `baseUrl` and `api` shown above. Upstream permits a built-in provider
overlay without repeating them. They are deliberately explicit here because
the existing persisted overlay had an empty `baseUrl` and a real request was
routed to `api.openai.com`; explicit transport settings make the intended
DeepSeek route unambiguous.

Do not add `apiKey` to this model overlay or copy a credential into the
declarative source. The official provider uses `DEEPSEEK_API_KEY`; the gateway
service should continue receiving it through its existing secret injection.

`cost` is not required for routing. DeepSeek publishes separate peak and
off-peak rates for this model, so a single static OpenClaw cost object would
not be an exact billing representation; leave it out unless we choose a
specific accounting policy.

## Plugin boundary and verification

The plugin still gives this model a useful DeepSeek provider route and tool
compatibility. However, its current special V4 thinking profile is hard-coded
to Flash and Pro, not the vision-exp ID. DeepSeek says vision-exp supports
thinking, but that provider-specific OpenClaw behavior is not yet confirmed
for this third ID. The overlay should therefore be verified with a real image
attachment after deployment; do not claim full DeepSeek-thinking integration
until that succeeds or the plugin gains the model upstream.

Minimal observable checks after deployment:

```bash
openclaw models list --provider deepseek
# Expect: deepseek/deepseek-v4-flash-vision-exp ... text+image

# Send an image through the normal OpenClaw channel/UI, then verify the model
# call's endpoint is https://api.deepseek.com/chat/completions and succeeds.
```

## Evidence

- DeepSeek's [first API call guide](https://api-docs.deepseek.com/) names
  `deepseek-v4-flash-vision-exp`, says it accepts image input, and gives the
  OpenAI-compatible base URL. Its [Vision guide](https://api-docs.deepseek.com/guides/vision)
  specifies that the model accepts images alongside text. Its
  [Models & Pricing table](https://api-docs.deepseek.com/quick_start/pricing)
  specifies thinking support, 1M context, 384K maximum output, and the
  peak/off-peak price schedule.
- The official npm registry identifies
  [`@openclaw/deepseek-provider@2026.8.1-beta.3`](https://registry.npmjs.org/@openclaw/deepseek-provider/-/deepseek-provider-2026.8.1-beta.3.tgz)
  as the latest beta available on the research date. Its
  [official manifest at that release](https://github.com/openclaw/openclaw/blob/7ea3a421cde856dd1d0a2b8e8d256926976d7bff/extensions/deepseek/openclaw.plugin.json#L26-L78)
  contains only the two text-only V4 rows; this establishes that a plugin
  upgrade alone cannot supply the vision declaration.
- OpenClaw's [model-provider documentation](https://github.com/openclaw/openclaw/blob/d6752326cc08e4ed9fa94d7ee755f9281f4c6528/docs/concepts/model-providers.md#L324-L334)
  says that explicit `models.providers.<id>.models[]` metadata controls native
  image routing. Its [schema](https://github.com/openclaw/openclaw/blob/7ea3a421cde856dd1d0a2b8e8d256926976d7bff/src/config/zod-schema.core.ts#L394-L439)
  defines the model fields, and marks `deepseek` as a built-in provider
  overlay in the [same schema](https://github.com/openclaw/openclaw/blob/7ea3a421cde856dd1d0a2b8e8d256926976d7bff/src/config/zod-schema.core.ts#L454-L473).
- The plugin's [catalog implementation](https://github.com/openclaw/openclaw/blob/7ea3a421cde856dd1d0a2b8e8d256926976d7bff/extensions/deepseek/provider-catalog.ts)
  establishes the provider's base URL and `openai-completions` transport.
  Its [V4 model-ID set](https://github.com/openclaw/openclaw/blob/7ea3a421cde856dd1d0a2b8e8d256926976d7bff/extensions/deepseek/models.ts#L6-L27)
  shows the present thinking-profile limitation.
