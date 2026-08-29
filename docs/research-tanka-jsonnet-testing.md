# Tanka / Jsonnet 测试方式研究

日期：2026-08-29

## 结论

Tanka 没有原生的 `tk test` 命令。对 Kosmos 这类以 Jsonnet 生成 Kubernetes
资源的仓库，最合适的分层是：

1. 把业务不变量写进按主题拆分的 `*.test.jsonnet`，用 Jsonnet 的
   `assert` / `std.assertEqual` 表达，由 `tk eval` 执行；
2. 每个受影响的 Tanka environment 再跑一次 `tk show >/dev/null`，确认
   Tanka 能完成 environment 解析、manifest 发现与处理；
3. 需要完整输出稳定性时才增加 golden test，需要 Kubernetes schema
   验证时交给专门 validator；
4. `tk diff` 连接真实集群，属于部署前验收，不属于离线单测。

这比“`tk show | yq | jq` 后在 Bash 中写全部断言”更贴近被测语言：测试条件
在 Jsonnet 内，Bash/Nix 只保留为很薄的测试调度层。

## 1. Jsonnet 原生测试能力

### `assert`、`error` 与 `std.assertEqual`

Jsonnet 没有内建 test runner，但语言本身有足够的断言原语：

- `assert condition; expression`：条件为假时求值失败，也可写
  `assert condition : 'domain-specific message'; expression`；
- object assertion：`{ assert self.x > 0, x: ... }`，适合把输入约束附着在
  library object 上；
- `error 'message'`：显式产生运行时错误，适合非法分支；
- `std.assertEqual(a, b)`：相等时返回 `true`，否则抛错，适合测试中的精确
  值比较。

