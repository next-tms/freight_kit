module FreightKit
  module Platforms
    class NextTMS
      class GraphQLClient
        module Query
          class Shipments
            DETAILS = Client.parse(<<~GRAPHQL)
              query($filter: ShipmentFilter, $page: Int, $pageSize: Int, $sort: [String!]) {
                shipments(filter: $filter, page: $page, pageSize: $pageSize, sort: $sort) {
                  items {
                    bol
                    bookedAt
                    brokerCarrier {
                      account
                      carrier {
                        id
                        mcNumber
                        name
                        scac
                      }
                      id
                    }
                    brokerCustomer {
                      customer {
                        id
                        name
                      }
                      id
                    }
                    canceledAt
                    createdAt
                    customerReference
                    deliveredAt
                    deliveryAppointmentAt
                    deliveryAppointmentOn
                    deliveryEtaOn
                    departedOriginTerminalAt
                    dispatchedAt
                    events {
                      city
                      countryAlpha2
                      id
                      name
                      occurredAt
                      regionIso31662
                      typeCode
                      zipCode
                    }
                    id
                    loadId
                    lostOn
                    outForDeliveryAt
                    pendingAppointmentSince
                    pickedUpAt
                    pickupDriverAssignedAt
                    pickupOn
                    pro
                    receiverAddress {
                      city
                      country {
                        alpha2Code
                      }
                      id
                      region {
                        abbreviation
                      }
                      street
                      street2
                      timeZoneName
                      zipCode
                    }
                    receiverName
                    shipperAddress {
                      city
                      country {
                        alpha2Code
                      }
                      id
                      region {
                        abbreviation
                      }
                      street
                      street2
                      timeZoneName
                      zipCode
                    }
                    shipperBol
                    shipperName
                    shipperReference
                    status
                    totalChargesCents
                    totalChargesCurrency
                    truckload
                    updatedAt
                  }
                  page
                  pageSize
                  pages
                  totalItems
                  updatedAt
                  version
                }
              }
            GRAPHQL
          end
        end
      end
    end
  end
end
