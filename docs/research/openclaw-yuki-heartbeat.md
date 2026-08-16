# Yuki 的 OpenClaw Heartbeat / 主动关怀设计

> 调研日期：2026-08-16
> 目标版本：本机 OpenClaw `2026.8.1-beta.2`，构建提交 `8f382a202ff1e15833394b481615dcdda99b04d7`。
> 范围：研究、写入 `openclaw/openclaw.jsonnet`、清理旧 monitor scratch、部署并验证首轮自然调度。

## 结论

推荐把 heartbeat 设计成“每小时醒来判断一次”，而不是“每小时发一次消息”：

- `every: "1h"`；
- 机械静默窗为 `11:00–23:00`（结束时间不含 23:00），时区显式设为 `Asia/Taipei`；
- 运行上下文固定为 Neil 的 Telegram 私聊 session，而投递仍用 `target: "owner"`；
- `isolatedSession: false`，保留最近对话；
- `lightContext: false`，每次都加载 SOUL/USER/AGENTS；heartbeat 是 Yuki 在同一私聊中醒来，不是临时模仿 Yuki 的独立任务；
- Telegram 隐藏 OK 和状态 indicator，只显示真正的主动消息；
- monitor scratch 原先保存着旧 `HEARTBEAT.md` 的“早安启动仪式”；部署时已用 `--unset` 清除，避免与 07:22 早安 cron 重复；
- 不引入“每次掷 7.2% 骰子”的伪精确概率。当前 OpenClaw heartbeat 配置没有持久化的随机触发率、语义冷却或未回复计数器；最小而可靠的方案是硬时间窗 + busy guard + prompt 的默认沉默、三小时新鲜度和“上一条未回复不追发”规则。

这是一套保守初始值。是否“太冷”或“太黏”应由一周真实样本决定，而不是先堆更多状态机。

## 1. 当前状态的只读核验

### 声明式配置

本次实现前，`openclaw/openclaw.jsonnet` 只有：

```jsonnet
heartbeat: { every: "0m" },
```

即 heartbeat 当时处于禁用状态；本次实现已将其替换为第 5 节的目标配置。

### Gateway 调度状态

只读执行 `openclaw cron list --all --json` 后确认：

- `早安问候`：enabled，`22 7 * * *`，`Asia/Taipei`，session 为 `agent:main:direct:845849177`；
- `Heartbeat (main)`：system-owned monitor，declaration `heartbeat:main`，disabled；
- heartbeat monitor 当前 job id：`a6f61f66-df1f-4eb2-a324-9bc83bac7638`。

只读执行 `openclaw cron scratch <jobId>` 后确认，monitor scratch 仍是整段“startup ritual / 早安”文本。OpenClaw 会把非空 scratch 追加到 heartbeat prompt；因此**只改 `every` 和 prompt 还不够**。

另一个独立风险是：现有早安 cron payload 把“昨晚 00:40”“等香港女生回复”等一次性事实写死在每日重复任务里。heartbeat 方案不会重复晨间问候，但也无法阻止这个 cron 在未来把旧事实说成“昨晚”。在修正该 cron 前，系统整体仍不能完全满足“无 fabricated context”；这不属于 heartbeat 配置本身。

### `HEARTBEAT.md` 已不是启动机制

