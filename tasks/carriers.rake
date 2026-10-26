require 'json'
require 'securerandom'

namespace :carriers do
  census_url = 'https://data.transportation.gov/resource/kjg3-diqy.json'
  authority_url = 'https://data.transportation.gov/resource/inys-ebih.json'
  suffixes = /\s*,?\s+\b(INCORPORATED|INC|LLC|L L C|CORPORATION|CORP|COMPANY|CO|LTD|LP|LIMITED)\.?\z/i

  soda = ->(url, where) do
    response = HTTPX.with(headers: { 'user-agent' => FreightKit::HTTPClient::USER_AGENT })
                    .get(url, params: { '$limit' => 25, '$where' => where })
    response.raise_for_status
    JSON.parse(response.body.to_s)
  end

  number_literal = ->(number) { number.to_s.reverse.scan(/\d{1,3}/).join('_').reverse }

  titleize = ->(name) do
    name.split.map { |word| word.match?(/\A(LLC|[^AEIOUY]{2,4})\z/i) ? word.upcase : word.capitalize }.join(' ')
  end

  desc 'Add a carrier from the FMCSA census by DOT number (QUERY=242009), MC number (QUERY=MC170247) or name'
  task(add: :environment) do
    query = ENV.fetch('QUERY').strip

    rows = case query
           when /\A\d+\z/ then soda.call(census_url, "dot_number='#{query}'")
           when /\AMC-?(\d+)\z/i
             dots = soda.call(authority_url, "docket_number='MC#{Regexp.last_match(1)}'").pluck('usdot_number').uniq
             dots.empty? ? [] : soda.call(census_url, "dot_number in (#{dots.map { |dot| "'#{dot}'" }.join(',')})")
           else
             name = query.upcase.gsub("'", "''")
             soda.call(census_url, "legal_name='#{name}' OR dba_name='#{name}'")
           end

    if rows.size != 1
      columns = ['dba_name', 'dot_number', 'legal_name', 'nbr_power_unit', 'phy_city', 'phy_state']
      rows.each { |row| puts row.values_at(*columns).join(' | ') }
      abort("Found #{rows.size} census records for #{query}. Run again with QUERY set to the DOT number.")
    end

    row = rows.first
    authorities = soda.call(authority_url, "usdot_number='#{row['dot_number']}' AND op_auth_status='Active'")
    unless row['authorized_for_hire'] == 'true' || row['exempt_for_hire'] == 'true' || authorities.any?
      abort("#{row['legal_name']} is not a for-hire carrier or broker")
    end

    legal_name = ENV.fetch('LEGAL_NAME') { titleize.call(row['legal_name']) }
    name = ENV.fetch('NAME') { titleize.call((row['dba_name'].presence || row['legal_name']).sub(suffixes, '')) }
    us_dot_number = row['dot_number'].to_i
    mc_docket = authorities.pluck('docket_number').find { |docket| docket.start_with?('MC') }
    us_mc_number = mc_docket.delete_prefix('MC').to_i if mc_docket

    existing = FreightKit::Carriers.all.find do |carrier|
      carrier.us_dot_number == us_dot_number || (us_mc_number && carrier.us_mc_number == us_mc_number)
    end
    abort("#{existing} already has DOT number #{us_dot_number} or MC number #{us_mc_number}") if existing

    words = name.gsub('&', ' and ').delete("'’.,()").split(%r{[\s\-/]+}).flat_map do |word|
      word.match?(/\A[A-Z0-9]+\z/) ? [word] : word.scan(/[A-Z]+(?![a-z])|[A-Z]?[a-z0-9]+/)
    end
    class_name = words.map { |word| word.match?(/\A[A-Z0-9]+\z/) ? word : word[0].upcase + word[1..] }.join
    basename = words.map(&:downcase).join('_')
    path = File.expand_path("../lib/freight_kit/carriers/#{basename}.rb", __dir__)
    abort("#{path} already exists") if File.exist?(path)

    acronyms = words.select { |word| word.length > 1 && word.match?(/\A[A-Z]+\z/) && word.capitalize != word }
    inflector_path = File.expand_path('../lib/freight_kit.rb', __dir__)
    inflector = File.read(inflector_path)
    known = inflector[/CARRIER_ACRONYMS = \[(.*?)\]/m, 1].scan(/'(\w+)'/).flatten
    if (acronyms - known).any?
      list = (known + acronyms).uniq.sort.map { |acronym| "                         '#{acronym}',\n" }.join
      File.write(inflector_path, inflector.sub(/(CARRIER_ACRONYMS = \[\n).*?(                       \]\.index_by)/m) do
        "#{Regexp.last_match(1)}#{list}#{Regexp.last_match(2)}"
      end)
    end

    identity = {
      id: "'#{SecureRandom.uuid}'",
      name: name.inspect.tr('"', "'"),
      legal_name: legal_name.inspect.tr('"', "'"),
      us_dot_number: number_literal.call(us_dot_number),
      us_mc_number: us_mc_number && number_literal.call(us_mc_number)
    }.compact

    File.write(path, <<~RUBY)
      module FreightKit
        module Carriers
          class #{class_name} < FreightKit::Carrier
            class << self
      #{identity.map { |key, value| "        def #{key} = #{value}" }.join("\n")}
            end
          end
        end
      end
    RUBY

    registry_path = File.expand_path('../lib/freight_kit/carriers.rb', __dir__)
    File.write(registry_path, "#{File.read(registry_path)}FreightKit::Carriers.register(:#{class_name})\n")

    puts "Added FreightKit::Carriers::#{class_name} (#{name}, #{legal_name}, DOT #{us_dot_number}) in #{path}"
  end

  desc 'Record released carrier, address, contact and terminal ids in spec/fixtures/carrier_ids.yml'
  task(snapshot_ids: :environment) do
    path = File.expand_path('../spec/fixtures/carrier_ids.yml', __dir__)
    released = File.exist?(path) ? YAML.load_file(path) : {}

    current = FreightKit::Carriers.all.to_h do |carrier|
      [
        carrier.id,
        {
          'check_mailing_addresses' => carrier.check_mailing_addresses.map(&:id),
          'contacts' => carrier.contacts.map(&:id),
          'headquarters' => carrier.headquarters&.id,
          'terminals' => carrier.terminals.map(&:id)
        }.compact
      ]
    end

    # Released ids are never dropped from the snapshot, so the spec keeps guarding them.
    snapshot = released.merge(current) do |_, old, new|
      old.merge(new) { |_, old_ids, new_ids| old_ids.is_a?(Array) ? (old_ids | new_ids) : new_ids }
    end

    mkdir_p(File.dirname(path))
    File.write(path, snapshot.sort.to_h.to_yaml)
    puts "Recorded #{snapshot.size} carriers in #{path}"
  end
end
