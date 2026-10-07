# Android development

WSL installs JDK 21 and a Nix-managed Android SDK: platform-tools 37.0.1
(adb/fastboot), command-line tools 22.0 (sdkmanager/avdmanager), Android API 36,
and build-tools 35.0.0. This matches the inspected Mac SDK. `JAVA_HOME` and
`ANDROID_HOME` are available in newly started Fish/Zsh sessions. Use a project's
Gradle wrapper. SDK components belong to `modules/wsl/android-development.nix`;
the SDK in the Nix store is read-only, so change that module instead of using
`sdkmanager` to install components there.

## Mac ADB server

Mac runs the ADB server on `127.0.0.1:5037`. The per-user LaunchAgent source is
`macos/launchagents/io.guion.adb.plist`, installed at
`~/Library/LaunchAgents/io.guion.adb.plist`. It runs `adb server nodaemon`, so
launchd owns the process and restarts it after exit. It starts on GUI login;
the Mac must remain awake and the phone must authorize its existing USB key.

Mac's unmanaged `~/.config/kepos/config.toml` publishes:

```toml
[[services]]
id = "adb"
name = "Mac ADB"
kind = "tcp"
source = { local_port = 5037 }
allow = ["e499c38286e33f481b64888c68e8a877872c17991d1465ae71b89272db80a304"]
```

Restart Mac's Kepos Desktop after editing this TOML so it loads the service.

NUC binds Mac's `adb` service through Kepos at `127.0.0.1:15037`. The binding
in `kepos/peer-policy.jsonnet` routes TCP to Mac's ADB server on port 5037.
The Mac ADB server and its published service configuration are managed
separately. Local NUC ADB continues to use its default port 5037.

After updating the Kosmos checkout on NUC, render the policy:

```bash
just kepos-policy-render
```

This atomically replaces `~/.config/kepos/peer.toml`. Kepos hot-reloads a valid
policy within one second; no NixOS rebuild or Kepos restart is needed on NUC.

Select the Mac server explicitly for each ADB command, including this read-only
device check:

```bash
adb -H 127.0.0.1 -P 15037 devices -l
```

Use the same `-H 127.0.0.1 -P 15037` options for other Mac ADB commands.
Plain `adb devices -l` still targets local NUC ADB on port 5037.

Validate launchd with `plutil -lint` and `launchctl print gui/501/io.guion.adb`,
then confirm the socket and actual `adb devices -l` result. `adb kill-server`
is not a persistent stop while this LaunchAgent is loaded; use
`launchctl bootout gui/501/io.guion.adb` to stop it.
