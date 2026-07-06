# WSL DevOps Runbook

This runbook covers the staging implementation from
`docs/dagger-forgejo-packages-plan.md`.

## Services

- Forgejo staging: `https://git-wsl.guion.io`
- Dagger engine: local only, `tcp://127.0.0.1:8080`
- Woodpecker staging: module present, service gated on secrets

Forgejo and Dagger are enabled in `hosts/wsl/default.nix`. Woodpecker is enabled
there too, but its systemd services do not start until the required env secrets
exist.

## Dagger

The `dagger` command installed by Nix is a wrapper around the pinned Dagger CLI.
It sets:

```text
XDG_CONFIG_HOME=/var/lib/dagger/config
XDG_CACHE_HOME=/var/lib/dagger/cache
_EXPERIMENTAL_DAGGER_RUNNER_HOST=tcp://127.0.0.1:8080
```

The engine runs as a systemd-managed Podman container:

```bash
systemctl status podman-dagger-engine
dagger version
```

The engine GC policy is written to:

```text
/etc/dagger/engine.json
```

Current policy:

```json
{
  "gc": {
    "maxUsedSpace": "100GB",
    "reservedSpace": "10GB",
    "minFreeSpace": "20%",
    "sweepSize": "50%"
  }
}
```

After changing the engine config, restart the engine container:

```bash
sudo systemctl restart podman-dagger-engine
```

## Forgejo Staging

The staging admin bootstrap credentials are stored outside git:

```text
/root/kosmos-forgejo-admin-init.txt
```

Read it only when you need to log in:

```bash
sudo cat /root/kosmos-forgejo-admin-init.txt
```

Check local service state:

```bash
kosmos-wsl-devops-smoke
systemctl status forgejo
curl -I http://127.0.0.1:3000/
curl -I https://git-wsl.guion.io/v2/
```

The `/v2/` response should be a container-registry response, not the Forgejo HTML
app shell.

If the public hostname does not reach the WSL tunnel, route it to the `nuc-wsl`
Cloudflare tunnel:

```bash
cloudflared tunnel route dns --overwrite-dns c0e179cd-14fc-4cd9-ba4c-00a445844c74 git-wsl.guion.io
```

Smoke test Packages after the admin user and `GuionAI` org exist. Use lowercase `guionai` in the OCI image path:

```bash
docker login git-wsl.guion.io
docker pull hello-world:latest
docker tag hello-world:latest git-wsl.guion.io/guionai/smoke:latest
docker push git-wsl.guion.io/guionai/smoke:latest
docker pull git-wsl.guion.io/guionai/smoke:latest
```

Dagger publish smoke:

```bash
export FORGEJO_PASSWORD="$(sudo awk -F': ' '$1 == "Password" { print $2; exit }' /root/kosmos-forgejo-admin-init.txt)"
dagger -M call container \
  with-new-file --path /smoke.txt --contents "kosmos dagger registry smoke" \
  with-registry-auth --address git-wsl.guion.io --username neil --secret env://FORGEJO_PASSWORD \
  publish --address git-wsl.guion.io/guionai/dagger-smoke:latest
unset FORGEJO_PASSWORD
docker pull git-wsl.guion.io/guionai/dagger-smoke:latest
```

## Woodpecker Secrets

Woodpecker needs two env files.

Server env:

```text
WOODPECKER_AGENT_SECRET=<shared-agent-secret>
WOODPECKER_FORGEJO_CLIENT=<forgejo-oauth-client-id>
WOODPECKER_FORGEJO_SECRET=<forgejo-oauth-client-secret>
```

Agent env:

```text
WOODPECKER_AGENT_SECRET=<same-shared-agent-secret>
```

Create them as agenix secrets:

```bash
agenix -e secrets/woodpecker-server-env.age
agenix -e secrets/woodpecker-agent-env.age
```

Then register both files in root `secrets.nix` with `users ++ systems`, add the
files to git, and rebuild WSL.

After secrets exist, check:

```bash
systemctl status woodpecker-server
systemctl status woodpecker-agent-wsl-podman
```

Woodpecker uses the Podman/Docker backend. Pipeline containers that need Dagger
receive this global environment variable from the Woodpecker server:

```text
_EXPERIMENTAL_DAGGER_RUNNER_HOST=unix:///run/dagger/engine.sock
```

The agent mounts `/run/dagger` into every pipeline step with
`WOODPECKER_BACKEND_DOCKER_VOLUMES`. Before relying on this from CI, verify from
a throwaway Woodpecker job that the socket exists and `dagger version` can reach
the engine.

## Kubernetes Pull Secret

The staging package pull token is stored outside git:

```text
/root/kosmos-forgejo-k8s-packages-pull-token.txt
```

The source Kubernetes secret is:

```text
devops/forgejo-packages
```

It has type `kubernetes.io/dockerconfigjson` and Reflector annotations for:

```text
apps-dev
apps-prod
apps-share
```

Verify source and mirrored secret metadata without printing secret data:

```bash
kubectl get secret forgejo-packages -n devops \
  -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,TYPE:.type'
for ns in apps-dev apps-prod apps-share; do
  kubectl get secret forgejo-packages -n "$ns" \
    -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,TYPE:.type'
done
```

Private image pull smoke in `apps-dev`:

```bash
kubectl delete pod forgejo-packages-pull-smoke -n apps-dev --ignore-not-found --wait=true
kubectl apply -n apps-dev -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: forgejo-packages-pull-smoke
spec:
  restartPolicy: Never
  imagePullSecrets:
    - name: forgejo-packages
  containers:
    - name: smoke
      image: git-wsl.guion.io/guionai/dagger-smoke:latest
      imagePullPolicy: Always
      command: ["/smoke.txt"]
EOF
kubectl get pod forgejo-packages-pull-smoke -n apps-dev \
  -o jsonpath='{.status.containerStatuses[0].imageID}{"\n"}'
kubectl delete pod forgejo-packages-pull-smoke -n apps-dev --ignore-not-found --wait=false
```

The smoke image is scratch-based, so the pod can fail after the pull. The pass
condition is a populated `imageID` and no `ErrImagePull` or `ImagePullBackOff`.

## Production Cutover Guardrails

Do not move `git.guion.io` until all of these are true:

- Forgejo staging login works.
- HTTPS clone and push work.
- Packages push and pull work through `git-wsl.guion.io`.
- Dagger can publish an image to `git-wsl.guion.io/guionai/*`.
- A Kubernetes pod in `apps-dev` pulls a private staging image using the mirrored
  `forgejo-packages` secret.
- A cold copy or restore dry run of the current Forgejo `/data` volume has been
  tested.
