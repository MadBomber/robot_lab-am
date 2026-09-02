# Getting Started

## Installation

Add to your Gemfile:

```ruby
gem "robot_lab-am"
```

Despite the family name, the gem is standalone: its only dependencies are
[RubyLLM](https://rubyllm.com) (for the one-shot inference call) and
myway_config. No robot framework required.

Or install directly:

```bash
gem install robot_lab-am
```

This provides the `am` executable.

## Prerequisite: a local LLM

Inference runs against LM Studio's OpenAI-compatible server by default, so
your activity log is summarized entirely on your own machine:

```bash
lms server start    # serves http://localhost:1234/v1
```

The default model is `qwen/qwen3.8-27b`. To use a different local server or
model, set it once in your config file:

```yaml
# ~/.config/robot_lab_am/robot_lab_am.yml
model: llama-3.3-70b
api_base: http://localhost:8080/v1
```

or per-invocation via `RLAM_MODEL` / `RLAM_API_BASE`
(see [Configuration](cli-reference.md#configuration)). Any RubyLLM
provider/model can be substituted — but the default is deliberately not a
hosted provider. See [Privacy & Redaction](privacy.md).

## Optional prerequisite: terminal capture

Commands you run in a terminal are read from
`~/.activity_monitor/terminal_activity.log`, written by a bash `preexec` hook
in your dotfiles (`~/.bashrc__activity_monitor`, registered via
[rcaloras/bash-preexec](https://github.com/rcaloras/bash-preexec)). Each line
is tab-delimited: `epoch.microseconds<TAB>cwd<TAB>command`.

Without the hook, the terminal source is simply empty — git and Claude Code
signals still work, and they are the richer sources anyway.

!!! note "Why a custom hook instead of bash history?"
    `~/.bash_history` is global across every terminal and repo, with no
    timestamps and no working directory — a raw `bundle exec rake test` line
    can't be attributed to a repo or a point in time. The `preexec` hook
    records both. It writes plain tab-delimited text (not JSON) because it
    runs *before* every command executes and must not fork a subprocess.

## Your first snapshot

From inside any git repo you've been working in:

```bash
am snapshot
```

This runs the whole pipeline once:

1. Collects recent git commits + uncommitted changes, your own messages from
   the repo's most recent Claude Code session, and terminal commands run
   inside the repo
2. Redacts credential-shaped values and appends the new events to
   `.robot_lab_am/events.jsonl`
3. Asks the local model to infer your current goal
4. Writes `.robot_lab_am/current_intent.md` and prints it

Repeated snapshots are safe: events are deduplicated against the log, so
nothing is double-counted.

## Running continuously

```bash
am start     # detaches; writes .robot_lab_am/daemon.log
am status    # pid, heartbeat age, event count, last inference
am stop
```

See [The Daemon](daemon.md) for lifecycle details, tuning, and launchd
supervision.

## Ignore the state directory

Add the gem's state directory to the watched repo's `.gitignore`:

```gitignore
/.robot_lab_am/
```

(The daemon already excludes its own state directory from the git activity it
reports, but there's no reason to commit event logs.)

## Handing off to robot_lab-to

`robot_lab-am` produces a file in a format `robot_lab-to` already knows how to
consume — front matter + prose, the same shape as its decision files. Invoke
`robot-to` with no objective to let the inferred intent seed the run, or with
an explicit objective to have the intent injected as extra context.
