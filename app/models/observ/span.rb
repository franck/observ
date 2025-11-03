# frozen_string_literal: true

module Observ
  class Span < Observation
    def finalize(output: nil, status_message: nil)
      update!(
        output: output.is_a?(String) ? output : output.to_json,
        end_time: Time.current,
        status_message: status_message
      )
    end
  end
end
