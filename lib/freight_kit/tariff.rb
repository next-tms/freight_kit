# frozen_string_literal: true

module FreightKit
  class Tariff
    attr_accessor :overlength_rules

    def initialize(options = {})
      options.symbolize_keys!
      @options = options

      overlength_rules = options[:overlength_rules].presence || []
      raise ArgumentError, 'overlength_rules must be an Array' unless overlength_rules.is_a?(Array)

      @overlength_rules = overlength_rules.map do |overlength_rule|
        overlength_rule.is_a?(OverlengthRule) ? overlength_rule : OverlengthRule.new(**overlength_rule)
      end
    end
  end
end
