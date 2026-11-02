module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class BrokerCustomers
            DETAILS = Client.parse(<<~GRAPHQL)
              query($filter: BrokerCustomerFilter, $page: Int, $pageSize: Int, $sort: [String!]) {
                brokerCustomers(filter: $filter, page: $page, pageSize: $pageSize, sort: $sort) {
                  items {
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
