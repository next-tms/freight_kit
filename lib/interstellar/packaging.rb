# frozen_string_literal: true

module Interstellar
  class Packaging
    VALID_TYPES = %i[
                    box
                    bundle
                    container
                    crate
                    cylinder
                    drum
                    luggage
                    pail
                    pallet
                    piece
                    roll
                    tote
                    truckload
                    tote
                  ].freeze

    PALLET_TYPES = %i[crate drum pallet tote].freeze

    attr_accessor :type

    # Packaging.new(:pallet)
    def initialize(type, options = {})
      options.symbolize_keys!
      @options = options

      unless VALID_TYPES.include?(type)
        raise ArgumentError, "Package#new: `type` should be one of #{VALID_TYPES.join(", ")}"
      end

      @type = type
    end

    def box?
      @box ||= BOX_TYPES.include?(@type)
    end

    def pallet?
      @pallet ||= PALLET_TYPES.include?(@type)
    end

    def box_or_pallet_type
      return :pallet if pallet?

      box? ? :box : nil
    end
  end
end
