module FreightKit
  module Platforms
    class NextTMS
      module ORM
        # A Next TMS record, loaded lazily from the tenant's GraphQL API with the {GraphQLClient::Query} of the same name.
        # Records from a collection are loaded. Records from an association hold only the fields that its query selects
        # for it, and load the rest when one is read.
        class Base
          class << self
            attr_accessor :orm

            delegate :count,
                     :find,
                     :find_by,
                     :find_by!,
                     :first,
                     :first!,
                     :ids,
                     :last,
                     :limit,
                     :none,
                     :not,
                     :offset,
                     :order,
                     :pluck,
                     :where,
                     to: :all

            def all = Collection.new(self)
            def association_type_mapping = {}

            def build_association(name, data)
              return if data&.dig(:id).blank?

              class_name = association_type_mapping[name.to_sym] || name.to_s.classify
              orm.const_get(class_name).new(data[:id], **data.except(:id))
            end

            def build_associations(name, items) = Array(items).filter_map { |data| build_association(name.to_s.singularize, data) }

            # @return [Symbol] The collection query, e.g. `:broker_carriers` for {GraphQLClient::Query::BrokerCarriers}.
            def collection_operation = graphql_name.pluralize.underscore.to_sym

            # @return [Symbol] The singular query, e.g. `:broker_carrier` for {GraphQLClient::Query::BrokerCarrier}.
            def element_operation = graphql_name.underscore.to_sym

            def graphql_name = superclass == Base ? name.demodulize : superclass.graphql_name

            def platform
              raise ArgumentError, "#{name} is not bound to a tenant, use e.g. FreightKit::Carriers::JFJTransportation::ORM" if orm.nil?

              orm.platform
            end
          end

          # Instance variables that {#reload} keeps, all others memoize attributes
          STATE = %i[@attributes @id @loaded].freeze

          attr_reader :id

          delegate :orm, :platform, to: :class

          def initialize(id, created_at: nil, loaded: false, updated_at: nil, **attributes)
            raise ArgumentError, 'id cannot be blank' if id.blank?

            @attributes = { created_at:, updated_at: }.compact.merge(attributes)
            # The API returns IDs without leading zeros, so `'01'` and `'1'` are the same record
            @id = id.is_a?(String) && id.match?(/\A\d+\z/) ? id.to_i.to_s : id
            @loaded = loaded
          end

          def ==(other) = other.instance_of?(self.class) && other.id.to_s == id.to_s
          alias eql? ==

          def attribute(key)
            reload unless @attributes.key?(key) || loaded?

            @attributes[key]
          end

          def attributes
            reload unless loaded?

            @attributes
          end

          def hash = [self.class, id.to_s].hash
          def inspect = "#<#{self.class.name} id=#{id}>"
          def loaded? = @loaded

          # Loads every attribute, from {FreightKit.cache} when present.
          def reload = load(cache: true)

          # Loads every attribute from the API.
          def reload! = load(cache: false)

          private

          def date(key) = attribute(key)&.then { |value| Date.iso8601(value) }
          def fetch_association(name) = self.class.build_association(name, attribute(name))
          def fetch_associations(name) = self.class.build_associations(name, attribute(name))

          def load(cache:)
            operation = self.class.element_operation
            data = platform.query(operation, cache:, id:)[operation]
            raise RecordNotFoundError, "Couldn't find #{self.class.name} with id #{id}" if data.nil?

            (instance_variables - STATE).each { |variable| remove_instance_variable(variable) }
            @attributes = data.except(:id)
            @loaded = true

            self
          end

          def time(key) = attribute(key)&.then { |value| Time.iso8601(value) }
        end
      end
    end
  end
end
