module FreightKit
  module Platforms
    class NextTMS
      module ORM
        class Customer < Base
          def broker_customers = @broker_customers ||= orm::BrokerCustomer.where(customer: self)
          def name = @name ||= attribute(:name)
        end
      end
    end
  end
end
