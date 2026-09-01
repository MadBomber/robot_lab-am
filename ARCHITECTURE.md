# robot_lab-am — component exploration

## Purpose

Sense what the human is doing inside a repo working directory (terminal
commands, Claude Code sessions, git activity) and distill it into a
current-goal/direction statement that `robot_lab-to` can use to seed a
takeover run — so "take over" starts from *what I was actually doing*
instead of a cold objective string typed at invocation time.

This is a survey of the component landscape, not a locked design.

**Decided:** continuous background daemon (not an on-demand snapshot) —
it should accumulate history and be able to notice drift across
sessions, not just seed a single takeover run.

## Signal sources (watchers)

| Source | What it gives us | How to get it |
|---|---|---|
| Git | commits, branch switches, diff shape, WIP (uncommitted changes) | `.git/refs` + `.git/HEAD` fs events, tailed (decided — see Deployment model); `git log` for detail once triggered |
| Claude Code sessions | the actual conversation — intent stated in plain language, plan/todo state, files touched, tool calls | JSONL transcripts under `~/.claude/projects/<slug>/*.jsonl` — already on disk per project, no new instrumentation needed |
| Terminal / shell | commands run outside Claude Code (tests, ad hoc scripts, greps) | **decided** — new `preexec` hook, see below |
| Editor/IDE | files opened/edited outside Claude Code | out of scope for v1 — high effort, low marginal signal since Claude Code sessions already show file touches |

The Claude Code transcripts are the richest, lowest-effort source: they
already contain natural-language intent, not just raw commands. Git is
the second-richest and trivial to poll.

### Terminal capture — what's actually there today

Checked `~/.bashrc_history` (sourced from `.bashrc`): it's a single
global `HISTFILE` (`~/.bash_history`) shared across *every* terminal
window and every repo on the machine, synced live after each command via
`PROMPT_COMMAND="...;syncHistory"`. Two things rule it out as a direct
source: no `HISTTIMEFORMAT` is set (entries carry no timestamp), and
nothing records `cwd` per command — so a raw command like `bundle exec
rake test` can't be attributed to a repo or a point in time from the
history file alone.

The good news: `.bashrc` already sources `~/.bash-preexec.sh`
(rcaloras/bash-preexec) and has a documented convention for add-on files
— `for file in ~/.bashrc__*; do sourceif "$file"; done`. So the clean
capture mechanism is a new `~/.bashrc__activity_monitor` that defines a
`preexec()` hook appending `{timestamp, cwd, command}` per command to a
dedicated log — no change to `HISTFILE`/`syncHistory`, fits the existing
plugin convention exactly, and gives real timestamp + repo attribution
that the flat history file can't.

**Built and verified** (2026-08-31): `~/.bashrc__activity_monitor` is in
place, registers via `preexec_functions+=(...)` (the array form, so it
composes with any other preexec hooks rather than clobbering them), and
appends to `~/.activity_monitor/terminal_activity.log`. It's tab-delimited
(`epoch.microseconds\tcwd\tcommand`), not JSON — it runs in `preexec`,
*before* the command executes, so it must not fork a subprocess or every
command you type gets delayed. Structuring/JSON-parsing this file is the
watcher's job on the read side, not the hook's. Takes effect in new shells
automatically; existing shells need `source ~/.bashrc__activity_monitor`.

## Ingestion & normalization

Each watcher emits events into one common shape:
`{ timestamp, repo, source, kind, summary, raw }`. `repo` is the
watched repo's root path — required, not optional. It matters most for
the terminal source: `~/.activity_monitor/terminal_activity.log` is
global across every shell on the machine (see Privacy & redaction), so
ingestion filters it down to lines whose `cwd` falls under the one
watched repo root, and only those become events. Git and Claude Code
events are already repo-scoped at the source (the watcher only points
at one repo's `.git` and one project's transcript dir), so `repo` is
constant per running daemon instance but still carried on every event
for consistency.

This mirrors the `audit_events` shape in `robot_lab-audit`
(event_type/timestamps/JSON payload) closely enough that reusing its
Hook-registration pattern (not its code — audit logs *robot* activity,
this logs *human* activity) is a reasonable template rather than
inventing a new convention.

## Storage

**Built and verified** (2026-09-01): JSONL, not SQLite —
`EventLog` (`lib/robot_lab/am/event_log.rb`) appends one JSON line per
Event to `.robot_lab_am/events.jsonl` in the watched repo. Matches
`robot_lab-to`'s `JsonlLogger`/`run.log` precedent over
`robot_lab-audit`'s SQLite one: the only consumer is an LLM
summarization pass over a bounded recent window, not ad hoc queries, so
SQLite's queryability wasn't worth the extra dependency.

## Inference engine

**Built and verified** (2026-09-01): `Inferrer` (`lib/robot_lab/am/inferrer.rb`)
takes a bounded window of Events and produces an `Intent` — goal
statement, confidence, evidence, open questions — via a `RobotLab::Robot`.

