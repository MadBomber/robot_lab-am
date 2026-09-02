# frozen_string_literal: true

require "myway_config"

module RobotLab
  module Am
    # Configuration for the activity monitor, following the same
    # MywayConfig::Base pattern as robot_lab-to's Config.
    #
    # Sources (lowest to highest precedence):
    #   1. Bundled defaults (config/defaults.yml)
    #   2. User config file (~/.config/robot_lab_am/robot_lab_am.yml,
    #      or $XDG_CONFIG_HOME/robot_lab_am/robot_lab_am.yml)
    #   3. Environment variables (RLAM_*)
    #   4. Constructor keyword arguments (CLI flag overrides)
    #
    # :reek:InstanceVariableAssumption -- the defaults.yml-backed ivars ARE
    # assigned, by `super()` (MywayConfig::Base / Anyway::Config), before any
    # of this class's own code runs. Do NOT pre-nil them in #initialize:
    # that overwrites the real loaded values with nil (robot_lab-to's Config
    # carries the same caveat).
    class Config < MywayConfig::Base
      config_name :robot_lab_am
      env_prefix :rlam
      defaults_path File.expand_path("config/defaults.yml", __dir__)
      auto_configure!

      # auto_configure! only derives symbol/boolean/section coercions from
      # the YAML value types; the integer settings and the string-to-symbol
      # provider need explicit coercion so RLAM_* env values (always
      # strings) come out typed.
      coerce_types provider: to_symbol, interval: :integer,
                   debounce: :integer, inference_window: :integer

      # Runtime CLI overrides — applied after load. A nil override is
      # ignored (see #initialize), so CLI code can pass flags through
      # unconditionally.
      attr_writer :provider, :model, :api_base, :api_key, :interval, :debounce,
                  :inference_window, :terminal_log

      def initialize(**overrides)
        super()
        overrides.each { |key, value| public_send(:"#{key}=", value) unless value.nil? }
      end

      def provider         = @provider || super
      def model            = @model || super
      def api_base         = @api_base || super
      def api_key          = @api_key || super
      def interval         = @interval || super
      def debounce         = @debounce || super
      def inference_window = @inference_window || super

      # Expanded at read time so "~" works from YAML, env, and overrides alike.
      def terminal_log = File.expand_path(@terminal_log || super)
    end
  end
end
