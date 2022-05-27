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
    attr_accessor :type

    # Returns a new instance of Credential.
    #
    # Other than the following, instance `:attr_reader`s are generated dynamically based on keys.
    #
    # @param [Symbol] type One of `:api`, `:website`
    # @param [String] base_url Required when type is `:selenoid`
    # @param [String] username Required when type is one of `:api`, `:website`
    # @param [String] password Required when type is one of `:api`, `:website`
    # @param [String] access_token Required when type is `:oauth2`
    # @param [DateTime] expires_at Required when type is `:oauth2`
    # @param [String] scope Required when type is `:oauth2`
    def initialize(hash)
      raise ArgumentError, 'Credential#new: `type` cannot be blank' if hash[:type].blank?

      type = hash[:type]

      requirements = case type
                     when :api, :website
                       { username: String, password: String }
                     when :oauth2
                       { access_token: String, expires_at: ::DateTime, scope: String }
                     when :selenoid
                       { base_url: URI, browser: Symbol }
                     else
                       {}
                     end

      requirements.each_key do |k|
        raise ArgumentError, "Credential#new: `#{k}` cannot be blank" if hash[k].blank?

        unless hash[k].is_a?(requirements[k])
          raise ArgumentError, "Credential#new: `#{k}` must be a #{requirements[k]}, got #{hash[k].class}"
        end
      end

      hash.each do |k, _v|
        next if k == :type

        singleton_class.class_eval { attr_accessor k.to_s } unless singleton_class.respond_to?(k)
      end

      super
    end

    def selenoid_options
      return nil unless type == :selenoid
      return @selenoid_options unless @selenoid_options.blank?

      download_url = base_url.dup
      download_url.path = '/download'
      download_url = download_url.to_s

      @selenoid_options = { download_url: }
    end

    def watir_args
      return nil unless type == :selenoid
      return @watir_args unless @watir_args.blank?

      url = base_url.dup
      url.path = '/wd/hub/'
      url = url.to_s

      @watir_args = [
        browser,
        {
          options: {
            prefs: {
              download: {
                directory_upgrade: true,
                prompt_for_download: false
              }
            }
          },
          url:
        }
      ]
    end
  end
end
