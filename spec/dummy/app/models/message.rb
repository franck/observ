# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :chat
  include Observ::TraceAssociation
end
