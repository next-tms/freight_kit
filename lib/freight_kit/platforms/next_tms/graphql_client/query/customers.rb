module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class Customers
            DETAILS = Client.parse(<<~GRAPHQL)
              query($filter: CustomerFilter, $page: Int, $pageSize: Int, $sort: [String!]) {
                customers(filter: $filter, page: $page, pageSize: $pageSize, sort: $sort) {
                  items {
                    id
                    name
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