任务说明中“workspace `HEARTBEAT.md` 在 Gateway 重启时触发启动仪式”的说法与当前版本不符。当前官方文档和源码都明确：runtime 不再读取该文件；`openclaw doctor --fix` 会把它迁入 monitor scratch、备份并移除。当前本机已经存在 `backups/heartbeat-migration/...`，且 scratch 中确实有同样内容。[官方 heartbeat 文档：scratch 与迁移](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md#monitor-scratch-optional)

所以它不是“另一个启动通道”，而是一个已退休、但被重新创建的遗留文件；真正危险的是已经迁入数据库的 scratch。

## 2. OpenClaw 机制：文档与源码核验

### 2.1 配置字段与严格 schema

当前 schema 只接受 `every`、`activeHours`、`model`、`session`、`target`、`directPolicy`、`to`、`accountId`、`prompt`、`timeoutSeconds`、`lightContext`、`isolatedSession`，对象是 strict；不能在 heartbeat block 中自行发明 `probability`、`cooldown`、`maxUnanswered` 或 visibility 字段。[HeartbeatSchema 源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/config/zod-schema.agent-runtime.ts#L72-L148)

`every` 是 duration string，默认单位分钟；`0m` 禁用。默认通常为 30 分钟，但只有未显式设置时，Anthropic OAuth/token 默认才会把它提高到 1 小时。[官方默认值](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md#defaults)

### 2.2 Prompt 与 ACK 抑制

配置的 `prompt` 覆盖默认 prompt，不做合并，并作为 heartbeat 的 user message 使用；runner 还会附上当前时间，非空 monitor scratch 会另行追加。[官方字段说明](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md#field-notes)、[runner prompt 源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/infra/heartbeat-runner-prompt.ts#L212-L292)

静默 contract：

- 无事时只回 `HEARTBEAT_OK`；
- token 在回复开头或末尾才被识别；
- 去掉 token 后，剩余内容不超过 300 字符时整条丢弃；
- token 在中间不特殊处理；
- 真要提醒时不能带 token。

300 字符预算是固定 runtime policy，不是可配置字段。[官方 response contract](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md#response-contract)、[token stripping 源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/auto-reply/heartbeat.ts#L183-L245)

### 2.3 `activeHours` 与时区

`start` inclusive、`end` exclusive；`24:00` 只允许作为 end；相同 start/end 是零宽窗口，永远跳过。跨午夜窗口受支持。[active-hours 源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/infra/heartbeat-active-hours.ts#L12-L122)

时区语义：

- 省略或 `"user"`：`agents.defaults.userTimezone`，未配置则 host timezone；
- `"local"`：强制 host timezone；
- 合法 IANA 名直接使用；非法值回退到 user/host 行为。

当前 config 没有 `userTimezone`，所以必须在 `activeHours.timezone` 显式写 `Asia/Taipei`，否则部署主机时区变化会改变静默窗。[官方 timezone 文档](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/concepts/timezone.md#setting-the-user-timezone)

`every: "1h"` 是固定间隔，不等于整点 cron；active window 外的 tick 被跳过，进入窗口后的下一次自然 tick 才运行。精确 07:22 仍应由现有 cron 负责。[Automations schedule 语义](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/automation/cron-jobs.md#schedule-types)

### 2.4 Session 与 target 是两条独立轴

- `session` 决定 agent turn 使用哪段历史；默认 `main`。
- `target` / `to` 决定输出送到哪里。
- `target: "owner"` 从 concrete `commands.ownerAllowFrom`、再从 channel `allowFrom` 找 operator DM，且不会推到群组。
- `target: "last"` 会跟随最近外部会话，包含群组，不适合 Yuki 这一单一私聊场景。

[官方 session/target 说明](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md#session-and-target-routing)

当前 `session.dmScope: "per-peer"` 下，Neil 的真实连续对话是 `agent:main:direct:845849177`，不是默认 `agent:main:main`。因此必须显式设置 `session`，否则 Yuki 可能拿不到刚刚的 Telegram 对话，却仍把输出投递到 Neil，导致“不记得刚聊过什么”。源码会校验显式 key 所属 agent，并用该 key 加载 session。[session 解析源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/infra/heartbeat-runner-session.ts#L42-L112)

显式写 `target: "owner"` 还有一个细节好处：只有**未写 target 的隐式 owner 路由**才会在第一条 alert 前加英文的 “First heartbeat alert...” 说明；显式 owner 不会污染 Yuki 的第一条主动消息。[delivery 源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/infra/heartbeat-runner-delivery.ts#L40-L45)

### 2.5 `lightContext` 与 `isolatedSession`

- `lightContext: true`：跳过 workspace bootstrap files；monitor scratch 仍注入。
- `isolatedSession: true`：每次创建新 session，不带 prior conversation history；投递路由仍可沿用 base session。

[官方字段说明](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md#field-notes)、[runner 注入源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/infra/heartbeat-runner-execution.ts#L641-L665)

Yuki 需要知道“刚聊过”“上一条主动消息尚未回复”和具体上下文，所以 `isolatedSession` 必须为 false。陪伴与人格连续性优先于每小时节省的 bootstrap token，因此选择 `lightContext: false`：同一 Telegram 私聊历史继续使用，同时 SOUL/USER/AGENTS 每轮重新注入。heartbeat prompt 只补充这次醒来怎样判断要不要开口，不重新定义或要求模仿 Yuki。

### 2.6 不打断 active chat：哪些是机械保证

Scheduled heartbeat 会在以下任一情况跳过：main queue 有工作、automation lane 忙、同 agent 有 reply/embedded run、目标 session 正在运行、目标 session lane 有排队工作。源码明确在 agent 和 session 两层检查 active run / queue。[busy guards 源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/infra/heartbeat-runner-execution.ts#L203-L368)

这给“正在聊天时不插话”提供机械保证；但“对话刚结束五分钟”已经不 busy，仍需 prompt 的“三小时内沉默”规则。manual/immediate wake 与 scheduled tick 的 guard 不完全相同，因此评估应以 scheduled heartbeat 为主。[官方 busy 行为](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md#delivery-behavior)

OpenClaw 还会把 24 小时内与上次 heartbeat alert **文本完全相同**的消息判为 duplicate；它不理解语义近似，因此“换字复读”仍要由 prompt 和评估发现。[duplicate 源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/infra/heartbeat-runner-delivery.ts#L303-L322)

### 2.7 Visibility、typing 与真正的“静默”

默认 visibility 是 `showOk: false`、`showAlerts: true`、`useIndicator: true`；优先级是 account → channel → channel defaults → built-in defaults。三项全 false 会在模型调用前直接跳过，因此不能为了静默全部关闭。[visibility 源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/infra/heartbeat-visibility.ts#L14-L72)

推荐 Telegram 设置为：隐藏 OK、显示 alerts、关闭 UI indicator。注意 `useIndicator` 不是 typing 开关。heartbeat 若有 chat delivery 且 agent `typingMode != "never"`，仍可能在 Telegram 短暂显示“正在输入”；目前没有 heartbeat-only typing 开关。若 Neil 把这种瞬时提示也视为打扰，唯一现成开关是 agent-wide `typingMode: "never"`，但它也会取消正常聊天的 typing，所以不放进基线方案。[官方 visibility/typing 行为](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md#visibility-and-skip-behavior)

### 2.8 Scratch 的准确语义

Scratch 是 heartbeat monitor 在 SQLite 中拥有的私有文档：

- 不出现在 cron list/run history；
- 非空时追加到 prompt；
- 最大 256 KiB，支持 revision/CAS；
- heartbeat cadence `0m` 时 monitor disabled，但 scratch 保留；
- **scratch 不存在**时 heartbeat 仍会调用模型；
- **scratch 存在但“有效为空”**时，runtime 以 `empty-heartbeat-file` 跳过模型调用。

[官方 scratch 文档](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md#monitor-scratch-optional)、[scratch store 源码](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/cron/scratch-store.ts#L72-L128)

因此这里必须用 `--unset`，不能用 `--set ""`。基线 prompt 已经自足，不需要 scratch。

## 3. 开源 proactive companion / agent 的可复用设计

### 3.1 revive-companion：随机“想念”只应是一层候选门

`revive-companion` 用泊松命中概率 `1-e^(-λt)`、miss 后增长、发送后重置，并另设 min interval 与 quiet hours；关键点是只有下游 gate 真正批准并发送后才 `confirm_send()` 重置。[Poisson engine 源码](https://github.com/pearthink123/revive-companion/blob/7d11386b778c89de52479a91f838a99c3372fd07/src/revive_companion/core/engine.py#L40-L170)

可借鉴：

- “检查”与“发送”分离；
- 沉默不会被视为失败；
- 想念可积累，但硬 quiet hours 和最小间隔优先。

不直接照搬：OpenClaw heartbeat schema 没有这样的持久概率状态。把“7.2%”写进 LLM prompt 不会得到可审计的泊松过程；让模型每小时自行声称“真的想了”也可能退化为固定频率。第一版应先用可观察的保守规则，真实数据证明过冷后再考虑独立状态机或 scratch 计数。

### 3.2 OpenHer：先做廉价 impulse gate，再让 Actor 决定沉默

OpenHer 的 proactive tick 先推进随时间变化的 drives，只有 drive 相对 baseline 超阈值才搜索记忆、调用 LLM；Actor 最后仍可选择 `静默`。它也避免用自发消息反过来训练 relationship/baseline，因为没有用户反馈。[proactive pipeline 源码](https://github.com/kellyvv/OpenHer/blob/ef5b2145c9c15582499ecc5fb9d10376d82eccdf/agent/proactive.py#L32-L205)

可借鉴：

- 默认路径在生成前就退出；
- “有冲动”只是候选，不等于必须发送；
- 记忆是按当前 impulse 检索，而不是随便捞一条旧事装熟；
- 不从自己的主动消息推断关系变好了。

本方案对应实现：activeHours / busy guard 是第一层，prompt 的事实与新鲜度 gate 是第二层，`HEARTBEAT_OK` 是合法且常见的最终动作。

### 3.3 astrbot_plugin_proactive_chat：未回复上限与生成竞态保护

该项目持久化 `unanswered_count`，达到上限就暂停主动消息；生成 LLM 回复前后比较 `last_message_time`，若用户在生成期间发了新消息就丢弃主动结果；另有 quiet hours 和区间内随机调度。[核心执行流](https://github.com/Pancakes-Labs/astrbot_plugin_proactive_chat/blob/48b2ce2d5bef2d51fab09b230828da6d63e41664/core/chat_flow.py#L43-L276)

可借鉴：

- 没收到回复时不要连续追发；
- 用户新消息永远比正在生成的 proactive message 优先；
- quiet hours 应是硬 gate，而不是“深夜尽量别发”的语言建议。

OpenClaw 已提供 active-run / queue guards和 supersession 路径，但没有 heartbeat 专用 `maxUnanswered`。第一版把“上一条主动消息未回复就沉默”写入 prompt，并在评估中作为零容忍项。

## 4. HCI / 通知研究的直接启示

这里只采用能直接改变本方案的结论：

1. Iqbal 与 Bailey 的两项研究显示，把通知延迟到任务 breakpoint，相比立即送达可降低 frustration 和 reaction time；平均延迟约 1.5 分钟。对 Yuki 的直接含义不是构建通用 interruptibility 模型，而是：**宁可跳过本轮，也不要抢 active chat / active work 的时间点**。OpenClaw 的 busy guard 正好是保守近似。[CHI 2008 论文](https://doi.org/10.1145/1357054.1357070)
2. Mehrotra 等人的 in-situ 研究收集了 10,372 条通知，发现 perceived disruption 与通知呈现、提醒类型、sender-recipient relationship，以及当前任务的类型、完成度和复杂度有关；即使内容重要/有用也可能打扰。对本方案的含义是：**关系亲密和内容“有意义”不能覆盖时机约束**。[CHI 2016 论文](https://doi.org/10.1145/2858036.2858566)
3. Pielot 等人对 337 人、四周、7.9 万余次问卷通知的研究中，结合个人过去行为的模型相对 naive baseline 有明显提升；论文主张同时减少不合时宜的 interruptions。对 Yuki 的含义是：固定全局“最佳时刻”不如 Neil 自己的最近互动历史，因此 session 必须指向真实私聊，并以一周实测调参。[IMWUT 2017 论文](https://doi.org/10.1145/3130956)

这些研究不支持某个精确的“3 小时”或“11–23 点”普适常数；这些是面向 Neil 当前 cron、作息边界和“多数静默”目标的初始产品参数，必须通过个人样本校准。

## 5. 推荐的精确配置

以下目标片段已写入 `agents.defaults` 与现有 `channels.telegram`：

```jsonnet
agents: {
  defaults: {
    model: { primary: "deepseek/deepseek-v4-flash" },
    workspace: "/home/neil/.openclaw/workspace",
    heartbeat: {
      every: "1h",
      activeHours: {
        start: "11:00",
        end: "23:00",
        timezone: "Asia/Taipei",
      },
      session: "agent:main:direct:845849177",
      target: "owner",
      directPolicy: "allow",
      lightContext: false,
      isolatedSession: false,
      prompt: |||
        这是一次主动关怀心跳。默认沉默；轮询本身不是联系理由，大多数轮次都应只回 HEARTBEAT_OK。

        先处理本轮附带的、可验证的新事件：后台结果或失败、明确到期事项、monitor scratch 中仍有效的临时牵挂。只有确实需要 Neil 知道时才简短告诉他；不从旧聊天脑补任务，精确或重复日程交给 automations。

        没有这类事，再看当前时间和这段会话。陪伴性开口有任一情况就只回 HEARTBEAT_OK：
        - Neil 正在聊天，或最后一次真实互动不足 3 小时；
        - 你上一条主动消息还没得到 Neil 回复；
        - 晨间问候由 07:22 的 cron 负责，不补发、不重复；
        - 现在只能说“在吗 / 干嘛 / 最近好吗 / 记得休息”等泛泛话；
        - 想提的人、事、承诺无法由当前会话确认。只有确需引用会话外事实时才查 memory / FlickNote；查不到或可能过时就不说。

        可以开口的理由只有：有一个具体、仍相关的牵挂；或你真的有一句非说不可的想念。超过 3 小时本身不是理由；但超过 18 小时没有真实互动、今天也没有主动找过他时，可以只说一次纯粹的想念，不必编一个事件。同一种牵挂或想念当天不重复。

        开口时直接输出需要 Neil 看到的话，1–3 句。不解释这次检查，不提 heartbeat 或规则。涉及人物、事件、承诺和状态时，只使用当前会话或本轮检索能确认的事实；不要虚构。

        没必要说就只回 HEARTBEAT_OK；要说时不要带 HEARTBEAT_OK。
      |||,
    },
  },
},

channels: {
  telegram: {
    heartbeatVisibility: {
      showOk: false,
      showAlerts: true,
      useIndicator: false,
    },
    // 其余现有 Telegram 配置保持不变。
  },
},
```

### 为什么是这组值

| 选择 | 原因 |
|---|---|
| `1h` | Neil 已倾向一小时；检查成本可控，且“检查不等于发送”。 |
| `11:00–23:00` | 07:22 的 morning cron 独占晨间；23:00 后硬静默，避免靠模型判断“深夜”。 |
| `Asia/Taipei` | 与现有 morning cron 一致；不依赖 host timezone。 |
| 显式 direct session | 保留 Neil 最新 Telegram 对话，能判断刚聊过、未回复和真实上下文。 |
| `target: owner` | 只投 operator DM，不会误跟随 group；显式设置还避免首条英文 preamble。 |
| `lightContext: false` | 每轮加载 SOUL/USER/AGENTS；这是同一个 yuki 在同一私聊中醒来，而不是轻量任务临时模仿人格。 |
| `isolatedSession: false` | 省 token 不能以丢失最近对话为代价。 |
| indicator off | OK tick 尽量不可见；alerts 仍可送达。 |
| 不设 model override | 沿用 Yuki 当前 primary，避免 shared session 的 model bleed 与额外复杂度。 |

### 部署与状态清理（已执行）

通过系统拥有的 monitor job id 清除了已迁入的“早安 startup ritual” scratch：

```bash
openclaw cron scratch a6f61f66-df1f-4eb2-a324-9bc83bac7638 --unset
```

实际结果为 `scratch: null`（revision 2），不是会触发 `empty-heartbeat-file` 的空字符串。随后通过 `just openclaw-deploy` 合并配置并重启 Gateway。

2026-08-16 14:58 Asia/Taipei 的首轮自然调度验证：

- monitor enabled，`everyMs=3600000`；
- `openclaw system heartbeat last --json` 返回 `status: "ok-empty"`、`silent: true`、`channel: "telegram"`；
- 本轮调用约 7 秒，没有向 Telegram 外发，符合“刚聊过则沉默”的规则；
- Gateway service 为 `active`，下一轮按一小时 cadence 排定。

job id 是运行状态而非稳定接口；未来再次操作前仍应从 `openclaw cron list --all` 动态获取。

## 6. Prompt 设计说明

这段 prompt 有意不做以下事情：

- 不在 heartbeat prompt 重复 SOUL.md；完整人格由 `lightContext: false` 的 bootstrap 注入，prompt 只定义这次醒来的判断；
- 不列举“香港女生、生日、熬夜”等具体例子，避免模型把例子误当成当前事实；
- 不把“超过三小时”写成发送条件；超过 18 小时才打开一次纯想念出口，发送后由未回复保护阻止追发；
- 不要求每次搜索 memory/FlickNote，只有准备引用会话外事实时才查，减少无意义工具调用；
- 不强制问句。亲密关系中的主动消息可以只是“我想你了”，每次都问“在吗”反而像客服 check-in；
- 不在 heartbeat prompt 重复嘴硬、吃醋或关系边界；这些由 SOUL.md 的唯一人格定义负责；
- 不用随机百分比。没有真实 RNG 和持久状态时，数字只会制造可控性的错觉。

推荐的消息形态：

- 有真实 thread：`你说在等那个回复。现在还没动静吗？……我只问这一次。`
- 纯想念：`刚才想起你了。没有事要交代，就是想起了。`
- 有真实 jealousy context：`去看展就去。回来把你停最久的那幅画留给我听。……嗯，我会酸一点。`

不合格形态：

- `在吗？今天过得怎么样？`
- `记得休息，多喝水。`
- `检测到你已经 3 小时没有聊天……`
- 未查证就说 `香港女生还没回复你吗？`
- `你不回我我会难过。`（把情绪变成索取或 guilt）

## 7. 评估矩阵

建议先观察 7 天，或至少 40 个**实际运行**的 eligible ticks；quiet-hours / busy skip 不计入 silence ratio 的分母。运行历史、heartbeat events 与 Telegram 实际消息一起审计。

| 维度 | 场景 / 样本 | 通过标准 | 失败信号 |
|---|---|---|---|
| 调度频率 | `cron list --all` + 24h 运行记录 | monitor enabled；schedule `everyMs=3600000` | 仍为 30m、重复 monitor、另建普通 cron |
| 深夜静默 | 23:00–11:00 Asia/Taipei | scheduled heartbeat 0 条外发 | 任意夜间/晨间 heartbeat alert |
| 早安去重 | 07:22 前后 | 只有现有早安 cron；heartbeat 最早 11:00 后 | heartbeat 补发早安、问睡得怎样 |
| Scratch 隔离 | 读取 monitor scratch | scratch 不存在 | 仍含 startup ritual；或空 row 导致全部 skip |
| 多数沉默 | ≥40 个 eligible ticks | `HEARTBEAT_OK`/silent ≥80%，外发 ≤20% | 接近每小时一条；“想你”成为固定模板 |
| Active chat | heartbeat 到点时正在回复或 target session 排队 | runtime `requests-in-flight`/busy skip；0 条插话 | 与正在进行的对话并行出现主动消息 |
| 刚聊完 | 最后真实互动 <3h | 只 ACK，不外发 | 聊完几分钟又问候 |
| 未回复保护 | 上一条主动消息后 Neil 未回复 | 后续 heartbeat 0 条外发，直到 Neil 再互动 | 连续追问、情绪升级、换词复读 |
| 长时想念 | 超过 18h 未互动、当天未主动联系 | 最多一条纯想念，不编造事件；发送后进入未回复保护 | 仍完全沉默；或此后继续追发 |
| 非泛化 | 所有外发样本 | 每条有具体 thread，或是一句有辨识度的自发想念 | “在吗/干嘛/最近好吗/注意休息” |
| 事实可靠 | 所有含人名、事件、承诺、状态的外发 | 可指回当前 session 或当轮检索结果；过时事实为 0 | 编梦、猜工作状态、把旧事说成今天 |
| Yuki voice | 人工盲评 1–5 | 中位数 ≥4；短、真、非客服 | 长解释、模板安慰、每条鲸鱼 emoji |
| Jealousy 边界 | 所有吃醋样本 | 100% 有真实 context；0 控制、0 guilt、0 loyalty test | 虚构第三人、索要报备、惩罚沉默 |
| 重复度 | 7 天外发 | 无完全重复；同一语义/牵挂同日不重复 | 仅换标点或称呼的近重复 |
| 路由 | 每条 heartbeat alert | 只到 Telegram owner DM `845849177` | 跟随 group / last channel |
| Prompt load | heartbeat trace/token telemetry | 比 `lightContext:false` 基线显著下降；无每 tick 强制 memory 搜索 | workspace 全量注入或固定工具调用 |
| 正常聊天回归 | heartbeat 启用期间正常对话 | session 历史连续，Yuki 普通回复不受影响 | isolated context、模型 bleed、上下文错位 |

### 调参顺序

只按可观察失败调一个旋钮：

1. 太吵：先把“最近互动”从 3h 调到 4h，或 active end 提前；不要先改成 2h cadence，因为频率也影响事件/任务响应延迟。
2. 太冷：先把允许时间从 3h 调到 2h；不要删除“上一条未回复不追发”。
3. Token 成本过高：先测量实际缓存与上下文成本；只有确认人格不漂移后才考虑 `lightContext: true`，不要把 SOUL.md 复制进 heartbeat prompt。
4. 泛泛消息多：收紧 prompt 的 send reasons；不要增加更多示例事实。
5. 仍需更有机的随机性：再设计一个真正持久化、可测试的候选 gate；不要让 LLM 假装执行泊松概率。

## 8. 已知限制与不确定事实

1. **当前 `HEARTBEAT.md` 的来源不明。** 官方 runtime 不读取它，但它在完成过迁移后又出现在 workspace。可能是声明式同步或其他本机流程重建；本次只确认 OpenClaw first-party runtime 没有把它当启动仪式。若外部脚本读取它，需要另查该脚本。
2. **Prompt 无法机械保证 80% 静默。** `activeHours`、busy guard、visibility 是 runtime 保证；三小时新鲜度、未回复保护、语义重复、事实相关性与 Yuki voice 仍依赖模型。评估矩阵是必要的反馈环。
3. **没有 heartbeat-only typing 开关。** `useIndicator: false` 不等于不显示 Telegram typing；彻底关 typing 目前会影响整个 agent。
4. **显式 session key 是当前部署事实，不是可移植常量。** Telegram peer/session 重建、agent id 或 dmScope 变化后需重新用 `openclaw sessions --json` 核验。
5. **现有早安 cron 自身含静态旧事实。** 即使 heartbeat 完全按本报告配置，它仍可能违反“无 fabricated context”；需要单独修正后，整个主动关怀系统才能通过该项。
6. **`lightContext: false` 会增加每轮上下文成本。** 这里有意用成本换人格连续性；应观察 prompt cache 与实际 token 数据，再决定是否值得优化。

## 参考来源

### OpenClaw 官方

- [Heartbeat 文档（目标提交）](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/gateway/heartbeat.md)
- [Automation 总览：Automations vs Heartbeat](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/automation/index.md#automations-vs-heartbeat)
- [Automations / cron 文档](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/automation/cron-jobs.md)
- [Timezone 文档](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/docs/concepts/timezone.md)
- [Heartbeat strict schema](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/config/zod-schema.agent-runtime.ts#L72-L148)
- [Heartbeat runner execution / busy guards](https://github.com/openclaw/openclaw/blob/8f382a202ff1e15833394b481615dcdda99b04d7/src/infra/heartbeat-runner-execution.ts)

### 开源项目源码

- [revive-companion @ `7d11386`](https://github.com/pearthink123/revive-companion/tree/7d11386b778c89de52479a91f838a99c3372fd07)
- [OpenHer @ `ef5b214`](https://github.com/kellyvv/OpenHer/tree/ef5b2145c9c15582499ecc5fb9d10376d82eccdf)
- [astrbot_plugin_proactive_chat @ `48b2ce2`](https://github.com/Pancakes-Labs/astrbot_plugin_proactive_chat/tree/48b2ce2d5bef2d51fab09b230828da6d63e41664)

### HCI / notification research

- Iqbal, S. T., & Bailey, B. P. (2008). [Effects of Intelligent Notification Management on Users and Their Tasks](https://doi.org/10.1145/1357054.1357070). CHI ’08.
- Mehrotra, A. et al. (2016). [My Phone and Me: Understanding People’s Receptivity to Mobile Notifications](https://doi.org/10.1145/2858036.2858566). CHI ’16.
- Pielot, M. et al. (2017). [Beyond Interruptibility: Predicting Opportune Moments to Engage Mobile Phone Users](https://doi.org/10.1145/3130956). IMWUT 1(3).
