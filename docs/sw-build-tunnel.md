# SW build tunnel

Kosmos initiates one native OpenSSH connection to `sw-admin@192.168.6.186:22`
over the existing OpenVPN route. Home Manager owns the `sw-build-tunnel.service`
user unit as Neil. Its explicit runtime identity is
`/home/neil/.ssh/seafarer_prod_ed25519`; its existing host trust is
`/home/neil/.ssh/known_hosts`. Neither file is copied into the Nix store or
managed by this change. SSH ignores ambient client config and agents, uses
strict host verification, and does not multiplex or fork into the background.

| SW listener owned by SSH | Kosmos target | Existing SW pod endpoint |
| --- | --- | --- |
| `127.0.0.1:18080` | `127.0.0.1:8080` Dagger | `10.42.0.1:18081` |
| `127.0.0.1:17890` | `127.0.0.1:7890` Mihomo | `10.42.0.1:17891` |

The existing `seafarer/sw-kepos-pod-bridge` Deployment retains its name,
selectors and CNI-only listeners. Pipeline runner and proxy environment values
remain unchanged. Kosmos still publishes Dagger/Mihomo through Kepos to other
trusted devices; SW is removed from that policy. No SW business workload,
OpenVPN settings, Dagger engine or storage changes are needed.

The systemd process state means SSH has executed, not that forwarding or
upstreams are healthy. `ExitOnForwardFailure=yes` makes a failed bind of either
remote listener fail the connection. It does not check Dagger/Mihomo health.
SSH has a 10-second connection timeout and one attempt; unanswered keepalives
at 15-second intervals with count three bound detection of a dead connection.
Systemd retries after five seconds without a start-rate lockout. Stopping the
unit terminates its owned SSH process and releases both remote listeners;
connection loss terminates existing streams. Reconnect supports future sessions
and cannot resume an interrupted Dagger build. Other causes of EOF may remain.
See the [OpenSSH client](https://man.openbsd.org/ssh) and
[configuration reference](https://man.openbsd.org/ssh_config).

## Ordered activation handoff

These are operator steps after reviewed deployment approval. Do not run a
switch, release ports, restart services or rerun CI during implementation.
Keep CI idle throughout the port-owner cutover; use Woodpecker's UI at
`https://192.168.6.186:8087` to confirm no running pipeline and coordinate users.
Run local commands as Neil from the reviewed Kosmos checkout.

1. Check the VPN route, local targets and service-independent authentication.
   These do not create reverse listeners or expose credential contents:

   ```bash
   ip -4 route get 192.168.6.186
   systemctl is-active openvpn-client.service
   timeout 3 bash -c ': </dev/tcp/127.0.0.1/8080'
   timeout 3 bash -c ': </dev/tcp/127.0.0.1/7890'
   env -u SSH_AUTH_SOCK ssh -F /dev/null \
     -i /home/neil/.ssh/seafarer_prod_ed25519 \
     -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes \
     -o StrictHostKeyChecking=yes \
     -o UserKnownHostsFile=/home/neil/.ssh/known_hosts \
     -o ConnectTimeout=10 sw-admin@192.168.6.186 true
   ```

   If this fails, the operator must provision/repair the existing identity's
   noninteractive access or verified known-host entry. Do not disable host
   verification. SW's administrator must verify effective sshd and authorized-key
   restrictions allow remote TCP forwarding to both loopback ports, with
   `GatewayPorts no` (or `clientspecified` honoring explicit loopback binds).
   SW host sudo is not available noninteractively to `sw-admin`; use an
   administrator session for the following host operations.

2. Before switching Kosmos, on SW in the administrator session inspect the
   exact old owner, then stop
   and disable only that unit. The observed owner is `kepos-peer.service`:

   ```bash
   sudo systemctl show kepos-peer.service -p FragmentPath -p ActiveState -p User
   sudo systemctl disable --now kepos-peer.service
   sudo ss -ltnp '( sport = :18080 or sport = :17890 )'
   ```

   Both ports must be free before continuing. Remove the retired unit from its
   reported `/etc/systemd/system/kepos-peer.service` installation and reload
   systemd, after confirming it is the SW-only runtime described above:

   ```bash
   sudo rm /etc/systemd/system/kepos-peer.service
   sudo systemctl daemon-reload
   ```

   Retired SW policy/state/software cleanup is operator-owned; do not read
   private state or use recursive deletion. The repository no longer installs
   or maintains that runtime. No compatibility owner runs alongside SSH.

3. With both old ports released, switch Kosmos. Home Manager may automatically
   start the new unit during this switch; that is why step 2 must finish first:

   ```bash
   nh os switch . -H wsl
   just kepos-policy-render
   systemctl --user start sw-build-tunnel.service
   systemctl --user status sw-build-tunnel.service --no-pager
   journalctl --user -u sw-build-tunnel.service -n 30 --no-pager
   ```

   Home Manager installs the `default.target` relationship for future user
   manager starts. Confirm Neil's user manager persists as intended with
   `loginctl show-user neil -p Linger`. Do not add cross-manager dependencies on
   system OpenVPN; SSH retries while VPN or upstream services are unavailable.
   No Tanka apply or pod bridge replacement is part of this cutover.

4. On SW, verify both listeners are loopback-only and owned by the SSH session:

   ```bash
   sudo ss -ltnp '( sport = :18080 or sport = :17890 )'
   ```

   On Kosmos, confirm the retained bridge is running:

   ```bash
   scripts/sw-kubectl -n seafarer get deployment sw-kepos-pod-bridge
   scripts/sw-kubectl -n seafarer get pods -l app=sw-kepos-pod-bridge -o wide
   ```

   A bind/authentication failure must appear in the user journal and retry;
   it is not readiness. If activation fails, stop `sw-build-tunnel` and keep CI
   idle while repairing the prerequisite. Do not reintroduce concurrent owners.

## Observable acceptance

Only after separately approved activation, use one selected, authorized CI
pipeline whose Dagger container supplies the existing CLI. Record its pipeline
ID, pod and container names, timestamps and result. Set `pipeline_pod` and
`dagger_container` to those observed names; do not guess or use a business pod.
During that pipeline, from Kosmos run bounded checks in that same container:

```bash
timeout 30 scripts/sw-kubectl -n seafarer exec "$pipeline_pod" \
  -c "$dagger_container" -- sh -ec \
  'test "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" = tcp://10.42.0.1:18081;
   curl --fail --silent --show-error --max-time 20 \
     --noproxy "" --proxy http://10.42.0.1:17891 https://example.com/ >/dev/null'
timeout 180 scripts/sw-kubectl -n seafarer exec -i "$pipeline_pod" \
  -c "$dagger_container" -- dagger query <<'QUERY'
{container{from(address:"alpine:3.21"){withExec(args:["sh","-c","printf sw-tunnel-ok"]){stdout}}}}
QUERY
```

The selected container must provide `curl` and `dagger`; arrange those through
its approved pipeline definition rather than installing into running workloads.
Require `sw-tunnel-ok` from Dagger, a successful proxy HTTPS request, and a
completed representative build with a recorded bounded timeout appropriate to
that build. Inspect the tunnel journal for exits/restarts over the build window.
Short SSH/proxy/query checks establish reachability only; they do not prove
long-build reliability or eliminate every prior EOF cause. Automatic recovery
must be judged on a fresh session after a separately approved tunnel interruption,
not continuity of the interrupted build. No reliability result is claimed until
these live acceptance steps have been observed.
