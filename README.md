# HyperCarrier

This library interfaces with the web services of various shipping carriers. The goal is to abstract the features that are most frequently used into a pleasant and consistent Ruby API:

- Finding shipping rates
- Registering shipments
- Tracking shipments
- Purchasing shipping labels

## Supported Shipping Carriers


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

### Compare rates from different carriers

```ruby
require 'hyper_carrier'

# Package up a poster and a Wii for your nephew.
packages = [
  HyperCarrier::Package.new(100,               # 100 grams
                              [93,10],           # 93 cm long, 10 cm diameter
                              cylinder: true),   # cylinders have different volume calculations

  HyperCarrier::Package.new(7.5 * 16,          # 7.5 lbs, times 16 oz/lb.
                              [15, 10, 4.5],     # 15x10x4.5 inches
                              units: :imperial)  # not grams, not centimetres
 ]

 # You live in Beverly Hills, he lives in Ottawa
 origin = HyperCarrier::Location.new(country: 'US',
                                       state: 'CA',
                                       city: 'Beverly Hills',
                                       zip: '90210')

 destination = HyperCarrier::Location.new(country: 'CA',
                                            province: 'ON',
                                            city: 'Ottawa',
                                            postal_code: 'K1P 1J1')

 # Find out how much it'll be.
 usps = HyperCarrier::USPS.new(login: 'developer-key')
 response = usps.find_rates(origin, destination, packages)

 usps_rates = response.rates.sort_by(&:price).collect {|rate| [rate.service_name, rate.price]}
 # => [["USPS Priority Mail International", 4110],
 #     ["USPS Express Mail International (EMS)", 5750],
 #     ["USPS Global Express Guaranteed Non-Document Non-Rectangular", 9400],
 #     ["USPS GXG Envelopes", 9400],
 #     ["USPS Global Express Guaranteed Non-Document Rectangular", 9400],
 #     ["USPS Global Express Guaranteed", 9400]]
```

Dimensions for packages are in `Height x Width x Length` order.

### Track a FedEx package

```ruby
fedex = HyperCarrier::FedEx.new(login: '999999999', password: '7777777', key: '1BXXXXXXXXXxrcB', account: '51XXXXX20')
tracking_info = fedex.find_tracking_info('tracking-number', carrier_code: 'fedex_ground') # Ground package

tracking_info.shipment_events.each do |event|
  puts "#{event.name} at #{event.location.city}, #{event.location.state} on #{event.time}. #{event.message}"
end
# => Package information transmitted to FedEx at NASHVILLE LOCAL, TN on Thu Oct 23 00:00:00 UTC 2008.
# Picked up by FedEx at NASHVILLE LOCAL, TN on Thu Oct 23 17:30:00 UTC 2008.
# Scanned at FedEx sort facility at NASHVILLE, TN on Thu Oct 23 18:50:00 UTC 2008.
# Departed FedEx sort facility at NASHVILLE, TN on Thu Oct 23 22:33:00 UTC 2008.
# Arrived at FedEx sort facility at KNOXVILLE, TN on Fri Oct 24 02:45:00 UTC 2008.
# Scanned at FedEx sort facility at KNOXVILLE, TN on Fri Oct 24 05:56:00 UTC 2008.
# Delivered at Knoxville, TN on Fri Oct 24 16:45:00 UTC 2008. Signed for by: T.BAKER
```

## Carrier specific notes

### FedEx connection

The `:login` key passed to `HyperCarrier::FedEx.new()` is really the FedEx meter number, not the FedEx login.

When developing with test credentials, be sure to pass `test: true` to `HyperCarrier::FedEx.new()`.


## Tests

You can run the unit tests with:

```
bundle exec rake test:unit
```

and the remote tests with:

```
bundle exec rake test:remote
```

The unit tests mock out requests and responses so that everything runs locally, while the remote tests actually hit the carrier servers. For the remote tests, you'll need valid test credentials for any carriers' tests you want to run. The credentials should go in [`~/.hyper_carrier/credentials.yml`](https://github.com/realsubpop/hyper_carrier/blob/master/test/credentials.yml). For some carriers, we have public credentials you can use for testing in `.travis.yml`. Remote tests missing credentials will be skipped.


## Contributing

See [CONTRIBUTING.md](https://github.com/realsubpop/hyper_carrier/blob/master/CONTRIBUTING.md).

We love getting pull requests! Anything from new features to documentation clean up.

If you're building a new carrier, a good place to start is in the [`Carrier` base class](https://github.com/realsubpop/hyper_carrier/blob/master/lib/hyper_carrier/carrier.rb).

It would also be good to familiarize yourself with [`Location`](https://github.com/realsubpop/hyper_carrier/blob/master/lib/hyper_carrier/location.rb), [`Package`](https://github.com/realsubpop/hyper_carrier/blob/master/lib/hyper_carrier/package.rb), and [`Response`](https://github.com/realsubpop/hyper_carrier/blob/master/lib/hyper_carrier/response.rb).

You can use the [`test/console.rb`](https://github.com/realsubpop/hyper_carrier/blob/master/test/console.rb) to do some local testing against real endpoints.

To log requests and responses, just set the `logger` on your Carrier class to some kind of `Logger` object:

```ruby
HyperCarrier::USPS.logger = Logger.new(STDOUT)
```

### Anatomy of a pull request

Any new features or carriers should have passing unit _and_ remote tests. Look at some existing carriers as examples.

When opening a pull request, include description of the feature, why it exists, and any supporting documentation to explain interaction with carriers.


### How to contribute

1. Fork it ( https://github.com/realsubpop/hyper_carrier/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
