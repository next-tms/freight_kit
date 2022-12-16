# frozen_string_literal: true

module Interstellar
  class Platform < Carrier
    # Credentials should be a `Credential` or `Array` of `Credential`
    def initialize(credentials, customer_location: nil, tariff: nil)
      super

      # Use #superclass instead of using #ancestors to fetch the parent class which the carrier class is inheriting from
      # (#ancestors returns an array including the parent class and all the modules that were included)
      parent_class_name = self.class.superclass.name.demodulize.underscore

      conf_path = File
                  .join(
                    File.expand_path(
                      '../../../../configuration/platforms',
                      self.class.const_source_location(:REACTIVE_FREIGHT_PLATFORM).first
                    ),
                    "#{parent_class_name}.yml"
                  )
      @conf = YAML.safe_load(File.read(conf_path), permitted_classes: [Symbol])

      conf_path = File
                  .join(
                    File.expand_path(
                      '../../../../configuration/carriers',
                      self.class.const_source_location(:REACTIVE_FREIGHT_CARRIER).first
                    ),
                    "#{self.class.to_s.demodulize.underscore}.yml"
                  )
      @conf = @conf.deep_merge(YAML.safe_load(File.read(conf_path), permitted_classes: [Symbol]))

      @rates_with_excessive_length_fees = @conf.dig(:attributes, :rates, :with_excessive_length_fees)
    end
  end
end
