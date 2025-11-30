# frozen_string_literal: true

module Observ
  module Concerns
    # Concern for adding observability to service objects
    #
    # This module provides automatic observability session management for services
    # that perform LLM operations. It handles session creation, lifecycle management,
    # and chat instrumentation.
    #
    # Usage:
    #   class MyService
    #     include Observ::Concerns::ObservableService
    #
    #     def initialize(observability_session: nil)
    #       initialize_observability(
    #         observability_session,
    #         service_name: "my_service",
    #         metadata: { custom: "data" }
    #       )
    #     end
    #
    #     def perform(input)
    #       with_observability do |session|
    #         # Your service logic here
    #         # Session automatically finalized on success/error
    #       end
    #     end
    #   end
    module ObservableService
      extend ActiveSupport::Concern

      included do
        attr_reader :observability
      end

      # Initialize observability for the service
      #
      # @param session_or_false [Observ::Session, false, nil] Session to use, false to disable, nil to auto-create
      # @param service_name [String] Name of the service (used in session metadata)
      # @param metadata [Hash] Additional metadata to include in the session
      def initialize_observability(session_or_false = nil, service_name:, metadata: {})
        if session_or_false == false
          # Explicitly disable observability
          @observability = nil
          @owns_session = false
        elsif session_or_false
          # Use provided session
          @observability = session_or_false
          @owns_session = false
        else
          # Auto-create session for standalone use
          @observability = create_service_session(service_name, metadata)
          @owns_session = @observability.present?
        end
      end

      # Execute a block with automatic session lifecycle management
      #
      # The session will be finalized automatically after the block completes,
      # whether it succeeds or raises an error. Only sessions owned by this
      # service instance (i.e., auto-created sessions) will be finalized.
      #
      # @yield [session] The observability session (may be nil if disabled)
      # @return The result of the block
      #
      # @example
      #   with_observability do |session|
      #     # Your service logic here
      #     process_data(session)
      #   end
      def with_observability(&block)
        result = block.call(@observability)
        finalize_service_session if @owns_session
        result
      rescue StandardError
        finalize_service_session if @owns_session
        raise
      end

      # Instrument a RubyLLM chat instance for observability
      #
      # This wraps the chat's ask method to automatically create traces
      # and track LLM calls within the observability session.
      #
      # @param chat [RubyLLM::Chat] The chat instance to instrument
      # @param context [Hash] Additional context to include in traces
      # @return [Observ::ChatInstrumenter, nil] The instrumenter or nil if observability is disabled
      #
      # @example
      #   chat = RubyLLM.chat(model: "gpt-4")
      #   instrument_chat(chat, context: { operation: "summarize" })
      #   response = chat.ask("Summarize this text")
      def instrument_chat(chat, context: {})
        return unless @observability

        @observability.instrument_chat(chat, context: context)
      end

      # Instrument RubyLLM.embed for observability
      #
      # This wraps the RubyLLM.embed class method to automatically create traces
      # and track embedding calls within the observability session.
      #
      # @param context [Hash] Additional context to include in traces
      # @return [Observ::EmbeddingInstrumenter, nil] The instrumenter or nil if observability is disabled
      #
      # @example
      #   instrument_embedding(context: { operation: "semantic_search" })
      #   embedding = RubyLLM.embed("Search query")
      def instrument_embedding(context: {})
        return unless @observability

        @observability.instrument_embedding(context: context)
      end

      # Instrument RubyLLM.paint for observability
      #
      # This wraps the RubyLLM.paint class method to automatically create traces
      # and track image generation calls within the observability session.
      #
      # @param context [Hash] Additional context to include in traces
      # @return [Observ::ImageGenerationInstrumenter, nil] The instrumenter or nil if observability is disabled
      #
      # @example
      #   instrument_image_generation(context: { operation: "product_image" })
      #   image = RubyLLM.paint("A modern logo")
      def instrument_image_generation(context: {})
        return unless @observability

        @observability.instrument_image_generation(context: context)
      end

      # Instrument RubyLLM.transcribe for observability
      #
      # This wraps the RubyLLM.transcribe class method to automatically create traces
      # and track transcription calls within the observability session.
      #
      # @param context [Hash] Additional context to include in traces
      # @return [Observ::TranscriptionInstrumenter, nil] The instrumenter or nil if observability is disabled
      #
      # @example
      #   instrument_transcription(context: { operation: "meeting_notes" })
      #   transcript = RubyLLM.transcribe("meeting.wav")
      def instrument_transcription(context: {})
        return unless @observability

        @observability.instrument_transcription(context: context)
      end

      private

      # Create a new observability session for this service
      #
      # @param service_name [String] Name of the service
      # @param metadata [Hash] Additional metadata for the session
      # @return [Observ::Session, nil] The created session or nil if observability is disabled/failed
      def create_service_session(service_name, metadata = {})
        return nil unless Rails.configuration.observability.enabled

        Observ::Session.create!(
          user_id: "#{service_name}_service",
          metadata: metadata.merge(
            agent_type: service_name,
            standalone: true,
            created_at: Time.current.iso8601
          )
        )
      rescue StandardError => e
        Rails.logger.error(
          "[#{self.class.name}] Failed to create observability session: #{e.message}"
        )
        nil
      end

      # Finalize the observability session if we own it
      #
      # This marks the session as complete and triggers aggregation of metrics.
      # Only called for sessions created by this service instance.
      def finalize_service_session
        return unless @observability

        @observability.finalize
        Rails.logger.debug(
          "[#{self.class.name}] Session finalized: #{@observability.session_id}"
        )
      rescue StandardError => e
        Rails.logger.error(
          "[#{self.class.name}] Failed to finalize session: #{e.message}"
        )
      end
    end
  end
end
