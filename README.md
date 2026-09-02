# robot_lab-am

A standalone activity monitor that watches what's happening in a repo working
directory — git activity, Claude Code session transcripts, and terminal
commands — and infers the current goal/direction using a local LLM via
[RubyLLM](https://rubyllm.com). The inferred intent is written to a well-known
artifact (`.robot_lab_am/current_intent.md`) that any tool can read;
[`robot_lab-to`](https://github.com/MadBomber/robot_lab-to) uses it to seed a
takeover run with real context instead of a cold objective string, but nothing
here depends on the [RobotLab](https://github.com/MadBomber/robot_lab)
framework.

**Documentation: [madbomber.github.io/robot_lab-am](https://madbomber.github.io/robot_lab-am)**

## Installation

Add to your Gemfile:

```ruby
gem "robot_lab-am"
```

Dependencies are just `ruby_llm` and `myway_config` — no robot framework
required.

## Usage

```bash
am snapshot                 # one-shot: collect activity, infer the goal, write
                            # .robot_lab_am/current_intent.md in the repo

am start                    # start the continuous daemon for this repo (detached)
am status                   # is it running? heartbeat, event count, last inference
am stop                     # stop it

am install                  # write a launchd agent so the daemon runs at login
am uninstall                # remove the launchd agent

# All commands accept --repo PATH (default: current directory).
# `am start` also accepts --foreground, --interval N (poll seconds, default 15),
# and --debounce N (minimum seconds between inference runs, default 300).
```

The daemon polls three signal sources — git commits and uncommitted changes,
your own messages in Claude Code session transcripts, and terminal commands run
inside the repo — appends new (redacted, deduplicated) events to
`.robot_lab_am/events.jsonl`, and re-infers `.robot_lab_am/current_intent.md`
on a debounced cadence whenever activity arrives.

### Prerequisites

- **Local LLM**: inference defaults to LM Studio's OpenAI-compatible server on
  `localhost:1234` (`lms server start`) so your activity log never leaves the
  machine. Any RubyLLM provider/model can be passed to `Inferrer` instead.
- **Terminal capture** (optional): commands are read from
  `~/.activity_monitor/terminal_activity.log`, written by a bash `preexec` hook
  (`~/.bashrc__activity_monitor` in your dotfiles). Without the hook, git and
  Claude Code signals still work.

## Configuration

Settings cascade via [myway_config](https://github.com/MadBomber/myway_config),
lowest to highest precedence:

1. Bundled defaults
2. User config file — `~/.config/robot_lab_am/robot_lab_am.yml` (flat keys)
3. `RLAM_*` environment variables
4. CLI flags (`--interval`, `--debounce`)

### Environment variables

| Variable | Default | Meaning |
|----------|---------|---------|
| `RLAM_PROVIDER` | `openai` | RubyLLM provider used for inference |
| `RLAM_MODEL` | `qwen/qwen3.8-27b` | Model name |
| `RLAM_API_BASE` | `http://localhost:1234/v1` | OpenAI-compatible server URL (applied to the `openai` provider) |
| `RLAM_API_KEY` | *(none)* | API key; unset falls back to the provider's own env var, then a placeholder (fine for LM Studio) |
| `RLAM_INTERVAL` | `15` | Seconds between daemon watcher polls |
| `RLAM_DEBOUNCE` | `300` | Minimum seconds between inference runs |
| `RLAM_INFERENCE_WINDOW` | `100` | Most recent events sent to the model |
| `RLAM_TERMINAL_LOG` | `~/.activity_monitor/terminal_activity.log` | Preexec command log path |

```bash
# point inference at a different local model/server
export RLAM_PROVIDER=openai
export RLAM_MODEL=llama-3.3-70b
export RLAM_API_BASE=http://localhost:8080/v1
```

Notes:

- `am --help` prints the *currently effective* interval/debounce, so you can
  see what your config file and environment resolve to.
- API keys cascade: `RLAM_API_KEY` if set, else the chosen provider's
  conventional env var (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, …), else a
  placeholder — which is all a local LM Studio server needs. The default
  local setup requires no key; your activity log never leaves the machine.
- Inference runs in a scoped RubyLLM context, so embedding robot_lab-am in a
  larger app never mutates that app's global RubyLLM configuration.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run
`bundle exec rake test` to run the tests. `bin/console` gives an interactive
prompt with the gem loaded.

```bash
bundle exec rake test          # all tests
asgard quality                 # all quality gates (tests + coverage, rubocop,
                               #   flog, flay, reek, fasterer, typos, ...)
asgard doc_builder             # build the MkDocs site
asgard doc_server              # serve docs locally
bin/console                    # IRB shell with gem loaded
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
