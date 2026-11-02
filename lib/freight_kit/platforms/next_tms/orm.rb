module FreightKit
  module Platforms
    class NextTMS
      # Every {NextTMS} subclass gets its own copy of these models, bound to its domain, e.g.
      #
      #   FreightKit::Carriers::JFJTransportation::ORM.credentials = FreightKit::Credential.new(type: :api_key, api_key:)
      #   FreightKit::Carriers::JFJTransportation::ORM::Shipment.where(status: :delivered).order(delivered_at: :desc)
      module ORM
        MODELS = %i[Address BrokerCarrier BrokerCustomer Carrier Customer Invoice Shipment].freeze

        # Methods of a carrier's ORM namespace, e.g. `FreightKit::Carriers::JFJTransportation::ORM`.
        module Namespace
          attr_reader :credentials, :platform_class

          def credentials=(credentials)
            @credentials = credentials
            @platform = nil
          end

          def platform = @platform ||= platform_class.new(credentials || raise(ArgumentError, "#{name}.credentials is not set"))
        end

        class << self
          # @param platform_class [Class<NextTMS>]
          # @return [Module] `platform_class::ORM`, with a subclass of each of {MODELS}.
          def define(platform_class)
            namespace = Module.new.extend(Namespace)
            namespace.instance_variable_set(:@platform_class, platform_class)
            platform_class.const_set(:ORM, namespace)

            MODELS.each { |model| namespace.const_set(model, Class.new(const_get(model)).tap { |orm_class| orm_class.orm = namespace }) }
            namespace
          end
        end
      end
    end
  end
end
