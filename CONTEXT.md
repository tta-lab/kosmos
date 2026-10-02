# Kosmos Service Hosting

Kosmos hosts applications and makes selected capabilities available to trusted devices or public visitors. This glossary names the service access, approval, and recovery concepts within that environment.

## Language

**Public Forgejo Access**:
The ability of an Internet client to reach the hosted Forgejo instance. Public
access does not imply permission to read a repository or artifact anonymously.
_Avoid_: Public repositories, open-source publication

**Anonymous Forgejo Content**:
Forgejo content readable without signing in, including repository content and
any separately accessible wiki, issue, release, attachment, or package.
_Avoid_: Public Forgejo Access

**Forgejo Publication Audit**:
A review of which hosted repositories and associated artifacts are intended
for anonymous access before public Forgejo access is enabled.
_Avoid_: Connectivity smoke test

**Approval Inbox**:
A private queue where a human reviews proposed actions before an agent may proceed.
_Avoid_: Dashboard, task list

**Action**:
A proposed operation awaiting a human decision.
_Avoid_: Request, task

**Decision**:
The durable record that an action was approved or rejected.
_Avoid_: Response, status

**Polling Service**:
A service that retrieves an action's decision from the Approval Inbox instead of receiving a callback.
_Avoid_: Callback consumer

**Watcher**:
An optional source monitor that creates actions when it observes matching external events.
_Avoid_: Polling Service

**Source Recovery Backup**:
An encrypted offsite snapshot that preserves Forgejo's Git repositories and a
consistent SQLite snapshot, but intentionally excludes Forgejo Packages/OCI
artifacts. It protects source recovery, not complete Forgejo-instance recovery.
_Avoid_: Full backup, mirror

**Full Forgejo Backup**:
A synchronized copy of every Forgejo storage domain, including database,
repositories, attachments, LFS objects, and Packages/OCI artifacts, from which
the complete Forgejo instance can be recovered.
_Avoid_: Source Recovery Backup

**Backup Snapshot**:
An immutable, encrypted restic record of a selected source-recovery state.
Snapshots share unchanged data blocks; retention removes only snapshots whose
data is no longer shared.
_Avoid_: Archive, mirror
