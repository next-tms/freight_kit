module Interstellar # :nodoc:
  class Package
    VALID_FREIGHT_CLASSES = [55, 60, 65, 70, 77.5, 85, 92.5, 100, 110, 125, 150, 175, 200, 250, 300, 400].freeze

    cattr_accessor :default_options
    attr_accessor :description, :hazmat, :nmfc
    attr_reader :currency, :options, :packaging, :value
    attr_writer :declared_freight_class

    # Package.new(100, [10, 20, 30], 'pallet', :units => :metric)
    # Package.new(Measured::Weight.new(100, :g), 'box', [10, 20, 30].map {|m| Length.new(m, :centimetres)})
    # Package.new(100.grams, [10, 20, 30].map(&:centimetres))
    def initialize(grams_or_ounces, dimensions, packaging_type, options = {})
      options = @@default_options.update(options) if @@default_options
      options.symbolize_keys!
      @options = options

      # For backward compatibility
      if dimensions.is_a?(Array)
        @dimensions = [dimensions].flatten.reject(&:nil?)
      else
        @dimensions = [dimensions.dig(:height), dimensions.dig(:width), dimensions.dig(:length)]
        @dimensions = [@dimensions].flatten.reject(&:nil?)
      end

      @description = options[:description]
      @hazmat = options[:hazmat] == true
      @nmfc = options[:nmfc].blank? ? nil : options[:nmfc]

      imperial = (options[:units] == :imperial)

      weight_imperial = dimensions_imperial = imperial if options.include?(:units)

      weight_imperial = (options[:weight_units] == :imperial) if options.include?(:weight_units)

      dimensions_imperial = (options[:dim_units] == :imperial) if options.include?(:dim_units)

      @weight_unit_system = weight_imperial ? :imperial : :metric
      @dimensions_unit_system = dimensions_imperial ? :imperial : :metric

      @weight = attribute_from_metric_or_imperial(grams_or_ounces, Measured::Weight, @weight_unit_system, :grams,
                                                  :ounces)

      if @dimensions.blank?
        zero_length = Measured::Length.new(0, (dimensions_imperial ? :inches : :centimetres))
        @dimensions = [zero_length] * 3
      else
        # Overriding ReactiveShipping's protected process_dimensions which sorts
        # them making it confusing for ReactiveFreight carrier API's that expect
        # the H x W x L order. Since H x W x L is nonstandard in the freight
        # industry ReactiveFreight introduces explicit functions for each
        @dimensions = @dimensions.map do |l|
          attribute_from_metric_or_imperial(l, Measured::Length, @dimensions_unit_system, :centimetres, :inches)
        end
        2.downto(@dimensions.length) do |_n|
          @dimensions.unshift(@dimensions[0])
        end
      end

      @value = Package.cents_from(options[:value])
      @currency = options[:currency] || (options[:value].currency if options[:value].respond_to?(:currency))
      @cylinder = options[:cylinder] || options[:tube] ? true : false
      @gift = options[:gift] ? true : false
      @oversized = options[:oversized] ? true : false
      @unpackaged = options[:unpackaged] ? true : false
      @packaging = Packaging.new(packaging_type)
    end

    def cubic_ft
      if !inches[0].blank? && !inches[1].blank? && !inches[2].blank?
        cubic_ft = (inches[0] * inches[1] * inches[2]).to_f / 1728
        return ('%0.2f' % cubic_ft).to_f
      end
      nil
    end

    def density
      if !inches[0].blank? && !inches[1].blank? && !inches[2].blank? && pounds
        density = pounds.to_f / cubic_ft
        return ('%0.2f' % density).to_f
      end
      nil
    end

    def calculated_freight_class
      sanitized_freight_class(density_to_freight_class(density))
    end

    def declared_freight_class
      @declared_freight_class || @options[:declared_freight_class]
    end

    def freight_class
      declared_freight_class.blank? ? calculated_freight_class : declared_freight_class
    end

    def length(unit)
      @dimensions[2].convert_to(unit).value.to_f
    end

    def width(unit)
      @dimensions[1].convert_to(unit).value.to_f
    end

    def height(unit)
      @dimensions[0].convert_to(unit).value.to_f
    end

    def cylinder?
      @cylinder
    end

    def oversized?
      @oversized
    end

    def unpackaged?
      @unpackaged
    end

    alias tube? cylinder?

    def gift?
      @gift
    end

    def hazmat?
      @hazmat
    end

    def ounces(options = {})
      weight(options).convert_to(:oz).value.to_f
    end
    alias oz ounces

    def grams(options = {})
      weight(options).convert_to(:g).value.to_f
    end
    alias g grams

    def pounds(options = {})
      weight(options).convert_to(:lb).value.to_f
    end
    alias lb pounds
    alias lbs pounds

    def kilograms(options = {})
      weight(options).convert_to(:kg).value.to_f
    end
    alias kg kilograms
    alias kgs kilograms

    def inches(measurement = nil)
      @inches ||= @dimensions.map { |m| m.convert_to(:in).value.to_f }
      measurement.nil? ? @inches : measure(measurement, @inches)
    end
    alias in inches

    def centimetres(measurement = nil)
      @centimetres ||= @dimensions.map { |m| m.convert_to(:cm).value.to_f }
      measurement.nil? ? @centimetres : measure(measurement, @centimetres)
    end
    alias cm centimetres

    def weight(options = {})
      case options[:type]
      when nil, :actual
        @weight
      when :volumetric, :dimensional
        @volumetric_weight ||= begin
          m = Measured::Weight.new((centimetres(:box_volume) / 6.0), :grams)
          @weight_unit_system == :imperial ? m.convert_to(:oz) : m
        end
      when :billable
        [weight, weight(type: :volumetric)].max
      end
    end
    alias mass weight

    def self.cents_from(money)
      return nil if money.nil?

      if money.respond_to?(:cents)
        money.cents
      else
        case money
        when Float
          (money * 100).round
        when String
          money =~ /\./ ? (money.to_f * 100).round : money.to_i
        else
          money.to_i
        end
      end
    end

    private

    def attribute_from_metric_or_imperial(obj, klass, unit_system, metric_unit, imperial_unit)
      if obj.is_a?(klass)
        obj
      else
        klass.new(obj, (unit_system == :imperial ? imperial_unit : metric_unit))
      end
    end

    def density_to_freight_class(density)
      return nil unless density
      return 400 if density < 1
      return 60 if density > 30

      density_table = [
        [1, 2, 300],
        [2, 4, 250],
        [4, 6, 175],
        [6, 8, 125],
        [8, 10, 100],
        [10, 12, 92.5],
        [12, 15, 85],
        [15, 22.5, 70],
        [22.5, 30, 65],
        [30, 35, 60]
      ]
      density_table.each do |density_row|
        return density_row[2] if (density >= density_row[0]) && (density < density_row[1])
      end
    end

    def sanitized_freight_class(freight_class)
      return nil if freight_class.blank?

      if VALID_FREIGHT_CLASSES.include?(freight_class)
        return freight_class.to_i == freight_class ? freight_class.to_i : freight_class
      end

      nil
    end

    def measure(measurement, ary)
      case measurement
      when Integer then ary[measurement]
      when :x, :max, :length, :long then ary[2]
      when :y, :mid, :width, :wide then ary[1]
      when :z, :min, :height, :depth, :high, :deep then ary[0]
      when :girth, :around, :circumference
        cylinder? ? (Math::PI * (ary[0] + ary[1]) / 2) : (2 * ary[0]) + (2 * ary[1])
      when :volume then cylinder? ? (Math::PI * (ary[0] + ary[1]) / 4)**2 * ary[2] : measure(:box_volume, ary)
      when :box_volume then ary[0] * ary[1] * ary[2]
      end
    end

    def process_dimensions
      @dimensions = @dimensions.map do |l|
        attribute_from_metric_or_imperial(l, Measured::Length, @dimensions_unit_system, :centimetres, :inches)
      end.sort
      # [1,2] => [1,1,2]
      # [5] => [5,5,5]
      # etc..
      2.downto(@dimensions.length) do |_n|
        @dimensions.unshift(@dimensions[0])
      end
    end
  end
end
