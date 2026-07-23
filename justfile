set shell := ["bash", "-euo", "pipefail", "-c"]

environment := "tanka/environments/devops"
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

cutover: _local-k3s
  #!/usr/bin/env bash
  set -euo pipefail
  sudo ./scripts/k3s-devops-migrate prepare
  rollback_needed=true
  cleanup() {
    status=$?
    trap - EXIT INT TERM
    if [[ "$rollback_needed" == true ]]; then
      sudo ./scripts/k3s-devops-migrate rollback || status=1
    fi
    exit "$status"
  }
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  KUBECONFIG="{{ kubeconfig }}" tk apply "{{ environment }}"
  for workload in deployment/canonical-gateway deployment/forgejo deployment/woodpecker statefulset/woodpecker-agent daemonset/dagger; do
    KUBECONFIG="{{ kubeconfig }}" kubectl rollout status "$workload" -n devops --timeout=5m
  done
  curl --fail --silent --show-error --header 'Host: forgejo.localhost' http://127.0.0.1:17480/api/healthz >/dev/null
  curl --fail --silent --show-error --header 'Host: woodpecker.localhost' http://127.0.0.1:17480/healthz >/dev/null
  _EXPERIMENTAL_DAGGER_RUNNER_HOST=tcp://127.0.0.1:8080 \
    dagger -M call container from --address alpine:3.20 with-exec --args=echo --args=dagger-pull-ok stdout >/dev/null
  sudo ./scripts/k3s-devops-migrate complete
  rollback_needed=false
  trap - EXIT INT TERM
  echo 'k3s DevOps cutover passed'

rollback: _local-k3s
  @sudo ./scripts/k3s-devops-migrate rollback

kepos-init:
  @./scripts/kepos-publisher-init
  @systemctl --user stop kepos-publisher.service
  @systemctl --user daemon-reload
  @systemctl --user start kepos-publisher.service

kepos-status:
  @systemctl --user status kepos-publisher.service --no-pager

k3s-status:
  @systemctl status k3s --no-pager

[private]
_local-k3s:
  @actual="$$(KUBECONFIG="{{ kubeconfig }}" kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"; \
    test "$$actual" = "{{ api_server }}" || { echo "refusing non-local cluster: $$actual" >&2; exit 1; }
