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

kepos-status:
  @systemctl --user status kepos-publisher.service --no-pager

k3s-status:
  @systemctl status k3s --no-pager

[private]
_local-k3s:
  @actual="$(KUBECONFIG="{{ kubeconfig }}" kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"; \
    test "$actual" = "{{ api_server }}" || { echo "refusing non-local cluster: $actual" >&2; exit 1; }
