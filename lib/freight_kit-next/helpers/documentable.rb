# frozen_string_literal: true

module FreightKit
  module Documentable
    class << self
      def included(base)
        base.send(:extend, ClassMethods)
      end
    end

    module ClassMethods
      def find_tracking_info_implemented?
        true
      end
    end

    def pod(tracking_number)
      parse_document_response(:pod, tracking_number)
    end

    def pod_implemented?
      true
    end

    def scanned_bol(tracking_number)
      parse_document_response(:bol, tracking_number)
    end

    def scanned_bol_implemented?
      true
    end
  end
end
