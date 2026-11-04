module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class Invoice
            DETAILS = Client.parse(<<~GRAPHQL)
              query($id: ID!) {
                invoice(id: $id) {
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
              }
            GRAPHQL
          end
        end
      end
    end
  end
end
