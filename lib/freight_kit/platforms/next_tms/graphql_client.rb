module FreightKit
  module Platforms
    class NextTMS
      # Parses each `Query::*::DETAILS` document against the Next TMS schema when it loads, so a wrong field or argument
      # fails at boot rather than at request time.
      class GraphQLClient
        # Sends documents to the tenant in `context[:platform]`, so one parsed document serves every tenant.
        class HTTPAdapter
          def execute(document:, context: {}, operation_name: nil, variables: {})
            context.fetch(:platform).execute(document.to_query_string, operation_name:, variables:)
          end
        end

        # Introspection of the GraphQL API, which every tenant shares
        SCHEMA_PATH = File.expand_path('../../../../schemas/next_tms.json', __dir__).freeze

        Schema = GraphQL::Client.load_schema(JSON.parse(File.read(SCHEMA_PATH)))
        Client = GraphQL::Client.new(schema: Schema, execute: HTTPAdapter.new)
      end
    end
  end
end
