# FreightKit

This library interfaces with the web services of various shipping carriers. The goal is to abstract the features that are most frequently used into a pleasant and consistent Ruby API.

FreightKit supports:

- Downloading scanned documents
- Finding shipping rates
- Tracking shipments

On a technical level it supports:

- Abstracted accessorials
- Abstracted tracking events
- Cubic feet and density calculations
- Freight class calculations (and manual overriding)

## Definitions

Carrier: Has unique web services pertaining to whatever real-world services they provide.

Platform: Provides web-accessible services for many carriers at once.

__Note:__ `Carrier`s may extend `Platform`s and override them when their behavior differs from the `Platform`.

## Supported Platforms

* [Carrier Logistics](https://carrierlogistics.com)
* [The Great Information Factory](https://www.tgifsoftware.com)

## Supported Carriers

|Carrier                            |Scanned BOL|POD|Pickups|Rates|Tracking|
|-----------------------------------|-----------|---|-------|-----|--------|
|ABF Freight System                 |           |   |       |✓    |        |
|Best Overnite Express              |✓          |✓  |✓      |✓    |✓       |
|Clear Lane Freight Systems         |           |   |       |✓    |        |
|DC Logistics                       |✓          |✓  |✓      |✓    |✓       |
|The Custom Companies               |           |   |       |✓    |✓       |
|Dependable Highway Express         |✓          |✓  |       |✓    |✓       |
|Forward Air                        |✓          |✓  |✓      |✓    |✓       |
|Frontline Freight                  |✓          |✓  |       |✓    |✓       |
|Numark Transportation              |✓          |✓  |✓      |✓    |✓       |
|OnTrac                             |           |   |       |✓    |        |
|Peninsula Truck Lines              |           |   |       |✓    |        |
|Roadrunner Transportation Services |✓          |✓  |       |✓    |✓       |
|Saia                               |           |   |✓      |✓    |✓       |
|Southeastern Freight Lines         |           |   |       |✓    |        |
|Tforce Worldwide                   |✓          |✓  |✓      |✓    |        |
|Total Transportation & Distribution|✓          |✓  |       |✓    |✓       |
|Western Regional Delivery Service  |           |✓  |       |     |✓       |

## Installation

Using bundler, add to the `Gemfile`:

```ruby
gem 'freight_kit'
```

Or standalone:

```
$ gem install freight_kit
```

## HTTP Client

FreightKit sends HTTP requests through `FreightKit::HTTPClient`, a wrapper around HTTPX. The client keeps connections open between requests, and it reuses HTTP/2 connections. If a connection fails, the client retries only idempotent requests, such as GET. It never retries a POST, because the carrier can already have processed it. The client asks carriers for Brotli, Zstandard, gzip, and deflate compression.

### Logging

The client writes request and response details at the debug level. By default it uses `Rails.logger`, or the Hanami app logger. Outside Rails and Hanami, it logs to standard output at the level in the `LOG_LEVEL` environment variable. The default level is `info`.

To use a different logger, set it at boot:

```ruby
FreightKit::HTTPClient.logger = Logger.new($stdout, level: :debug)
```

Debug output contains request headers and bodies, which include carrier credentials. Do not use the debug level in production.

### Cache

The client uses conditional requests: it sends `If-None-Match` and `If-Modified-Since` and reuses the cached body when the carrier replies `304 Not Modified`.

By default, the client keeps cached responses in an in-process `ActiveSupport::Cache::MemoryStore`. To share the cache between processes, set your own backend at boot. The backend must respond to `read`, `write`, and `delete_matched`, like `ActiveSupport::Cache::Store`.

In Rails, add this line to an initializer:

```ruby
FreightKit::HTTPClient.cache = Rails.cache
```

In Hanami or plain Ruby, give any compatible store:

```ruby
FreightKit::HTTPClient.cache = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch('REDIS_URL'))
```

Cache entries contain carrier response bodies. Use a backend that you trust with that data. Keys are SHA-256 digests of the method, the URL, and all request headers. Requests with different credentials thus never share an entry. To turn off the cache, set `ActiveSupport::Cache::NullStore.new`.

## Standard Usage

Start off by initializing a `Carrier`:

```ruby
require 'freight_kit'

# Typically just one `Credential` is required
credentials = [
  FreightKit::Credential.new(
    type: :api,
    account: 'account_number',
    username: 'username',
    password: 'password',
    tariff: FreightKit::Tariff.new # optional
  ),
  FreightKit::Credential.new(
    type: :oauth2,
    access_token: 'token',
    expires_at: DateTime.current + 1.day, # DateTime
    scope: 'scope'
  ),
  FreightKit::Credential.new(
    type: :website,
    username: 'username',
    password: 'password'
  ),
  FreightKit::Credential.new(
    type: :selenoid,
    base_url: URI.parse('http://domain:4444'),
    browser: :chrome
  )
]

carrier = FreightKit::Carriers::Saia.new(credentials)
```

### Documents

```ruby
carrier.bol(tracking_number) # BOL generated by carrier
carrier.scanned_bol(tracking_number) # BOL scanned by carrier

carrier.pod(tracking_number)
```

### Tracking

```ruby
tracking = carrier.find_tracking_info(tracking_number)

tracking.delivered?
tracking.status

tracking.shipment_events.each do |event|
  puts "#{event.name} at #{event.location.city}, #{event.location.state} on #{event.time}. #{event.message}"
end
```

### Quoting

```ruby
packages = [
  FreightKit::Package.new(
    371 * 16, # 371 lbs
    {
      length: 40, # inches
      width: 48,
      height: 47
    },
    units: :imperial
  ),
  FreightKit::Package.new(
    371 * 16, # 371 lbs
    {
      length: 40, # inches
      width: 48,
      height: 47
    },
    freight_class: 125, # override calculated freight class
    units: :imperial
  )
]

origin = FreightKit::Location.new(
  country: 'US',
  state: 'CA',
  city: 'Los Angeles',
  zip: '90001'
)

destination = FreightKit::Location.new(
  country: 'US',
  state: 'IL',
  city: 'Chicago',
  zip: '60007'
)

accessorials = %i[
  appointment_delivery
  liftgate_delivery
  residential_delivery
]

response = carrier.find_rates(origin, destination, packages, accessorials: accessorials)
rates = response.rates
rates = response.rates.sort_by(&:price).collect { |rate| [rate.service_name, rate.price] }
```
