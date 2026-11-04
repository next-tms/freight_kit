module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class Invoices
            DETAILS = Client.parse(<<~GRAPHQL)
              query($filter: InvoiceFilter, $page: Int, $pageSize: Int, $sort: [String!]) {
                invoices(filter: $filter, page: $page, pageSize: $pageSize, sort: $sort) {
                  items {
                    balanceCents
                    balanceCurrency
                    dueOn
                    id
                    issuedOn
                    number
                    paidAt
                    shipment {
                      id
                      loadId
                    }
                    totalCents
                    totalCurrency
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
