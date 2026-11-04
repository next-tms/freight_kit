module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class Carriers
            DETAILS = Client.parse(<<~GRAPHQL)
              query($filter: CarrierFilter, $page: Int, $pageSize: Int, $sort: [String!]) {
                carriers(filter: $filter, page: $page, pageSize: $pageSize, sort: $sort) {
                  items {
                    id
                    mcNumber
                    name
                    scac
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
