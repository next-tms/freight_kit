module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Mutation
          class ShipmentCreate
            DETAILS = Client.parse(<<~GRAPHQL)
              mutation($input: ShipmentCreateInput!) {
                shipmentCreate(input: $input) {
                  shipment {
                    documents {
                      contentType
                      kind
                      url
                    }
                    id
                    loadId
                    pro
                    status
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
