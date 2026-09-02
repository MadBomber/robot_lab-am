# The Daemon

`am start` runs the activity monitor continuously for one repo: polling the
watchers, accumulating events, and re-inferring the current intent whenever
activity arrives. This is what lets it notice *drift* in direction across
sessions, not just seed a single takeover run.

## Lifecycle

```bash
am start                   # fork + detach; logs to .robot_lab_am/daemon.log
am start --foreground      # stay attached to the terminal (what launchd runs)
am status                  # liveness + heartbeat detail
am stop                    # SIGTERM, waits up to 10s for a clean exit
```

`am status` when running:

```text
daemon running for /Users/you/src/my_project (pid 41820)
  heartbeat: 2s ago
  events logged since start: 14
  last inference: 2026-09-01T23:22:38Z
```

Exit codes follow convention: `status` exits `0` when the daemon is running
and `1` when it isn't, so it works in scripts.

## Inference cadence — debounced, not per-event

Re-running inference on every keystroke-equivalent event would be wasteful and
noisy. Instead:

- The daemon polls all three watchers every **`--interval`** seconds
  (default **15**).
- New events set a *dirty* flag; inference runs only when the flag is set
  **and** at least **`--debounce`** seconds (default **300**) have passed
  since the last inference.
- The first activity after startup infers immediately.

```bash
am start --interval 5 --debounce 60    # snappier, chattier
```

Prefer a persistent setting? Put it in `~/.config/robot_lab_am/robot_lab_am.yml`
or `RLAM_INTERVAL`/`RLAM_DEBOUNCE` — flags always win over
both (see [Configuration](cli-reference.md#configuration)).

A failed inference (LM Studio not running, malformed response) is logged to
`daemon.log`, keeps the dirty flag set, and retries once the next debounce
window opens. It never kills the daemon.

## Heartbeat

Every tick, the daemon rewrites `.robot_lab_am/heartbeat.json`:

```json
{"pid": 41820, "updated_at": "2026-09-01T23:23:08Z",
 "events_total": 14, "last_inference_at": "2026-09-01T23:22:38Z"}
```

The heartbeat also beats **before** each inference call — a local model can
take 25+ seconds to respond, and a live daemon in the middle of a slow
inference must not look dead. `am status` combines the heartbeat with a real
process-table check (not just the pid file's existence), and detects, reports,
and cleans up stale pid files left by a crash.

## State files

Everything lives under `.robot_lab_am/` in the watched repo:

| File | Purpose |
|------|---------|
| `events.jsonl` | Append-only event log — one JSON line per event |
| `current_intent.md` | The inferred intent artifact ([format](index.md#what-it-produces)) |
| `daemon.pid` | Pid of the running daemon |
| `heartbeat.json` | Rewritten every tick |
| `daemon.log` | Stdout/stderr of the detached daemon |

## launchd supervision

To have macOS start the daemon at login and restart it if it crashes:

```bash
am install
```

This writes `~/Library/LaunchAgents/com.madbomber.robot-lab-am.<repo>-<hash>.plist`
(one agent per watched repo) configured with `RunAtLoad` and `KeepAlive`,
running `am start --foreground` under launchd's supervision. Installing only
writes the file — the command prints the `launchctl` invocations to actually
load it:

```bash
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.madbomber.robot-lab-am.<repo>-<hash>.plist
```

`am uninstall` removes the plist (and prints the matching `launchctl bootout`
command if the agent was loaded).

!!! tip "One repo per daemon"
    Watching several repos is "run N instances" — one `am start` (or one
    `am install`) per repo — not a built-in registry. Each instance derives
    everything it needs from its single `--repo` root.
