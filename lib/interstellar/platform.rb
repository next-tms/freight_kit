# frozen_string_literal: true

module Interstellar
  class Platform < Carrier
    # Credentials should be a `Credential` or `Array` of `Credential`
    def initialize(credentials, customer_location: nil, tariff: nil)
      super

      conf_path = File
                  .join(
                    File.expand_path(
                      '../../../../configuration/platforms',
                      self.class.const_source_location(:REACTIVE_FREIGHT_PLATFORM).first
                    ),
                    "#{self.class.ancestors[1].name.split('::')[1].underscore}.yml"
                  )
      @conf = YAML.safe_load(File.read(conf_path), permitted_classes: [Symbol])

      conf_path = File
                  .join(
                    File.expand_path(
                      '../../../../configuration/carriers',
                      self.class.const_source_location(:REACTIVE_FREIGHT_CARRIER).first
                    ),
                    "#{self.class.to_s.split('::')[1].underscore}.yml"
                  )
      @conf = @conf.deep_merge(YAML.safe_load(File.read(conf_path), permitted_classes: [Symbol]))

      @rates_with_excessive_length_fees = @conf.dig(:attributes, :rates, :with_excessive_length_fees)
    end
  end
end
