# How It Works

## Signal sources

Three watchers read what's already on disk — no instrumentation of your tools:

| Source | What it yields | Read from |
|--------|----------------|-----------|
| **Git** | Recent commits, plus current uncommitted changes as a WIP summary | `git log` / `git status` in the watched repo |
| **Claude Code** | Your own plain-language messages from the repo's most recent session — stated intent, not just commands | Transcripts under `~/.claude/projects/<slug>/*.jsonl` |
| **Terminal** | Commands run inside the repo (tests, greps, ad hoc scripts) | The global `preexec` log, filtered to lines whose `cwd` is inside the repo |

The Claude Code transcripts are the richest, lowest-effort source: they
contain natural-language intent. Git is second-richest. The terminal source is
optional — see [Getting Started](getting-started.md#optional-prerequisite-terminal-capture).

Two deliberate exclusions: the `ClaudeWatcher` skips synthetic user turns that
are really tool-result payloads (only things *you* typed count), and the
`GitWatcher` filters the gem's own `.robot_lab_am/` state directory out of the
WIP summary — the monitor must not observe its own footprint.

## Events

Every watcher emits one normalized shape:

```json
{"timestamp": "2026-09-01T23:22:38Z",
 "repo": "/Users/you/src/my_project",
 "source": "terminal",
 "kind": "command",
 "summary": "asgard quality"}
```

`source`/`kind` pairs: `git`/`commit`, `git`/`wip`, `claude_code`/
`user_message`, `terminal`/`command`.

## Collection: redact, dedupe, append

Both `am snapshot` and every daemon tick run the same collection pass:

1. Ask all three watchers for their recent window of events
2. **Redact** credential-shaped values in each summary
   ([details](privacy.md#3-redaction))
3. **Dedupe** against everything already in `events.jsonl`, by fingerprint
4. Append only what's genuinely new

Fingerprints make collection idempotent: repeated snapshots, daemon restarts,
and overlapping watcher windows never duplicate a line. Most events
fingerprint on `timestamp + source + kind + summary`; WIP events drop the
timestamp (it's collection time, not activity time), so an unchanged dirty
tree is recorded once, and again only when it actually changes.

## Storage: JSONL, not SQLite

`events.jsonl` is an append-only file, one JSON object per line. The only
consumer is an LLM summarization pass over a bounded recent window — not ad
hoc queries — so a database wasn't worth the dependency. (Its structural
sibling, [`robot_lab-audit`](https://github.com/MadBomber/robot_lab-audit),
made the opposite call because audit logs *are* queried.)

## Inference

The `Inferrer` takes the last 100 events, renders them oldest-to-newest as a
timestamped activity log, and asks the model — a one-shot
[RubyLLM](https://rubyllm.com) chat in a scoped context, no agent framework —
for exactly this YAML:

```yaml
goal: <one or two sentences on what they're currently working toward>
confidence: <low|medium|high>
evidence:
  - <short reference to a specific event that supports the goal>
open_questions:
  - <anything ambiguous or unresolved>
```

The response is parsed defensively — fenced YAML is extracted, and a
malformed reply degrades to using the raw text as the goal with
`confidence: unknown` rather than failing.

A repo with no recent activity short-circuits to a "No recent activity
detected" intent without calling the model at all.

## The intent artifact

`IntentWriter` renders the result to `.robot_lab_am/current_intent.md` —
YAML front matter (confidence, timestamp, evidence, open questions) followed
by the goal as prose. The format and the `.robot_lab_<name>/` directory
convention deliberately match `robot_lab-to`'s decision files and run state,
so the consumer needs nothing new to read it.