来源：Jsonnet 官方 [tutorial 的 Errors 章节](https://jsonnet.org/learning/tutorial.html#errors)、
[language reference 的 Object Assertions 与 Error](https://jsonnet.org/ref/language.html)、
以及 [`std.assertEqual` 标准库文档](https://jsonnet.org/ref/stdlib.html#std.assertEqual)。

Jsonnet 是惰性求值语言，这是测试最容易踩的坑。未被最终结果引用的 local
不会被执行；object assertion 也要等该对象的字段被求值时才检查。官方语言参考
明确说明 manifestation 会强制可见字段并检查 assertions。因此测试入口必须返回
一个会被完整 manifest 的值，例如最终返回 `true`，或返回一个所有字段均为可见
测试结果的 object。不要只声明一组未使用的 `local test...`。

一种适合 Kosmos 的单文件模式是：

```jsonnet
local resources = import '../../tanka/environments/codex-bridge/main.jsonnet';
local deployment = resources.codexBridgeDeployment;
local service = resources.codexBridgeService;

assert deployment.spec.replicas == 0 :
  'placeholder image must stay disabled';
assert service.spec.ports[0].targetPort == 'proxy' :
  'Service must target the loopback relay';
std.assertEqual(deployment.spec.strategy.type, 'Recreate')
```

也可以用多个 `std.assertEqual(...) && ...` 串成最终 boolean；每一项成功均为
`true`，失败则直接以非零退出。建议一个主题一个文件，例如
`codex-bridge.test.jsonnet`、`gateway.test.jsonnet`，而不是把所有服务塞进一个
巨型测试文件。

### Suite、golden 与 manifest patterns

Jsonnet 官方解释器自己的 suite 说明了两种成熟约定：普通 `.jsonnet` 测试若无
`.golden`，输出必须是 `true`；有 `.golden` 时比较 stdout/stderr；文件名以
`error.` 开头时预期退出码为 1。见官方
[`test_suite/README.md`](https://github.com/google/jsonnet/blob/master/test_suite/README.md)
及 [`assert.jsonnet`](https://github.com/google/jsonnet/blob/master/test_suite/assert.jsonnet)。
这证明“独立 Jsonnet 测试文件 + 求值退出码”本身就是一方项目采用的模式。

Golden test 适合以下情况：

- 完整生成结果本身就是稳定的对外契约；
- 需要固定错误文本或多文件输出；
- 审阅完整输出变化比维护大量路径断言更容易。

它不适合默认覆盖整个 Kubernetes manifest：镜像 digest、默认字段、字段顺序等
会让 snapshot 过度敏感。Kosmos 应优先断言稳定且有风险的行为契约，再让
`tk show` 检查整体可渲染。若仓库以后使用 Bazel，维护中的
[`rules_jsonnet`](https://github.com/bazel-contrib/rules_jsonnet) 提供
`jsonnet_to_json_test`，就是“求值并与 golden JSON 比较”的现成规则；当前 Nix
仓库没有必要仅为此引入 Bazel。

Jsonnet 自身不能捕获 `error`，所以“预期失败”的负向测试需要外部 runner 检查
退出码/错误。除非 Kosmos 真有稳定的拒绝契约，否则不必为普通 manifest 测试
引入这层复杂度。

## 2. Tanka 命令的职责

截至本机 Tanka v0.38.0，`tk --help` 的命令清单没有 `test`。上游 `main.go`
也只注册 apply/show/diff 等 workflow 命令及 fmt/lint/eval 等 Jsonnet 命令，见
[Tanka `cmd/tk/main.go`](https://github.com/grafana/tanka/blob/main/cmd/tk/main.go)。
因此不能寻找一个不存在的“Tanka 原生单测框架”。

| 命令 | 实际职责 | 在测试分层中的位置 |
|---|---|---|
| `tk eval <path>` | 使用 Tanka 配置好的 Jsonnet implementation、JPATH、ext/TLA 参数求值，输出原始 JSON；`-e` 可在结果上再求表达式 | 执行 `*.test.jsonnet` 的首选 runner |
| `tk show <environment>` | 完整加载 environment，发现含 `apiVersion`/`kind` 的资源，做 namespace/filter 等 Tanka 处理并输出 YAML | 无集群的 environment 集成 smoke test |
| `tk diff <environment>` | 将本地期望资源与目标 Kubernetes 集群比较；有差异默认退出 16 | 部署前人工/CI 验收，不是单测 |

`tk eval` 的上游命令说明就是 “evaluate the jsonnet to json”，实现调用
`tanka.Eval`；见 [`cmd/tk/jsonnet.go`](https://github.com/grafana/tanka/blob/main/cmd/tk/jsonnet.go)
和 [`pkg/tanka/load.go`](https://github.com/grafana/tanka/blob/main/pkg/tanka/load.go)。
它适合运行断言文件，因为失败会沿 Jsonnet 求值错误返回非零，同时不需要把 JSON
先转 YAML 再交给 jq。

`tk show` 不是简单的格式转换。Tanka 文档说明 `main.jsonnet` 可返回深层 object
或 array，Tanka 会递归提取同时含 `kind` 与 `apiVersion` 的对象；见
[`main.jsonnet` 文档](https://tanka.dev/jsonnet/main/)。其实现先 `Load` environment
再返回处理后的 `manifest.List`，见
[`pkg/tanka/workflow.go`](https://github.com/grafana/tanka/blob/main/pkg/tanka/workflow.go)。
所以 `tk show ... >/dev/null` 能补上直接 import library 的 Jsonnet 单测覆盖不到的
Tanka manifest extraction 和 environment spec 处理。

`tk diff` 的官方教程定位是类似 `git diff` 的部署前变更检查；实现会连接 cluster，
并以 0 表示无变化、16 表示有变化。见
[Tanka tutorial](https://tanka.dev/tutorial/jsonnet/) 和
[`cmd/tk/workflow.go`](https://github.com/grafana/tanka/blob/main/cmd/tk/workflow.go)。
它不应放进要求隔离、不能读取生产状态的单元测试层。

## 3. jsonnet-bundler、k8s-libsonnet 与 Go 测试

### `jb` 和 `k8s-libsonnet` 不负责运行测试

[`jsonnet-bundler`](https://github.com/jsonnet-bundler/jsonnet-bundler) 是依赖管理器：
`jsonnetfile.json` 声明直接依赖，lock 文件固定传递依赖与版本，`jb install` 生成
`vendor/`。Tanka 的
[directory structure 文档](https://tanka.dev/directory-structure/) 也要求两个文件
都提交，vendor 可忽略。`jb` 不提供 `test` 子命令；它自己的单测是普通 Go
`go test`，网络安装场景用 `//go:build integration` 分开，见上游
[`Makefile`](https://github.com/jsonnet-bundler/jsonnet-bundler/blob/master/Makefile)
和 [`install_test.go`](https://github.com/jsonnet-bundler/jsonnet-bundler/blob/master/cmd/jb/install_test.go)。

[`k8s-libsonnet`](https://github.com/jsonnet-libs/k8s-libsonnet) 是生成 Kubernetes
object 的 Jsonnet library，也不是测试框架。引入它可以减少手写 API 字段和复用
builder，但不能替代针对本仓库策略的断言，也不能证明输出通过 Kubernetes schema。

### 成熟 Jsonnet 项目的实际模式

Grafana 的大型 [`jsonnet-libs`](https://github.com/grafana/jsonnet-libs) 仓库提供了
很直接的一方实例：

- [`enterprise-metrics/main_test.jsonnet`](https://github.com/grafana/jsonnet-libs/blob/master/enterprise-metrics/main_test.jsonnet)
  import 被测 library，在可见 `test...` 字段中使用带消息的 `assert`，并通过
  fold/comprehension 覆盖多组资源；
- 对应 [`Makefile`](https://github.com/grafana/jsonnet-libs/blob/master/enterprise-metrics/Makefile)
  的 test target 先 `jb install` 测试依赖，再直接运行
  `jsonnet ... main_test.jsonnet`。

这正是 Kosmos 应采用的核心形态：断言属于 Jsonnet，Make/Nix/Bash 只调度命令。

需要更复杂 harness 时，Go 的常见做法是用 go-jsonnet VM 求值，把 JSON decode
后用 typed Kubernetes structs 或结构断言比较，并使用 `t.TempDir()` 隔离 fixture。
Tanka 自己的
[`acceptance-tests/show_test.go`](https://github.com/grafana/tanka/blob/main/acceptance-tests/show_test.go)
就是在临时项目中运行 `tk show`、反序列化到 `corev1.ConfigMap` 后比较；
[`go-jsonnet/main_test.go`](https://github.com/google/go-jsonnet/blob/master/main_test.go)
则批量执行 `testdata/*.jsonnet` 并比较 golden。Kosmos 当前不是 Go 工具项目，单为
manifest 断言建立 Go module 会增加无益的 harness；只有出现预期错误、typed schema
或复杂 fixture 需求时才值得升级到这一层。

## 4. Kosmos 的建议替换方案

### 目标分层

| 层 | 内容 | 推荐执行方式 |
|---|---|---|
| 静态质量 | Jsonnet 格式与 lint | `tk fmt --test tests/jsonnet`、`tk lint tests/jsonnet` |
| 业务不变量 | 镜像、replicas、端口、probe、security context、PVC、无内嵌 Secret、Caddy/CoreDNS route | 按主题的 `tests/jsonnet/*.test.jsonnet` + `tk eval` |
| Tanka 集成 | environment 能加载并提取资源 | 对变更 environment 跑 `tk show --dangerous-allow-redirect ... >/dev/null` |
| Schema（可选） | Kubernetes API schema 合法 | 未来若实际需要，给 `tk show` 接专用离线 validator；不要用 jq 模拟 schema |
| 部署验收 | 与本地 k3s 现状的差异 | `just <service>-diff` / `tk diff`，不纳入 hermetic 单测 |

### Codex Bridge 应怎么测

新的 Codex Bridge manifest 最值得保留的契约是：

- placeholder 阶段 image 为占位值且 `replicas == 0`，避免不可拉取镜像被调度；
- bridge 以非 root UID 10001 运行、state mount 和 auth path 一致；
- loopback relay 监听代理端口，probe 实际检查 `127.0.0.1:8787`；
- Service 的 `targetPort` 指向 relay，而不是无法跨 Pod network 访问的 bridge loopback；
- PV 为 `Retain` 且 hostPath 正确，PVC 固定绑定该 PV；
- rendered object 中没有把凭据直接生成成 Secret；
- Caddy 与 CoreDNS 同时存在 `codex-bridge.localhost` 路由。

这些都是稳定运行时契约，适合放在独立的
`codex-bridge.test.jsonnet` 与 `gateway.test.jsonnet`。镜像 ready 后，同一测试应原子地
把 image 期望改为 immutable tag/digest，并把 replicas 期望改为 1；不要保留兼容
placeholder 的“两个值都允许”断言。

### 对现有 Bash + `tk show` + jq 测试的迁移

不需要一次性重写所有历史测试。推荐：

1. 本次新 Codex Bridge 和正在升级的 Hindsight 先采用 Jsonnet tests；
2. 原 Bash render test 若仅做 manifest 字段查询，就在下次触碰该服务时迁到对应
   `*.test.jsonnet`；
3. shell test 只保留真正测试 shell 行为、临时文件、进程和退出码的用例；
4. flake check 中逐个执行测试文件，便于 CI 直接显示失败主题；可在文件数量明显
   增长后再增加一个 suite aggregator，但不要重新做成单一巨型测试。

这样 Bash 不会完全消失——Nix derivation 仍需调度命令——但测试逻辑、错误位置和
结构遍历都会留在 Jsonnet，`tk show` 只承担它真正擅长的 Tanka 集成检查。
