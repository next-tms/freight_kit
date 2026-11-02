module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          # Never cached, since document URLs expire after 5 minutes
          class ShipmentDocuments
            DETAILS = Client.parse(<<~GRAPHQL)
              query($filter: ShipmentFilter, $page: Int, $pageSize: Int) {
                shipments(filter: $filter, page: $page, pageSize: $pageSize) {
                  items {
                    documents {
                      contentType
                      filename
                      kind
                      url
                    }
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
