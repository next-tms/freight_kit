# frozen_string_literal: true

module Interstellar
  # Class representing credentials.
  #
  # @!attribute kind
  #   What kind?
  #   @return [Symbol] One of `:api`, `:oauth2`, `:website`
  #
  # @!attribute access_token
  #   Access token when type is `:oauth2`
  #   @return [String] Access token
  #
  # @!attribute expires_at
  #   Token expiration date/time when type is `:oauth2`
  #   @return [DateTime] Token expiration date/time
  #
  # @!attribute scope
  #   Scope when type is `:oauth2`
  #   @return [String] Scope
  #
  # @!attribute username
  #   Username when type is one of `:api`, `:website`
  #   @return [String] Username
  #
  # @!attribute password
  #   Password when type is one of `:api`, `:website`
  #   @return [String] Username
  #
  class Credential < Model
    VALID_TYPES = %i[api oauth2 website].freeze

    attr_accessor :type

    # Returns a new instance of Credential.
    #
    # Other than the following, instance `:attr_reader`s are generated dynamically based on keys.
    #
    # @param [Symbol] type One of `:api`, `:website`
    # @param [String] username Required when type is one of `:api`, `:website`
    # @param [String] password Required when type is one of `:api`, `:website`
    # @param [String] access_token Required when type is `:oauth2`
    # @param [DateTime] expires_at Required when type is `:oauth2`
    # @param [String] scope Required when type is `:oauth2`
    def initialize(hash)
      unless VALID_TYPES.include?(hash[:type])
        raise ArgumentError, "Credential#new: `type` should be one of #{VALID_TYPES.join(', ')}"
      end

      if hash[:type] == :oauth2 && !hash[:expires_at].is_a?(::DateTime)
        raise ArgumentError, "Credential#new: `expires_at` must be a DateTime, got #{hash[:expires_at].class}"
      end

      hash.each do |k, v|
        next if k == :type

        singleton_class.class_eval { attr_accessor k.to_s }
      end
      
      type = hash[:type]
      
      requirements = case type
                     when :api, :website
                       %i[username password]
                     when :oauth2
                       %i[access_token expires_at scope]
                     end
      
      requirements.each do |k|
        raise ArgumentError, "Credential#new: `#{k.to_s}` cannot be blank" if hash[k].blank?
      end
      
      super
    end
  end
end
