module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class BrokerCustomer
            DETAILS = Client.parse(<<~GRAPHQL)
              query($id: ID!) {
                brokerCustomer(id: $id) {
                  accountingCustomerId
                  canQuote
                  customer {
                    id
                    name
                  }
                  id
                  officeAddress {
                    city
                    country {
                      alpha2Code
                    }
                    id
                    region {
                      abbreviation
                    }
                    street
                    street2
                    timeZoneName
                    zipCode
                  }
                  primaryPickupAddress {
                    city
                    country {
                      alpha2Code
                    }
                    id
                    region {
                      abbreviation
                    }
                    street
                    street2
                    timeZoneName
                    zipCode
                  }
                  validFreightClasses
                }
              }
            GRAPHQL
          end
        end
      end
    end
  end
end
