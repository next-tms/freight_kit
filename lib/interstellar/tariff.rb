module Interstellar
  class Tariff
    attr_accessor :overlength_rules

    def initialize(options = {})
      options.symbolize_keys!
      @options = options

      @options[:overlength_rules] = @options[:overlength_rules].blank? ? [] : @options[:overlength_rules]
      raise ArgumentError, 'overlength_rules must be an Array' unless @options[:overlength_rules].is_a?(Array)

      @options[:overlength_rules].each do |overlength_rule|
        if !overlength_rule[:min_length].is_a?(Measured::Length)
          raise ArgumentError, 'overlength_rule[:min_length] must be a Measured::Length'
        elsif ![Measured::Length, NilClass].include?(overlength_rule[:max_length].class)
          raise ArgumentError, 'overlength_rule[:max_length] must be one of Measured::Length, NilClass'
        end

        unless overlength_rule[:fee_cents].is_a?(Integer)
          raise ArgumentError, 'overlength_rule[:fee_cents] must be an Integer'
        end
      end

      @overlength_rules = @options[:overlength_rules]
    end
  end
end
