# HyperCarrier

This library interfaces with the web services of various shipping carriers. The goal is to abstract the features that are most frequently used into a pleasant and consistent Ruby API.

It is based on [ReactiveFreight](https://github.com/brodyhoskins/reactive_freight) which depends on [ReactiveShipping](https://github.com/realsubpop/reactive_shipping), which in turn is based on [ActiveShipping](https://github.com/Shopify/active_shipping).

HyperCarrier supports:

- Download scanned documents including bill of lading and/or proof of delivery where supported
- Finding shipping rates
- Registering shipments
- Tracking shipments
- Purchasing shipping labels

It also includes the following features:

- Abstracted accessorials
- Abstracted tracking events
- Cubic feet and density calculations
- Freight class calculations (and manual overriding)

## Supported Freight Carriers & Platforms

*This list varies day to day as this the project is a work in progress*

Carriers differ from platforms in that they have unique web services whereas platforms host several carriers' web services on a single service (platform). Carriers however may extend platforms and override them for carrier-specific functionality.

### Freight Carriers

|Carrier                            |BOL|POD|Rates|Tracking|
|-----------------------------------|---|---|-----|--------|
|Best Overnite Express              |✓  |✓  |✓    |✓       |
|Clear Lane Freight Systems         |✓  |✓  |✓    |✓       |
|The Custom Companies               |   |   |✓    |✓       |
|Dependable Highway Express         |   |   |✓    |✓       |
|Forward Air                        |   |✓  |✓    |✓       |
|Frontline Freight                  |✓  |✓  |✓    |✓       |
|Peninsula Truck Lines              |   |   |✓    |        |
|Roadrunner Transportation Services |✓  |✓  |✓    |✓       |
|Saia                               |   |   |✓    |✓       |
|Southeastern Freight Lines         |   |   |✓    |        |
|Tforce Worldwide                   |✓  |✓  |✓    |        |
|Total Transportation & Distribution|✓  |✓  |✓    |✓       |
|Western Regional Delivery Service  |   |✓  |     |✓       |

### Package Carriers

* [UPS](http://www.ups.com)
* [USPS](http://www.usps.com)
* [USPS Returns](http://returns.usps.com)
* [FedEx](http://www.fedex.com)
* [Canada Post](http://www.canadapost.ca)
* [New Zealand Post](http://www.nzpost.co.nz)
* [Shipwire](http://www.shipwire.com)
* [Stamps](http://www.stamps.com)
* [Kunaki](http://www.kunaki.com)
* [Australia Post](http://auspost.com.au/)

### Platforms

* [Carrier Logistics](https://carrierlogistics.com)

## Installation

Using bundler, add to the `Gemfile`:

```ruby
gem 'hyper_carrier'
```

Or stand alone:

```
$ gem install hyper_carrier
```

## Sample Usage

Start off by initializing the carrier:

```ruby
require 'hyper_carrier'
carrier = HyperCarrier::BTVP.new(
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
  HyperFreight::Package.new(
    371 * 16, # 371 lbs
    {
      length: 40, # inches
      width: 48,
      height: 47
    },
    units: :imperial
  ),
  HyperCarrier::Package.new(
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

origin = HyperCarrier::Location.new(
  country: 'US',
  state: 'CA',
  city: 'Los Angeles',
  zip: '90001'
)

destination = HyperCarrier::Location.new(
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