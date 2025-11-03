module Observ
  module TraceAssociation
    extend ActiveSupport::Concern

    included do
      has_many :traces, class_name: "Observ::Trace", dependent: :nullify
    end
  end
end
