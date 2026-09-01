# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Gem Does

`robot_lab-am` ("activity monitor") is a planned [RobotLab](https://github.com/MadBomber/robot_lab)
extension gem that watches a repo working directory — git activity, Claude Code
session transcripts, and terminal commands — and infers the current goal or
direction of work. The inferred intent is meant to seed
[`robot_lab-to`](https://github.com/MadBomber/robot_lab-to)'s takeover runs with
real context instead of a cold objective string typed at invocation time.

**Status: working one-shot pipeline, no daemon yet.** `am snapshot` really
collects git/Claude Code/terminal activity, infers a goal via a local LLM,
and writes `.robot_lab_am/current_intent.md` — verified end to end against
`robot_lab_project`'s own history. `start`/`stop`/`status` (the continuous
daemon from ARCHITECTURE.md) are still stubs. See `ARCHITECTURE.md` for
the full component survey and decisions made so far.

## Commands

```bash
bundle exec rake test          # all tests
bundle exec rake test_verbose  # verbose test output
bundle exec rake test_file[path]  # single test file
bundle exec rake quality       # tests + coverage + rubocop + flog + flay
bin/console                    # IRB shell with gem loaded
bin/am --help                  # CLI help
bin/am snapshot [--repo PATH]  # the working command — see below
```

## Decided so far (see ARCHITECTURE.md for detail)

- **Deployment model**: continuous background daemon, not an on-demand
  snapshot — it should notice drift across sessions, not just seed one
  takeover run.
- **Terminal capture**: `~/.bashrc_history` is a single global `HISTFILE`
  shared across every terminal and repo, with no timestamps or cwd, so it
  can't attribute a command to a repo or a point in time. Instead,
  `~/.bashrc__activity_monitor` (outside this repo, in the user's dotfiles)
  registers a `preexec_functions` hook that appends
  `epoch.microseconds\tcwd\tcommand` to `~/.activity_monitor/terminal_activity.log`
  on every command. It's tab-delimited, not JSON, because it runs in
  `preexec` — *before* the command executes — so it must not fork a
  subprocess or every command gets delayed. Parsing/structuring that file
  is this gem's job on the read side.
- **Storage**: JSONL (`.robot_lab_am/events.jsonl` in the watched repo),
  not SQLite — the only consumer is an LLM summarization pass, not ad
  hoc queries.
- **Inference model**: local, not hosted. `Inferrer` defaults to
  `provider: :openai` / `model: "qwen/qwen3.8-27b"` against LM Studio's
  OpenAI-compatible server (`lms server start`, `localhost:1234/v1`) —
  explicitly not Anthropic. Your own activity log shouldn't have to
  leave the machine, or need an API key, just to be summarized.

## Open questions

See the "Open questions" section at the bottom of `ARCHITECTURE.md` —
inference cadence and log rotation for the terminal log are still
unresolved. (Single-repo vs multi-repo scope is resolved: one repo per
daemon instance.)

## Testing

Minitest with SimpleCov (branch coverage tracked). Same conventions as the
other gems in this family — see the workspace-level `CLAUDE.md` and
`.claude/rules/rubocop.md`.
