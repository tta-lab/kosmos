# N5 Dagger consumer bridge

Home Manager's Neil user unit `n5-dagger-tunnel.service` owns one foreground
SSH connection to `root@192.168.1.88`. It reuses `/home/neil/.ssh/id_ed25519`
and `/home/neil/.ssh/known_hosts` with strict authentication, no agent and no
ambient SSH config. No identity is copied or newly registered.

Both `127.0.0.1:8080` and CNI-only `10.42.0.1:8080` forward to N5's
`127.0.0.1:8080`. Only cni0 allows inbound 8080. Missing cni0 or a failed bind
ends SSH; systemd retries after five seconds. Keepalives detect a dead connection
at 15-second intervals, count three. Reconnect serves new builds; interrupted
builds cannot resume. Unit state and a TCP connection do not prove Engine health.

The existing `devops/dagger` Service keeps its DNS and allocated ClusterIP
(observed `10.43.245.204`); apply updates it in place, without a selector.
`dagger-n5` EndpointSlice points its grpc port to the CNI listener. NUC CLI,
Mac Kepos `127.0.0.1:18080`, and SW's SSH `18080` / pod bridge `18081` still
use their existing endpoints. Kosmos remains the relay and Mihomo host and
cannot yet be shut down. SW Mihomo `17890` / `17891` and its reverse SSH
contract are unchanged. N5 Engine proxy readiness depends on spec4393.

## Operator handoff (never part of Worker verification)

1. Recheck that N5 spec4393 is deployed, strict SSH authentication works, and
   both old and new Engines have no active builds. Block new CI submissions,
   record current SW agent replicas, and pause agents only after running work
   finishes. Earlier idle observations are not current evidence.
2. Save only the old public Engine manifest for rollback, before updating the
   source checkout: render `tanka/environments/devops/main.jsonnet` at fixed
   base `593e95766546b1417399fc6b36b1512358ce1a11` in an operator temporary
   source directory, retaining `daggerDaemonSet`, `daggerConfig`, `daggerCa`
   and `daggerService` (restore the Service in place).
   No cache copy or backup is required.
3. Recheck `devops/daemonset/dagger` UID against
   `f137cd3b-85f5-4b75-a73b-d7b5ae33afa4` and inspect the actual loopback 8080
   owner. A mismatch requires investigation before proceeding. Delete only
   that verified old DaemonSet, wait for its pods to terminate, and confirm
   loopback 8080 is free. Do not restart k3s or prune the namespace.
4. Only now activate the reviewed source with `nh os switch . -H wsl` as
   Neil. Home Manager may start the new unit during activation. Inspect its
   journal and both listeners; require exactly loopback and cni0 ownership.
5. Render the reviewed devops environment. Apply only `daggerService` and
   `daggerEndpointSlice` from that render (as a Kubernetes List); never delete
   or recreate the Service. Confirm its existing ClusterIP is retained, its
   selector is absent, and no stale controller-managed Dagger EndpointSlices
   remain after old pod removal. Remove only the obsolete `dagger-engine` and
   `dagger-sw-ca` ConfigMaps after confirming they have no remaining consumer.
6. Verify NUC `tcp://127.0.0.1:8080`, Mac's existing Kepos binding, a test-owned
   ko pod using `tcp://dagger.devops.svc.cluster.local:8080`, and the selected
   SW CI container using its existing `tcp://10.42.0.1:18081`. Require a bounded
   real Dagger alpine pull/exec query and representative build on N5, plus SW
   HTTPS via `10.42.0.1:17891` as described in [SW acceptance](sw-build-tunnel.md#observable-acceptance).
   Record build IDs/results and tunnel restarts. Restore the recorded CI agent
   replicas and submissions only after acceptance, or after verified rollback.

For rollback, first block submissions and confirm both Engines idle, stop
`n5-dagger-tunnel` and verify both local listeners released. Delete only
`dagger-n5` EndpointSlice, restore the saved old Engine ConfigMaps/DaemonSet,
and restore the old Service selector/port declaration in place. Verify old
Engine readiness and all consumer paths before restoring CI. The new unit must
remain stopped until a later deliberate handoff. Old cache stays untouched at
`/var/lib/kosmos-k3s/dagger`; it is acceleration data, with no business-data
restore or cache migration. Standard apply of the new source cannot revive the
old Engine. A later activation may restart the enabled relay, so repeat the
port-owner handoff before any such activation while rolled back.
