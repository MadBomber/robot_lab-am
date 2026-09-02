## [Unreleased]

- **Standalone: dropped the robot_lab dependency.** Inference is a one-shot
  prompt, so `Inferrer` now calls RubyLLM directly (scoped
  `RubyLLM.context`, `assume_model_exists: true`) instead of building a
  `RobotLab::Robot`. Dependencies are now just `ruby_llm` + `myway_config`,
  making the gem useful outside the robot_lab-to environment. New `api_key`
  setting / `RLAM_API_KEY` (cascades to the provider's conventional
  env var, then a placeholder for keyless local servers); the
  `ROBOT_LAB_RUBY_LLM__OPENAI_API_BASE` coupling is gone. Injectable seam
  renamed `robot:` -> `chat:`.

- Continuous daemon: `am start|stop|status` — forked/detached process with pid
  file, per-tick heartbeat (`.robot_lab_am/heartbeat.json`), and debounced
  inference (new-activity flag + `--debounce` window; failed inference warns
  and retries instead of killing the daemon)
- launchd integration: `am install|uninstall` write/remove a per-repo agent
  plist (`RunAtLoad` + `KeepAlive`) that supervises `am start --foreground`
- `Collector`: fingerprint-based dedupe against `events.jsonl`, so repeated
  snapshots and daemon restarts never duplicate events
- `Redactor`: masks credential-shaped values (key/token/secret/password
  assignments, bearer tokens, known token formats) before events are stored
  or sent to the LLM
- `GitWatcher` no longer reports the gem's own `.robot_lab_am/` state
  directory as uncommitted work
- `am snapshot` now reports only *new* events and infers over the accumulated
  recent window of the event log
- MkDocs documentation site (Material theme) with GitHub Pages deploy workflow
- myway_config-based configuration (`RobotLab::Am::Config`, same pattern as
  robot_lab-to): bundled defaults → `~/.config/robot_lab_am/robot_lab_am.yml` →
  `RLAM_*` env vars → CLI flags. Tunables: provider, model, api_base,
  interval, debounce, inference_window, terminal_log. `am --help` now shows
  the effective interval/debounce

## [0.1.0] - 2026-08-31

- Initial release
