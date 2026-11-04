module FreightKit
  module Platforms
    class NextTMS
      module ORM
        class Carrier < Base
          def broker_carriers = @broker_carriers ||= orm::BrokerCarrier.where(carrier: self)
          def mc_number = @mc_number ||= attribute(:mc_number)
          def name = @name ||= attribute(:name)
          def scac = @scac ||= attribute(:scac)
        end
      end
    end
  end
end
