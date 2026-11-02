module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class BrokerCarriers
            DETAILS = Client.parse(<<~GRAPHQL)
              query($filter: BrokerCarrierFilter, $page: Int, $pageSize: Int, $sort: [String!]) {
                brokerCarriers(filter: $filter, page: $page, pageSize: $pageSize, sort: $sort) {
                  items {
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
                  page
                  pageSize
                  pages
                  totalItems
                  updatedAt
                  version
                }
              }
            GRAPHQL
          end
        end
      end
    end
  end
end
