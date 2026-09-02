# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Gem Does

`robot_lab-am` ("activity monitor") is a **standalone** gem (RobotLab-family
naming, but no robot_lab dependency — just `ruby_llm` + `myway_config`) that
watches a repo working directory — git activity, Claude Code session
transcripts, and terminal commands — and infers the current goal or
direction of work via a one-shot local-LLM call. The inferred intent seeds
[`robot_lab-to`](https://github.com/MadBomber/robot_lab-to)'s takeover runs with
real context instead of a cold objective string, but any tool can consume it.

**Status: complete v1 — one-shot pipeline and continuous daemon.**
`am snapshot` collects git/Claude Code/terminal activity, infers a goal via
a local LLM, and writes `.robot_lab_am/current_intent.md`. `am start`/`stop`/
`status` run the continuous daemon (detached, pid file + heartbeat,
debounced inference), and `am install`/`uninstall` manage a launchd agent
that supervises it. All verified end to end against a live daemon and a
real LM Studio model. See `ARCHITECTURE.md` for the component survey and
decisions.

## Commands

```bash
bundle exec rake test          # all tests
bundle exec rake test_file[path]  # single test file
asgard quality                 # all *_check gates in parallel (tests + coverage,
                               #   rubocop, flog, flay, reek, fasterer, typos, ...)
asgard doc_builder             # build the MkDocs site
asgard doc_server              # serve docs locally
bin/console                    # IRB shell with gem loaded
bin/am --help                  # CLI help
bin/am snapshot [--repo PATH]  # one-shot: collect + infer + write intent
bin/am start [--foreground]    # start the daemon (detached by default)
bin/am stop|status             # stop / inspect the daemon
bin/am install|uninstall       # manage the launchd agent plist
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
- **RubyLLM directly, no robots** (2026-09-02): the inference is a
  one-shot prompt, so `Inferrer` calls
  `RubyLLM.context.chat(model:, provider:, assume_model_exists: true)`
  in a scoped context (host apps' global RubyLLM config inherited,
  never mutated). The gem no longer depends on `robot_lab` — deps are
  `ruby_llm` + `myway_config` only, so it's usable outside the
  robot_lab-to environment. Injectable seam is `chat:` (responds to
  `#ask(prompt)` returning a message with `#content`).
- **Configuration**: `Config < MywayConfig::Base` (same pattern as
  robot_lab-to). Cascade: `config/defaults.yml` →
  `~/.config/robot_lab_am/robot_lab_am.yml` (flat keys) →
  `RLAM_*` env vars → CLI flags / constructor keywords.
  Settings: provider, model, api_base, interval, debounce,
  inference_window, terminal_log. `Am.config` is the memoized
  process-wide instance (`Am.reset_config!` in tests). Caveat: the
  defaults.yml-backed ivars are assigned by `super()` — never pre-nil
  them in `Config#initialize`.

- **Inference cadence**: debounced — the daemon polls watchers every
  `--interval` seconds (default 15) but re-infers only when new events
  have arrived since the last inference, and at most once per
  `--debounce` seconds (default 300). A failed inference (LLM down) is
  retried on the same debounce, and never kills the daemon.
- **Redaction**: `Redactor` masks credential-shaped values (key/token/
  secret/password assignments, bearer tokens, well-known token formats)
  before any event is stored or sent to the LLM.
- **Dedupe**: `Collector` fingerprints events against the existing
  `events.jsonl`, so repeated snapshots/daemon restarts never duplicate
  log lines. `wip` events dedupe on summary (their timestamps are
  collection-time), everything else on timestamp + summary.

## Testing

Minitest with SimpleCov (branch coverage tracked). Same conventions as the
other gems in this family — see the workspace-level `CLAUDE.md` and
`.claude/rules/rubocop.md`.
