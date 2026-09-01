# robot_lab-am

A [RobotLab](https://github.com/MadBomber/robot_lab) extension gem that watches
what's happening in a repo working directory — git activity, Claude Code session
transcripts, and terminal commands — and infers the current goal/direction. The
inferred intent is written to a well-known artifact that
[`robot_lab-to`](https://github.com/MadBomber/robot_lab-to) reads to seed a
takeover run with real context instead of a cold objective string.

> [!CAUTION]
> Early design/exploration stage. See `ARCHITECTURE.md` for the component
> survey and open decisions; nothing here is a stable API yet.

## Installation

Add to your Gemfile:

```ruby
gem "robot_lab"
gem "robot_lab-am"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run
`bundle exec rake test` to run the tests. `bin/console` gives an interactive
prompt with the gem loaded.

```bash
bundle exec rake test          # all tests
bundle exec rake test_verbose  # verbose test output
bundle exec rake quality       # tests + coverage + rubocop + flog + flay
bin/console                    # IRB shell with gem loaded
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
