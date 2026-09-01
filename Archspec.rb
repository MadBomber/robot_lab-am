# robot_lab-am is a plain Ruby gem (RobotLab::Am), not a Rails app -- there is
# no app/ tree, no controllers/models/views, so the :rails preset doesn't
# apply. These are the actual boundaries described in ARCHITECTURE.md and
# CLAUDE.md.

component :watchers,      in: "lib/robot_lab/am/watchers/**/*.rb"
component :event_log,     in: "lib/robot_lab/am/event_log.rb"
component :inferrer,      in: "lib/robot_lab/am/inferrer.rb"
component :intent_writer, in: "lib/robot_lab/am/intent_writer.rb"
component :cli,           in: "lib/robot_lab/am/cli.rb"

# NOTE: every file here reopens `module RobotLab` (shared with the external
# robot_lab gem's own top-level module -- Inferrer calls RobotLab.build), so
# a `dependencies.forbid` rule keyed on components would treat that one bare
# `RobotLab.build` call as "depends on every component" -- every file
# "defines" the bare RobotLab constant. Naming the actual target constants
# instead of components sidesteps that ambiguity (same fix robot_lab's own
# Archspec.rb applies for the same reason).

# Watchers are pure activity collectors -- git/Claude Code/terminal in,
# Event out (see ARCHITECTURE.md "Ingestion & normalization"). They must not
# know how an Event gets stored, summarized, or reported; CLI is the only
# thing that wires collection to storage/inference.
watchers.cannot_reference_constants "RobotLab::Am::EventLog", "RobotLab::Am::Inferrer",
                                    "RobotLab::Am::IntentWriter", "RobotLab::Am::CLI",
                                    because: "a watcher's only job is producing Events -- what " \
                                             "happens to an Event afterward is not its concern"

# Inferrer consumes a bounded window of Events (already collected) and
# produces an Intent; it must not reach back into how those Events were
# gathered, or which specific source produced them.
inferrer.cannot_reference_constants "RobotLab::Am::Watchers::GitWatcher",
                                    "RobotLab::Am::Watchers::ClaudeWatcher",
                                    "RobotLab::Am::Watchers::TerminalWatcher",
                                    "RobotLab::Am::EventLog", "RobotLab::Am::IntentWriter",
                                    "RobotLab::Am::CLI",
                                    because: "Inferrer only knows the normalized Event shape, never " \
                                             "a specific watcher, the log file, or how its own " \
                                             "output is used"

# IntentWriter is a pure renderer: Intent in, front-matter + prose file out.
# It must not know how that Intent was produced.
intent_writer.cannot_reference_constants "RobotLab::Am::Watchers::GitWatcher",
                                         "RobotLab::Am::Watchers::ClaudeWatcher",
                                         "RobotLab::Am::Watchers::TerminalWatcher",
                                         "RobotLab::Am::EventLog", "RobotLab::Am::Inferrer",
                                         "RobotLab::Am::CLI",
                                         because: "IntentWriter only serializes an already-built " \
                                                  "Intent -- it has no business asking how one was " \
                                                  "inferred"

# CLAUDE.md/ARCHITECTURE.md: GitWatcher subprocesses `git` and must never
# build a command via string interpolation (the same rule robot_lab-to's
# CommitManager enforces for its own git ops) -- Open3.capture3 with an
# explicit argv array only.
watchers.cannot_call :system, receiver: :none,
                     because: "git subprocess calls must go through Open3.capture3 with an " \
                              "argv array, never system()/backticks with an interpolated string"