**Decided: local model, not a hosted provider.** Default is
`provider: :openai` / `model: "qwen/qwen3.8-27b"` against LM Studio's
OpenAI-compatible local server (`lms server start`, default
`http://localhost:1234/v1`, set via `ROBOT_LAB_RUBY_LLM__OPENAI_API_BASE`
if not already configured). Inference runs over your own activity
log — commits, terminal commands, Claude Code messages — so it
shouldn't require sending that anywhere or holding an API key.
Ran for real against `robot_lab_project`'s own history and this
session's own Claude Code transcript; produced a correct, well-formed
intent with no network call leaving the machine. `robot:` stays
injectable so no test exercises the real model.

This is the same "summarize a bounded context into a structured
decision" shape as `robot_lab-to`'s `Evals::Prose` (pairwise LLM judge)
and `DecisionManager` (YAML front matter + human-readable body) — reused
those patterns rather than inventing a new format.

## Intent artifact & handoff to robot_lab-to

Write the inferred intent to a well-known file — `.robot_lab_am/current_intent.md`
in the watched repo, front-matter + prose, same shape as `robot_lab-to`'s
decision files and the same naming convention as `robot_lab-to`'s own
`.robot_lab_to/runs/<run_id>/` run state. `robot_lab-to`'s `PromptBuilder` /
CLI would read it the way it already reads `notes.md`, either:
- as the seed `objective` when `robot-to` is invoked with no objective, or
- injected as extra context alongside an explicit objective.

This keeps `robot_lab-to` mostly unchanged — `robot_lab-am` produces a
file in a format `robot_lab-to` already knows how to consume.

## Deployment model — decided: continuous background daemon, single repo

Watches file system events (git refs, new Claude Code JSONL transcript
lines, the new `preexec` command log) continuously, accumulating a
running history, able to infer *drift* in direction over time and not
just seed a single takeover run.

**Scope: one repo per daemon instance, not a registry.** The goal (see
top of this doc) is "seed *this* repo's takeover with what I was
actually doing" — that only makes sense pointed at one repo at a time.
Watching several repos and reporting which one has fresh activity is a
different, fancier feature nobody's asked for; if it's ever wanted,
it's "run N instances," not a built-in registry.

This needs, in rough build order:
- **launchd agent** (`~/Library/LaunchAgents/*.plist`) — process
  supervision, start on login, restart on crash. One agent per watched
  repo.
- **repo root** — the one piece of config each instance needs: the path
  to the repo it's watching. Everything else (which `.git` to tail,
  which Claude Code project transcript dir, how to filter the terminal
  log) derives from it.
- **fs-event watchers** — `.git/refs` + `.git/HEAD` for git activity,
  the Claude Code project transcript dir, and the new preexec log file
  (filtered to this repo's `cwd` prefix — see Ingestion & normalization
  and Privacy & redaction), all tailed rather than polled where
  possible.
- **start/stop/status CLI** — `am start|stop|status` (the gem's
  executable is `am`, in `bin/`, per RubyGems convention — see
  `robot_lab-to`'s `bin/robot-to` for the sibling precedent). The
  command shape is scaffolded in `lib/robot_lab/am/cli.rb`; all three
  subcommands currently exit 1 with "not implemented yet." Still needed:
  a way to tell if the daemon is alive without guessing from a PID file
  alone (a heartbeat row/line is simplest).

## Privacy & redaction

The terminal log itself is necessarily global: `~/.bashrc__activity_monitor`
captures every command in every shell on the machine, because a
`preexec` hook can't know in advance which repo will later be "the
watched one." The opt-in boundary is enforced at ingestion, not
capture — the daemon only reads lines from `terminal_activity.log`
whose `cwd` falls under the one repo root it's watching (see Ingestion
& normalization); every other line in that file is never parsed,
stored, or sent to an LLM by this gem.

Within those in-scope lines, terminal history and even git diffs can
still contain secrets (API keys in `export` statements, credentials in
test fixtures). Whatever the watcher reads needs a redaction pass
before anything gets written to the event store or sent to an LLM.

## Relationship to existing gems

- `robot_lab-audit` — closest structural precedent for an event log fed by a Hook, but it logs *robot* activity, not human activity behind the scenes.
- `robot_lab-cyborg` — the conceptual mirror: cyborg makes a human an addressable peer *inside* a run; `robot_lab-am` senses a human *outside* any run and turns that into tasking context.
- `robot_lab-to` — the consumer. `NotesManager`, `DecisionManager`, and `PromptBuilder` are the integration points, not `Orchestrator` itself.
- `robot_lab-durable` — possible home for cross-session distilled intent (pgvector recall of "what have I generally been working toward"), but that's a v2 concern, not v1.

## Open questions

Resolved: single-repo vs multi-repo scope — see Deployment model above.
Watch one repo per daemon instance.

1. Does the inference pass re-run on every new event (commit, transcript
   line, command), or on a timer/debounce? Running it on every keystroke
   -equivalent event would be wasteful and noisy.
2. `~/.activity_monitor/terminal_activity.log` (not scoped to any one
   repo — see Privacy & redaction) grows forever as an append-only file
   across every shell on the machine. Does it need rotation independent
   of what `robot_lab-am`'s watcher reads from it?
