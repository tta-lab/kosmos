set shell := ["bash", "-euo", "pipefail", "-c"]

environment := "tanka/environments/devops"
photos_environment := "tanka/environments/photos"
ebooks_environment := "tanka/environments/ebooks"
anki_environment := "tanka/environments/anki"
notes_environment := "tanka/environments/notes"
feeds_environment := "tanka/environments/feeds"
hindsight_environment := "tanka/environments/hindsight"
kubeconfig := env_var_or_default("KUBECONFIG", "/etc/rancher/k3s/k3s.yaml")
api_server := "https://127.0.0.1:26443"

default:
  @just --list

show target=environment:
  @TANKA_DANGEROUS_ALLOW_REDIRECT=true tk show "{{ target }}"

diff target=environment: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk diff "{{ target }}"

apply target=environment: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ target }}"

status namespace="devops": _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" kubectl get pods,svc,pvc -n "{{ namespace }}" -o wide

photos-show:
  @TANKA_DANGEROUS_ALLOW_REDIRECT=true tk show "{{ photos_environment }}"

photos-diff: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk diff "{{ photos_environment }}"

photos-apply: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ photos_environment }}"

photos-status: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" kubectl get pods,svc,pvc -n photos -o wide

ebooks-show:
  @TANKA_DANGEROUS_ALLOW_REDIRECT=true tk show "{{ ebooks_environment }}"

ebooks-diff: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk diff "{{ ebooks_environment }}"

ebooks-secrets: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" scripts/init-ebook-secrets

ebooks-apply: _local-k3s ebooks-secrets
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ ebooks_environment }}"

ebooks-deploy: ebooks-apply
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ environment }}"
  @KUBECONFIG="{{ kubeconfig }}" kubectl rollout restart deployment/canonical-gateway -n devops
  @KUBECONFIG="{{ kubeconfig }}" kubectl rollout status deployment/canonical-gateway -n devops --timeout=120s

ebooks-status: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" kubectl get pods,svc,pvc -n ebooks -o wide

anki-show:
  @TANKA_DANGEROUS_ALLOW_REDIRECT=true tk show "{{ anki_environment }}"

anki-diff: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk diff "{{ anki_environment }}"

anki-apply: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ anki_environment }}"

anki-deploy: anki-apply
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ environment }}"
  @KUBECONFIG="{{ kubeconfig }}" kubectl rollout restart deployment/canonical-gateway -n devops
  @KUBECONFIG="{{ kubeconfig }}" kubectl rollout status deployment/canonical-gateway -n devops --timeout=120s

anki-status: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" kubectl get pods,svc,pvc -n anki -o wide

notes-show:
  @TANKA_DANGEROUS_ALLOW_REDIRECT=true tk show "{{ notes_environment }}"

notes-diff: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk diff "{{ notes_environment }}"

notes-apply: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ notes_environment }}"

notes-deploy: notes-apply
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ environment }}"
  @KUBECONFIG="{{ kubeconfig }}" kubectl rollout restart deployment/canonical-gateway -n devops
  @KUBECONFIG="{{ kubeconfig }}" kubectl rollout status deployment/canonical-gateway -n devops --timeout=120s

notes-status: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" kubectl get pods,svc,pvc -n notes -o wide

hindsight-show:
  @TANKA_DANGEROUS_ALLOW_REDIRECT=true tk show "{{ hindsight_environment }}"

hindsight-diff: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk diff "{{ hindsight_environment }}"

hindsight-apply: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ hindsight_environment }}"

hindsight-deploy: hindsight-apply

hindsight-status: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" kubectl get pods,svc,pvc -n hindsight -o wide

feeds-show:
  @TANKA_DANGEROUS_ALLOW_REDIRECT=true tk show "{{ feeds_environment }}"

feeds-diff: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" tk diff "{{ feeds_environment }}"

feeds-secrets: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" scripts/init-miniflux-secrets

feeds-apply: _local-k3s feeds-secrets
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ feeds_environment }}"

feeds-deploy: feeds-apply
  @KUBECONFIG="{{ kubeconfig }}" tk apply "{{ environment }}"
  @KUBECONFIG="{{ kubeconfig }}" kubectl rollout restart deployment/canonical-gateway -n devops
  @KUBECONFIG="{{ kubeconfig }}" kubectl rollout status deployment/canonical-gateway -n devops --timeout=120s

feeds-status: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" kubectl get pods,svc,pvc -n feeds -o wide

hindsight-logs: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" kubectl logs deployment/hindsight -n hindsight --tail=200

bookorbit-bootstrap-token: _local-k3s
  @KUBECONFIG="{{ kubeconfig }}" kubectl get secret bookorbit-env -n ebooks -o jsonpath='{.data.SETUP_BOOTSTRAP_TOKEN}' | base64 --decode; echo

kepos-status:
  @systemctl --user status kepos-publisher.service --no-pager

kepos-publisher-key:
  @kepos publisher key --state ~/.local/state/kepos-neo/mux-publisher

kepos-subscriber-key:
  @kepos setup subscriber --state ~/.local/state/kepos-neo/subscriber

k3s-status:
  @systemctl status k3s --no-pager

# Merge declarative OpenClaw settings through its CLI so auto-managed metadata
# and credentials survive; install the miniflux-mcp credential wrapper, then
# restart the gateway (managed by \`openclaw gateway install\`).
openclaw-deploy:
  @install -m 0700 scripts/miniflux-mcp-wrapper ~/.local/bin/miniflux-mcp-wrapper
  @jsonnet openclaw/openclaw.jsonnet | openclaw config patch --stdin
  @systemctl --user restart openclaw-gateway

sync-codex-auth direction:
  @bun scripts/sync-codex-auth.ts "{{ direction }}"

[private]
_local-k3s:
  @actual="$(KUBECONFIG="{{ kubeconfig }}" kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"; \
    test "$actual" = "{{ api_server }}" || { echo "refusing non-local cluster: $actual" >&2; exit 1; }
