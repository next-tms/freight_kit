# frozen_string_literal: true

module FreightKit
  module Documentable
    def pod(tracking_number)
      parse_document_response(:pod, tracking_number)
    end

    def scanned_bol(tracking_number)
      parse_document_response(:bol, tracking_number)
    end
  end
end
