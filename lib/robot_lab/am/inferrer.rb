# frozen_string_literal: true

require "yaml"
require "ruby_llm"

module RobotLab
  module Am
    # Summarizes a bounded window of Events into a structured Intent with a
    # one-shot RubyLLM chat — no robots, no robot_lab dependency, so the gem
    # is useful outside the robot_lab-to environment too. `chat:` is
    # injectable so callers (and tests) never have to make a real LLM call
    # to exercise this class.
    #
    # Provider, model, API base, and key come from Am::Config (defaults.yml
    # -> user config file -> RLAM_* env vars -> keyword overrides).
    # The shipped default is a local model served by LM Studio's
    # OpenAI-compatible API (`lms server start`), not a hosted provider —
    # inference over your own activity log shouldn't require sending it,
    # or an API key, anywhere.
    class Inferrer
      # LM Studio ignores the key but RubyLLM's :openai provider requires
      # one to be configured; used only when neither the config nor the
      # provider's conventional env var supplies a real key.
      PLACEHOLDER_API_KEY = "no-key-required"

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

      def initialize(chat: nil, config: nil, model: nil, provider: nil)
        @chat = chat
        @config = config
        @model = model
        @provider = provider
      end

      def infer(events, repo:)
        return empty_intent if events.empty?

        parse(chat.ask(build_prompt(events, repo)).content)
      end

      private

      def chat
        @chat ||= build_chat
      end

      def config   = @config ||= Am.config
      def model    = @model || config.model
      def provider = @provider || config.provider

      # assume_model_exists: local model names aren't in RubyLLM's registry.
      def build_chat
        llm_context.chat(model: model, provider: provider, assume_model_exists: true)
                   .with_instructions(SYSTEM_PROMPT)
      end

      # A scoped RubyLLM context (a dup of the global config), so embedding
      # robot_lab-am in a larger app never mutates that app's RubyLLM setup.
      # api_base is an OpenAI-compatible-server concern and is only applied
      # to the :openai provider.
      def llm_context
        RubyLLM.context do |llm|
          llm.openai_api_base = config.api_base if provider == :openai
          key_setter = :"#{provider}_api_key="
          llm.public_send(key_setter, api_key) if llm.respond_to?(key_setter)
        end
      end

      # Cascade: explicit config -> the provider's conventional env var
      # (OPENAI_API_KEY, ANTHROPIC_API_KEY, ...) -> placeholder for keyless
      # local servers.
      def api_key
        config.api_key || ENV.fetch("#{provider.to_s.upcase}_API_KEY") { PLACEHOLDER_API_KEY }
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
