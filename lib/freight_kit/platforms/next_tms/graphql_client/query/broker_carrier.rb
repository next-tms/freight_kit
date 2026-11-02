module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class BrokerCarrier
            DETAILS = Client.parse(<<~GRAPHQL)
              query($id: ID!) {
                brokerCarrier(id: $id) {
                  account
                  accountDesc
                  brokerCustomer {
                    customer {
                      id
                      name
                    }
                    id
                  }
                  carrier {
                    id
                    mcNumber
                    name
                    scac
                  }
                  createInvoiceOnPickup
                  daysToPayAfterInvoiceDate
                  id
                  shipmentsCount
                }
              }
            GRAPHQL
          end
        end
      end
    end
  end
end
