# Interstellar CHANGELOG

### v0.1.pre1

- Change HyperCarrier name to Interstellar
- Change version to 0.0.1_beta1
- Remove all carriers and platforms

## From HyperCarrier

### v0.0.1

- Change ReactiveShipping name to HyperCarrier
- Change version to v0.0.1

## From ReactiveShipping

### v3.0.1 *Unofficial*

From pull request #2 [realsubpop/reactive_shipping/pull/2](https://github.com/realsubpop/reactive_shipping/pull/2)

- Add support for ActiveSupport 6.1

### v3.0.0

- Change ActiveShipping name to ReactiveShipping
- Return UPS support

## From ActiveShipping

### v2.2.0
- Remove UPS integration from ActiveShipping repository as requested by UPS. For information about the UPS APIs see https://www.ups.com/upsdeveloperkit

### v2.1.1
- Update README to clarify Shopify's involvement moving forward with v2.x

### v2.1.0
- Add email field to Location

### v2.0.0
- Drop support for < ruby 2.2, support ruby 2.4
- Drop support for < Rails 4.2.
- BREAKING CHANGE: Use shopify/measured instead of shopify/quantified for dimensions and units.

### v1.14.2
- Make saturday delivery an option for fedex

### v1.14.1
- Fix parsing of CanadaPostPWS service options response.

### v1.14.0
- Update Correios default services list.
- Fix CanadaPostPWS from generating an empty options tag.
- Allow contract-number on CanadaPost merchant detail's response to be nil.
- Fix a flakey UPS remote test that would fail only on Fridays.

### v1.13.4
- Upcase postal code for CanadaPostPWS
- Fix failing USPS test
- add .byebug_history to .gitignore

### v1.13.3
- CanadaPostPWS no longer modifies locations passed to it

### v1.13.2
- Bump active_utils to 3.3.1
- Allow activesupport <5.2.0

### v1.13.1
- Fix up UPS tracker parsing for Kosovo (KV)

### v1.13.0
- Add default location for CanadaPost PWS
- Patch UPS to use old Kosovo country code
- Add option to not include tax in rates for CP PWS

### v1.12.1
- Explicitly set ssl_version for USPS
- Strip 9 digit origin zip code for USPS world rate requests

### v1.12.0
- Update active_utils dependency to v3.3.0

### v1.8.6
- Fix UPS TrackResponse with no status code
- Stop FedEx from raising for successful responses with no statuses
- Raise appropriate exception response for FedEx errors

### v1.8.5
- Fix UPS TrackResponse parsing for missing elements

### v1.8.4
- Add price details to rate estimates
- Fix encoding for UPS responses

### v1.8.3
- Add description field to rate estimates

### v1.8.2
- Add option for FedEx label format
- Fix kunaki remote tests broken due to more shipping options

### v1.6.1
- Fix FedEx ShipmentEvents to include event type
- Skip broken Canada Post remote tests

### v1.6.0
- Update active_utils dependency to v3.2.0

### v1.5.0
- Fix Kunaki remote test
- Fix credentials for Canada Post PWS remote tests
- Add compare price to rate estimate options
- Add phone required to rate estimate options
- Update active_utils dependency to v3.1.0

### v1.4.3

- Fix UPS SurePost for < 1 pound packages
- Use status type code in UPS tracking
- Fix USPS and Fedex remote tests

### v1.4.2

- Fix USPS rates for commercial shipments

### v1.4.1

- Raise error on invalid status code with FedEx
- Fix USPS tracking to certain countries
- Fix USPS tracking of events with no time
- Fix USPS batch tracking error messages.
- Fix FedEx logging exception

### v1.4.0

- Added support for USPS merchant returns service
- Added support for UPS SurePost
- Added support for UPS third party billing
- Fix FedEx tracking response errors
- Add rake console command for development

### v1.3.0

- Support voiding labels on UPS
- Parse FedEx ground delivery dates
- Add maximum address length field
- Fix UPS unknown country code when using SUREPOST

### v1.2.2

