# CLI Reference

```text
Usage: am COMMAND [options]
```

## Commands

### `am snapshot`

One-shot pipeline: collect new activity, infer the current goal, write and
print `.robot_lab_am/current_intent.md`.

```bash
am snapshot
am snapshot --repo ~/src/other_project
```

Prints how many *new* events were collected (dedupe means a quiet repo
reports `0` but still re-infers over the accumulated recent window).

### `am start`

Start the daemon for the repo. Forks and detaches by default; output goes to
`.robot_lab_am/daemon.log`. Fails with exit `1` if a daemon is already
running for the repo.

```bash
am start
am start --foreground                 # stay attached (what launchd runs)
am start --interval 5 --debounce 60   # tune the cadence
```

### `am stop`

Send SIGTERM to the running daemon and wait (up to 10s) for a clean exit.
Detects a stale pid file (crash leftover), removes it, and reports it.

### `am status`

Report liveness — pid checked against the real process table, plus heartbeat
detail when available. Exits `0` if running, `1` if not, so it's scriptable:

```bash
am status && echo "monitoring" || am start
```

### `am install` / `am uninstall`

Write (or remove) the per-repo launchd agent plist under
`~/Library/LaunchAgents/`. Only touches the file; prints the `launchctl
bootstrap` / `bootout` commands for you to run. See
[launchd supervision](daemon.md#launchd-supervision).

## Options

| Option | Applies to | Default | Meaning |
|--------|-----------|---------|---------|
| `--repo PATH` | all commands | current directory | The repo to watch. Everything else derives from this one path. |
| `--interval N` | `start`, `install` | `15` | Seconds between watcher polls |
| `--debounce N` | `start`, `install` | `300` | Minimum seconds between inference runs |
| `--foreground` | `start` | off | Run attached to the terminal instead of detaching |
| `-h`, `--help` | — | — | Show usage |
| `-v`, `--version` | — | — | Print version and exit |

With `install`, `--interval`/`--debounce` are baked into the plist's program
arguments.

`am --help` shows the *currently effective* interval/debounce — i.e. what your
config file and environment resolve to, not the bundled defaults.

## Configuration

Settings cascade through [myway_config](https://github.com/MadBomber/myway_config)
(the same pattern as `robot_lab-to`), lowest to highest precedence:

1. Bundled defaults (`lib/robot_lab/am/config/defaults.yml`)
2. User config file — `~/.config/robot_lab_am/robot_lab_am.yml`
   (or `$XDG_CONFIG_HOME/robot_lab_am/robot_lab_am.yml`)
3. `RLAM_*` environment variables
4. CLI flags / constructor keywords

The user config file uses flat keys:

```yaml
# ~/.config/robot_lab_am/robot_lab_am.yml
interval: 30
debounce: 600
model: qwen/qwen3.8-27b
```

| Setting | Default | Env var | Meaning |
|---------|---------|---------|---------|
| `provider` | `openai` | `RLAM_PROVIDER` | RubyLLM provider for inference |
| `model` | `qwen/qwen3.8-27b` | `RLAM_MODEL` | Model name |
| `api_base` | `http://localhost:1234/v1` | `RLAM_API_BASE` | OpenAI-compatible server URL (applied to the `openai` provider) |
| `api_key` | *(none)* | `RLAM_API_KEY` | API key — see [API keys](#api-keys) below |
| `interval` | `15` | `RLAM_INTERVAL` | Seconds between daemon polls |
| `debounce` | `300` | `RLAM_DEBOUNCE` | Minimum seconds between inference runs |
| `inference_window` | `100` | `RLAM_INFERENCE_WINDOW` | Most recent events sent to the model |
| `terminal_log` | `~/.activity_monitor/terminal_activity.log` | `RLAM_TERMINAL_LOG` | Preexec command log path |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (for `status`: daemon is running) |
| `1` | Error — unknown command/option, daemon not running, already running, start/stop timeout |
| `130` | Interrupted (Ctrl-C) |

## API keys

None are needed for the default local LM Studio setup. The key passed to
RubyLLM cascades: `api_key` config / `RLAM_API_KEY` if set → the
chosen provider's conventional env var (`OPENAI_API_KEY`,
`ANTHROPIC_API_KEY`, …) → a placeholder value, which keyless local servers
accept. Inference runs in a scoped RubyLLM context, so a host application's
global RubyLLM configuration is inherited but never mutated.
