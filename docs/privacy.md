# Privacy & Redaction

An activity monitor watches *you* — so the privacy posture is the design, not
an afterthought. Three layers:

## 1. Local-first inference

Inference over your own activity log — commits, terminal commands, your Claude
Code messages — shouldn't require sending that log anywhere, or holding an API
key, just to summarize it.

The `Inferrer` therefore defaults to a **local model** served by LM Studio's
OpenAI-compatible API (`lms server start`, `http://localhost:1234/v1`),
explicitly not a hosted provider. With the default configuration, no network
call leaves the machine.

You *can* point it at any RubyLLM provider programmatically — that's a
deliberate, visible choice, never the default:

```ruby
RobotLab::Am::Inferrer.new(model: "claude-sonnet-4", provider: :anthropic)
```

## 2. Read-side scoping of the terminal log

The `preexec` hook is necessarily global: it captures every command in every
shell, because a shell hook can't know in advance which repo will later be
"the watched one."

The opt-in boundary is enforced **at ingestion, not capture**: the watcher
only parses lines from `~/.activity_monitor/terminal_activity.log` whose
`cwd` falls inside the one repo root it's watching. Every other line in that
file is never parsed, stored, or sent to an LLM by this gem.

Git and Claude Code sources are already repo-scoped at the source.

## 3. Redaction

Even in-scope activity can contain secrets — an API key in an `export`
statement, credentials in a test fixture showing up in a WIP diff summary.
The `Redactor` masks credential-shaped values in every event summary
**before** it is written to `events.jsonl` or shown to the LLM:

- `key` / `token` / `secret` / `password` / `credential` **assignments** —
  `export MY_TOKEN=…`, `password: …`, `api_key => …` (value masked, name kept)
- **Bearer tokens** — `Authorization: Bearer …`
- **Well-known token formats** wherever they appear — OpenAI (`sk-…`), AWS
  (`AKIA…`), GitHub (`ghp_…`, `github_pat_…`), Slack (`xoxb-…`)

```text
export ANTHROPIC_API_KEY=sk-ant-abc123…   →   export ANTHROPIC_API_KEY=[REDACTED]
```

!!! warning "Conservative by design — not a guarantee"
    Redaction is pattern-based. It catches the common shapes of leaked
    credentials, not every possible secret. Treat `.robot_lab_am/` like any
    other local development artifact: keep it out of version control
    (`/.robot_lab_am/` in `.gitignore`) and be deliberate if you ever switch
    inference to a hosted provider.

## What is stored, and where

Everything stays in the watched repo's `.robot_lab_am/` directory — redacted
event summaries, the inferred intent, and daemon runtime state. Nothing is
written outside the repo, and nothing is transmitted anywhere with the
default local-model configuration.

## Log rotation

The global terminal log belongs to your dotfiles, and rotating or truncating
it there is always safe for this gem: the watcher takes only the most recent
in-scope lines each poll, and fingerprint dedupe means rotation can never
cause re-ingestion.
