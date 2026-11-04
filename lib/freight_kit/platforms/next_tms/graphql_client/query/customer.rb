module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class Customer
            DETAILS = Client.parse(<<~GRAPHQL)
              query($id: ID!) {
                customer(id: $id) {
                  id
                  name
                }
              }
            GRAPHQL
          end
        end
      end
    end
  end
end
