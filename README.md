# Interstellar

This library interfaces with the web services of various shipping carriers. The goal is to abstract the features that are most frequently used into a pleasant and consistent Ruby API.

Interstellar supports:

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

## Plug-in System

Interstellar relies on plug-ins (gems) to define how it connects to individual `Carrier`s and `Platform`s.

## Installation

Using bundler, add to the `Gemfile`:

```ruby
gem 'interstellar'
```

Or standalone:

```
$ gem install interstellar
```

__Note__: Plug-ins are required to connect to `Carrier`s and `Platforms` (see above).

## Standard Usage

Start off by initializing the `Carrier` provided by a `Carrier` plug-in:

```ruby
require 'interstellar'

carrier = Interstellar::BTVP.new(
  account: 'account_number',
  username: 'username',
  password: 'password'
)
```

### Documents

```ruby
carrier.find_bol(tracking_number)

# Path is optional:
carrier.find_pod(tracking_number, path: 'POD.pdf')
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
  Interstellar::Package.new(
    371 * 16, # 371 lbs
    {
      length: 40, # inches
      width: 48,
      height: 47
    },
    units: :imperial
  ),
  Interstellar::Package.new(
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

origin = Interstellar::Location.new(
  country: 'US',
  state: 'CA',
  city: 'Los Angeles',
  zip: '90001'
)

destination = Interstellar::Location.new(
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
