module FreightKit
  module Platforms
    class NextTMS
      module ORM
        # A lazy, chainable query of a collection field, e.g. `shipments(filter:, page:, pageSize:, sort:)`.
        #
        # Conditions become ransack predicates (`where(pro: '123')` => `proEq`), so only the filter fields the tenant
        # generates from the model's ransackable attributes work. Without {#limit}, {#to_a} fetches every page.
        class Collection
          include Enumerable

          # Pairs of opposite predicates, e.g. `delivered_at_gteq` is the opposite of `delivered_at_lt`
          NEGATIONS = {
            'cont' => 'not_cont', 'end' => 'not_end', 'eq' => 'not_eq', 'gt' => 'lteq', 'gteq' => 'lt', 'in' => 'not_in',
            'start' => 'not_start'
          }.freeze
          PAGE_SIZE = 100 # the API's maximum
          PREDICATE = /_(cont|end|eq|gt|gteq|in|lt|lteq|not_cont|not_end|not_eq|not_in|not_start|null|start)\z/

          attr_reader :filter, :orm_class, :page, :page_size, :sort, :updated_at, :version

          attr_writer :orm_objects

          delegate :[], :each, :each_with_index, :map, to: :to_a

          def initialize(orm_class, **options)
            raise ArgumentError, 'orm_class must be descended from FreightKit::Platforms::NextTMS::ORM::Base' unless orm_class < Base

            @filter = options[:filter] || {}
            @none = options[:none] || false
            @offset = options[:offset]
            @orm_class = orm_class
            @page = options[:page]
            @page_size = options[:page_size]
            @sort = Array(options[:sort]).compact.presence
            @total_items = options[:total_items]
            @updated_at = options[:updated_at]
          end

          # Arguments and blocks need the records, the bare forms only the total
          def any?(*args, &) = args.empty? && !block_given? ? total_items.positive? : super
          def blank? = !any?
          def count(*args, &) = args.empty? && !block_given? ? total_items : super
          def empty? = total_items.zero?

          # The singular query cannot apply the collection's filter, so a filtered collection filters by ID too, and a
          # limited one searches its page
          def find(id)
            record = if @none then nil
                     elsif page_size.present? then to_a.find { |item| integer_id(item.id).to_s == integer_id(id).to_s }
                     elsif filter.blank? then orm_class.new(id).reload
                     else where(id:).limit(1).first
                     end

            record || raise(RecordNotFoundError, "Couldn't find #{orm_class} with id #{id}")
          end

          def find_by(**conditions)
            find_by!(**conditions)
          rescue RecordNotFoundError
            nil
          end

          def find_by!(**conditions)
            return find(conditions[:id]) if conditions.keys == [:id]

            where(**conditions).limit(1).first || raise(RecordNotFoundError, "Couldn't find #{orm_class} with #{conditions}")
          end

          def first = page_size.present? ? orm_objects.first : limit(1).orm_objects.first
          def first! = first || raise(RecordNotFoundError, "Couldn't find #{orm_class}")

          def ids = pluck(:id)
          def inspect = "#<#{self.class.name} orm_class=#{orm_class}>"

          def last
            return orm_objects.last if page_size.present?

            offset(total_items - 1).limit(1).orm_objects.first unless empty?
          end

          def limit(page_size)
            raise ArgumentError, 'page_size must be 1..100' unless page_size.is_a?(Integer) && page_size.between?(1, PAGE_SIZE)

            new_instance(page: @offset ? offset_page(@offset, page_size) : page || 1, page_size:)
          end

          def new_instance(**options)
            self.class.new(
              orm_class,
              filter: options.fetch(:filter, filter),
              none: options.fetch(:none, @none),
              offset: options.fetch(:offset, @offset),
              page: options.fetch(:page, page),
              page_size: options.fetch(:page_size, page_size),
              sort: options.fetch(:sort, sort),
              total_items: options[:total_items],
              updated_at: options.fetch(:updated_at, updated_at)
            )
          end

          def none = new_instance(none: true, total_items: 0, page: 1, page_size: 1).tap { |collection| collection.orm_objects = [] }
          def not(**conditions) = merge(conditions.map { |key, value| build_negated_filter(key => value) })

          def offset(value)
            raise ArgumentError, 'Offset must be a non-negative integer' unless value.is_a?(Integer) && value >= 0

            page_size.present? ? new_instance(offset: value, page: offset_page(value, page_size)) : new_instance(offset: value)
          end

          def order(*orders, **order_hash)
            sort_strings = if order_hash.any?
                             order_hash.map { |attribute, direction| "#{attribute}:#{direction || :asc}" }
                           else
                             orders.map { |(attribute, direction)| "#{attribute}:#{direction || :asc}" }
                           end

            new_instance(sort: sort_strings)
          end

          def orm_objects = @orm_objects ||= fetch_orm_objects
          def pluck(attribute) = map(&attribute)

          def present? = any?

          def sample
            collection = page_size.present? ? self : limit(10)
            collection.to_a.sample
          end
          alias take sample

          def to_a
            @to_a ||= if @orm_objects || page_size.present?
                        orm_objects
                      else
                        raise ArgumentError, 'offset needs a limit, since the API pages' if @offset

                        first = new_instance(page: page || 1, page_size: PAGE_SIZE).tap(&:orm_objects)
                        pages = ((first.page + 1)..first.total_pages).map { |page| new_instance(page:, page_size: PAGE_SIZE).orm_objects }
                        @total_items = first.total_items
                        @updated_at = first.updated_at
                        @version = first.version

                        [first.orm_objects, *pages].flatten
                      end
          end

          def total_items
            return 0 if @none
            return @total_items if @total_items.present?

            @total_items = (page_size.present? ? self : new_instance(page: 1, page_size: 1)).tap(&:orm_objects).total_items
          end
          alias length total_items
          alias size total_items

          def total_pages
            return if total_items.blank? || page_size.blank?

            (total_items.to_f / page_size).ceil
          end

          def where(**conditions)
            conditions.blank? ? self : merge(conditions.map { |key, value| build_filter(key => value) })
          end

          protected

          def fetch_orm_objects
            return @orm_objects = [] if @none

            operation = orm_class.collection_operation
            variables = { filter: serialize(filter).presence, page:, page_size:, sort: }
            data = orm_class.platform.query(operation, cache: true, **variables)[operation]

            raise ResponseError, 'data[:page] is blank' if data&.dig(:page).blank?
            raise ResponseError, 'data[:page_size] is blank' if data[:page_size].blank?
            raise ResponseError, 'data[:total_items] is blank' if data[:total_items].blank?

            @page = data[:page]
            @page_size = data[:page_size]
            @total_items = data[:total_items]
            @updated_at = data[:updated_at]
            @version = data[:version]

            data[:items].map { |item| orm_class.new(item[:id], loaded: true, **item.except(:id)) }
          end

          private

          # Contradictory alternatives match nothing, so they drop out
          def alternatives(conditions)
            conditions.filter_map { |condition| combine({}, condition.map { |key, value| build_filter(key => value) }) }
          end

          # Whether the filter knows the key only by its foreign key, e.g. `broker_carrier_id_null` but no `broker_carrier_null`
          def association?(key)
            arguments = GraphQLClient::Schema.types["#{orm_class.graphql_name}Filter"].arguments

            arguments.exclude?("#{key.to_s.camelize(:lower)}Null") && arguments.key?("#{key.to_s.camelize(:lower)}IdNull")
          end

          def build_filter(**conditions)
            conditions.each_with_object({}) do |(key, value), filter|
              next filter[:or] = alternatives(value) if key == :or

              value = integer_ids(value) if id_attribute?(key)
              next filter[key] = value if key.to_s.match?(PREDICATE)

              case value
              when Array
                next filter[:"#{key}_id_in"] = value.map { |record| integer_id(record.id) } if value.any? && value.all?(Base)

                filter[:"#{key}_in"] = value
              when Base
                filter[:"#{key}_id_eq"] = integer_id(value.id)
              when Collection
                filter[:"#{key}_id_in"] = value.ids.map { |id| integer_id(id) }
              when nil
                filter[:"#{association?(key) ? "#{key}_id" : key}_null"] = true
              when Range
                filter[:"#{key}_gteq"] = value.begin unless value.begin.nil?
                filter[:"#{key}_#{value.exclude_end? ? 'lt' : 'lteq'}"] = value.end unless value.end.nil?
              else
                filter[:"#{key}_eq"] = value
              end
            end
          end

          # Filter fields are ANDed, so only a condition that becomes one predicate can be negated
          def build_negated_filter(**conditions)
            conditions.each_with_object({}) do |(key, value), filter|
              predicates = build_filter(key => value)
              raise ArgumentError, "Can't negate #{key}: #{value.inspect}, negate each condition instead" if key == :or || predicates.many?

              predicate, value = predicates.first
              match = predicate.to_s.match(PREDICATE)
              next filter[predicate] = !value if match[1] == 'null'

              filter[:"#{match.pre_match}_#{NEGATIONS[match[1]] || NEGATIONS.key(match[1])}"] = value
            end
          end

          # ANDs each condition's predicates with `base`, since a filter has one value per predicate, and conditions such as
          # `id:` and `id_eq:` share one.
          #
          # @return [Hash, nil] Nil when the predicates contradict each other.
          def combine(base, predicates_by_condition)
            predicates_by_condition.flat_map(&:to_a).each_with_object(base.dup) do |(key, value), result|
              old = result[key]
              next result[key] = value if old.nil? || comparable(old) == comparable(value)
              raise ArgumentError, 'A query takes one or:, combine the alternatives instead' if key == :or

              match = key.to_s.match(PREDICATE)
              case match[1]
              when 'eq', 'null' then return nil
              when 'gt', 'gteq' then result[key] = [old, value].max_by { |bound| comparable(bound) }
              when 'in' then result[key] = old.select { |item| comparable(value).include?(comparable(item)) }
              when 'lt', 'lteq' then result[key] = [old, value].min_by { |bound| comparable(bound) }
              when 'not_eq'
                not_in = :"#{match.pre_match}_not_in"
                result.delete(key)
                result[not_in] = [*result[not_in], old, value].uniq { |item| comparable(item) }
              when 'not_in' then result[key] = (old + value).uniq { |item| comparable(item) }
              else raise ArgumentError, "A query takes one #{key}"
              end
            end
          end

          # Values can be ISO 8601 strings, of dates or of times with different offsets, so they compare by date or instant
          def comparable(value)
            case value
            when Array then value.map { |item| comparable(item) }
            when Hash then value.transform_values { |item| comparable(item) }
            when String then value.match?(/\A\d{4}-\d{2}-\d{2}\z/) ? Date.iso8601(value) : Time.iso8601(value)
            when Symbol then value.to_s
            else value
            end
          rescue ArgumentError
            value
          end

          # `id` and `*_id`, with or without a predicate
          def id_attribute?(key) = key.to_s.sub(PREDICATE, '').then { |attribute| attribute == 'id' || attribute.end_with?('_id') }

          # GraphQL serializes IDs as strings, but ID filters take the integer column
          def integer_id(id) = Integer(id, 10, exception: false) || id

          def integer_ids(value)
            case value
            when Array then value.map { |id| integer_id(id) }
            when Range then Range.new(integer_id(value.begin), integer_id(value.end), value.exclude_end?)
            else integer_id(value)
            end
          end

          def merge(predicates_by_condition)
            merged = combine(filter, predicates_by_condition)&.then { |combined| satisfiable(combined) }

            merged ? new_instance(filter: merged) : none
          end

          # The API pages, so the offset must start a page
          def offset_page(offset, page_size)
            raise ArgumentError, "offset #{offset} must be a multiple of the limit #{page_size}" unless (offset % page_size).zero?

            (offset / page_size) + 1
          end

          # The API ignores empty lists, so an empty list matches nothing, and an empty exclusion excludes nothing
          def satisfiable(conditions)
            conditions = conditions.reject { |key, value| value == [] && key.end_with?('_not_in') }
            return if conditions.any? { |_, value| value == [] }
            return conditions unless conditions.key?(:or)

            alternatives = conditions[:or].filter_map { |alternative| satisfiable(alternative) }
            return if alternatives.empty?

            alternatives.any?(&:empty?) ? conditions.except(:or) : conditions.merge(or: alternatives)
          end

          def serialize(value)
            case value
            when Array then value.map { |item| serialize(item) }
            when Date, Time then value.iso8601
            when Hash then value.transform_values { |item| serialize(item) }
            when Symbol then value.to_s
            else value
            end
          end
        end
      end
    end
  end
end
