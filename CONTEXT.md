# Kosmos Service Hosting

Kosmos hosts private applications and makes selected capabilities available to trusted devices. This glossary names the concepts that define the Impri approval workflow within that environment.

## Language

**Approval Inbox**:
A private queue where a human reviews proposed actions before an agent may proceed.
_Avoid_: Dashboard, task list

**Action**:
A proposed operation awaiting a human decision.
_Avoid_: Request, task

**Decision**:
The durable record that an action was approved or rejected.
_Avoid_: Response, status

**Telegram Approval**:
A decision made through an Impri approval message by an explicitly authorized Telegram user.
_Avoid_: Telegram notification

**Polling Service**:
A service that retrieves an action's decision from the Approval Inbox instead of receiving a callback.
_Avoid_: Callback consumer

**Watcher**:
An optional source monitor that creates actions when it observes matching external events.
_Avoid_: Polling Service
