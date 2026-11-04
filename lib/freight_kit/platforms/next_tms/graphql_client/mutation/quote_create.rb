module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Mutation
          class QuoteCreate
            DETAILS = Client.parse(<<~GRAPHQL)
              mutation($input: QuoteCreateInput!) {
                quoteCreate(input: $input) {
                  rates {
                    carrierName
                    chargeCents
                    chargeCurrency
                    expiresAt
                    id
                    reference
                    scac
                    transitDays
                  }
                  shipment {
                    id
                    loadId
                  }
                }
              }
            GRAPHQL
          end
        end
      end
    end
  end
end
