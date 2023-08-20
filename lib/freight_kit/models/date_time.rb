# frozen_string_literal: true

module FreightKit
  # Represent dates and times in varous formats.
  #
  # @attribute date_time_with_zone
  #   Date and time with time zone.
  #   @return [ActiveSupport::TimeWithZone]
  #
  # @attribute local_date
  #   Local date.
  #   @return [Date]
  #
  # @attribute local_date_time
  #   Local date and time in the format `"YYYY-MM-DD HH:MM:SS"`
  #   (zero-padded 24 hour clock) aka `DateTime#to_fs(:db)` format.
  #   @return [String]
  #
  class DateTime < Model
    attr_accessor :local_date, :local_date_time, :location, :date_time_with_zone

    def initialize(*)
      super

      attempt_upgrade_using_location(location) if location.present?
    end

    private

    def attempt_upgrade_using_location(location)
      return if @date_time_with_zone.present? || @local_date_time.blank? || location.time_zone.blank?

      @date_time_with_zone = location.time_zone.parse(@local_date_time)
      @local_date_time = nil
    end
  end
end
