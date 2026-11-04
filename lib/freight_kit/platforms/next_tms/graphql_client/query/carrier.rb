module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class Carrier
            DETAILS = Client.parse(<<~GRAPHQL)
              query($id: ID!) {
                carrier(id: $id) {
                  id
                  mcNumber
                  name
                  scac
                }
              }
            GRAPHQL
          end
        end
      end
    end
  end
end
