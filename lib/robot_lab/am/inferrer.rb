# frozen_string_literal: true

require "yaml"

module RobotLab
  module Am
    # Summarizes a bounded window of Events into a structured Intent via a
    # small RobotLab::Robot. `robot:` is injectable so callers (and tests)
    # never have to make a real LLM call to exercise this class.
    #
    # Defaults to a local model served by LM Studio's OpenAI-compatible API
    # (`lms server start`), not a hosted provider — inference over your own
    # activity log shouldn't require sending it, or an API key, anywhere.
    class Inferrer
      DEFAULT_PROVIDER = :openai
      DEFAULT_MODEL = "qwen/qwen3.8-27b"
      DEFAULT_API_BASE = "http://localhost:1234/v1"
      API_BASE_ENV_VAR = "ROBOT_LAB_RUBY_LLM__OPENAI_API_BASE"

      SYSTEM_PROMPT = <<~PROMPT
        You infer what a software developer is currently working on from a
        timestamped activity log: their own git commits and uncommitted
        changes, their own messages in a Claude Code session, and commands
        they ran in a terminal. Respond with ONLY YAML, no other text, in
        exactly this shape:

        goal: <one or two sentences on what they're currently working toward>
        confidence: <low|medium|high>
        evidence:
          - <short reference to a specific event that supports the goal>
        open_questions:
          - <anything ambiguous or unresolved>
      PROMPT

      def initialize(robot: nil, model: DEFAULT_MODEL, provider: DEFAULT_PROVIDER)
        @robot = robot
        @model = model
        @provider = provider
      end

      def infer(events, repo:)
        return empty_intent if events.empty?

        parse(robot.run(build_prompt(events, repo)).last_text_content)
      end

      private

      def robot
        @robot ||= build_robot
      end

      def build_robot
        ENV[API_BASE_ENV_VAR] ||= DEFAULT_API_BASE if @provider == :openai
        RobotLab.build(name: "robot_lab-am-inferrer", system_prompt: SYSTEM_PROMPT,
                       model: @model, provider: @provider)
      end

      def build_prompt(events, repo)
        lines = events.sort_by(&:timestamp).map { |e| "[#{e.timestamp}] (#{e.source}/#{e.kind}) #{e.summary}" }
        "Repo: #{repo}\n\nActivity log, oldest to newest:\n#{lines.join("\n")}"
      end

      def parse(response)
        data = YAML.safe_load(extract_yaml(response), permitted_classes: [Symbol]) || {}
        build_intent(data, response)
      rescue Psych::SyntaxError, Psych::DisallowedClass
        build_intent({}, response)
      end

      def extract_yaml(response)
        response[/```ya?ml\n(.*?)```/m, 1] || response
      end

      # :reek:FeatureEnvy -- this method's whole job is reading the parsed
      # YAML hash into an Intent; that's not a sign it belongs elsewhere.
      def build_intent(data, response)
        Intent.new(
          goal: data["goal"] || response.strip,
          confidence: data["confidence"] || "unknown",
          evidence: Array(data["evidence"]),
          open_questions: Array(data["open_questions"]),
          generated_at: Time.now.utc.iso8601
        )
      end

      def empty_intent
        Intent.new(goal: "No recent activity detected.", confidence: "low", evidence: [],
                   open_questions: [], generated_at: Time.now.utc.iso8601)
      end
    end
  end
end