- Fix "RECTANGULAR" errors with small USPS US->US package rate requests
- Fix error tracking USPS packages to other countries
- Fix USPS rate requests to destinations with only a country.

### v1.2.1

- Fix compatibility with latest USPS WEBTOOLS international rate schema changes.

### v1.2.0

- Added support for buying labels with FedEx
- Added support for batched tracking requests with USPS

### v1.1.3

- Handle ZIP+4 numbers in USPS tracking
- Add a field for rate estimate references
- Add support for UPS mail innovations tracking option

### v1.1.2

- Fix finding of error descriptions for USPS tracking

### v1.1.1

- Fix bug with USPS tracking not handling optional fields being absent.

### v1.1.0

- USPS: Allows package tracking disambiguation and exposes predicted arrival date and event codes.

### v1.0.0

- **BREAKING CHANGE:** Change namespace from `ActiveMerchant::Shipping` to `ActiveShipping`
- Drop support for Ruby 1.8 and Ruby 1.9.
- Drop support for ActiveSupport < 3.2, support up to ActiveSupport 4.2.
- Updated Fedex to use latest API version for tracking
- Various improvements to UPS carrier implementation.
- Small bugfixes in USPS carrier implementation.
- Various small bugfixes in XML handling for several carriers.
- Rewite all carriers to use nokogiri for XML parsing and generating.
- Bump `active_utils` dependency to require 3.x to avoid conflicts with `ActiveMerchant`.
- Extracted `quantified` into separate gem.
- Removed vendored `XmlNode` library.
- Removed `builder` dependency.
- Improved test setup that allows running functional tests on CI.
- Improved documentation of the abstraction API.

### v0.10.1

 - Canada Post PWS: Makes wrapper act more consistently with the rest of the API [jnormore]
 - UPS: Adds insurance charge to package object declarations [pbonnell]
 - USPS: Improves how unavailable delivery information is handled [cyu]
 - Shipment Packer: Prevents packing errors and consistently return an array when packing [christianblais]
 - General: Improves tests such that they work with ruby 2.0 [Sirupsen]

### 2011/04/21

* USPS updated to use new APIs [james]
* new :gift boolean option for Package [james]
* Location's :address_type can be "po_box" [james]

### Earlier

* New Zealand Post [AbleTech]
* Include address name for rate requests to Shipwire if provided [dennis]
* Add support for address name to Location [dennis]
* Add fix for updated USPS API to strip any encoded html and trailing asterisks from rate names [dennis]
* Add carrier CanadaPost [william]
* Update FedEx rates and added ability to auto-generate rate name from code that gets returned by FedEx [dennis]
* Assume test_helper is in load path when running tests [cody]
* Add support Kunaki rating service [cody]
* Require active_support instead of activesupport to avoid deprecation warning in Rails 2.3.5 [cody]
* Remove ftools for Rails 1.9 compatibility and remove xml logging, as logging is now included in the connection [cody]
* Update connection code from ActiveMerchant [cody]
* Fix space-ridden USPS usernames when validating credentials [james]
* Remove extra slash from USPS URLs [james]
* Update Shipwire endpoint hostname [cody]
* Add missing ISO countries [Edward Ocampo-Gooding]
* Add support for Guernsey to country.rb [cody]
* Use :words_connector instead of connector in RequiresParameters [cody]
* Add name to Shipwire class [cody]
* Improve FedEx handling of some error conditions [cody]
* Add support for validating credentials to Shipwire [cody]
* Add support for ssl_get to PostsData. Update Carriers to use PostsData module. Turn on retry safety for carriers [cody]
* Add support for Shipwire Shipping Rate API [cody]
* Cleanup package tests [cody]
* Remove unused Carrier#setup method [cody]
* Don't use Array splat in Regex comparisons in Package [cody]
* Default the Location to use the :alpha2 country code format [cody]
* Add configurable timeouts from Active Merchant [cody]
* Update xml_node.rb from XML Node [cody]
* Update requires_parameters from ActiveMerchant [cody]
* Sync posts_data.rb with ActiveMerchant [cody]
* Don't use credentials fixtures in local tests [cody]
