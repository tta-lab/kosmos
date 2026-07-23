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
  trap 'sudo ./scripts/k3s-devops-migrate rollback' ERR
  KUBECONFIG="{{ kubeconfig }}" tk apply "{{ environment }}"
  for workload in deployment/canonical-gateway deployment/forgejo deployment/woodpecker statefulset/woodpecker-agent daemonset/dagger; do
    KUBECONFIG="{{ kubeconfig }}" kubectl rollout status "$workload" -n devops --timeout=5m
  done
  curl --fail --silent --show-error --header 'Host: forgejo.localhost' http://127.0.0.1:17480/api/healthz >/dev/null
  curl --fail --silent --show-error --header 'Host: woodpecker.localhost' http://127.0.0.1:17480/healthz >/dev/null
  sudo ./scripts/k3s-devops-migrate complete
  trap - ERR
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
