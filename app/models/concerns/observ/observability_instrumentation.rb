module Observ
  module ObservabilityInstrumentation
    extend ActiveSupport::Concern

  included do
    belongs_to :observ_session, class_name: "Observ::Session", foreign_key: :observability_session_id,
               primary_key: :session_id, optional: true

    after_create :initialize_observability_session
    after_find :ensure_instrumented_if_needed

    attr_accessor :instrumenter
  end

  def ask_with_observability(message, **options)
    ensure_instrumented!
    ask(message, **options)
  end

  def complete_with_observability(&block)
    ensure_instrumented!
    complete(&block)
  end

  def update_observability_context(new_context)
    return unless observ_session && @instrumenter

    observ_session.update_metadata(new_context)
    @instrumenter.instance_variable_get(:@context).merge!(new_context)
  end

  def finalize_observability_session
    return unless observ_session

    observ_session.finalize
    Rails.logger.info "[Observability] Session finalized: #{observ_session.session_id}"
  end

  private

  # Hook method for building observability session metadata
  # Override this in your model or concerns to add custom metadata
  # @return [Hash] metadata hash
  def observability_metadata
    {
      agent_type: agent_class_name || "standard",
      chat_id: id
    }
  end

  # Hook method for building observability context
  # Override this in your model or concerns to add custom context
  # @return [Hash] context hash
  def observability_context
    context = {
      agent_type: agent_class_name || "standard",
      chat_id: id
    }

    # Include agent_class if available for prompt metadata extraction
    if respond_to?(:agent_class)
      context[:agent_class] = agent_class
    end

    context
  end

  def initialize_observability_session
    return unless Rails.configuration.observability.enabled

    session = Observ::Session.create!(
      user_id: "chat_#{id}",
      metadata: observability_metadata
    )

    update_column(:observability_session_id, session.session_id)

    instrument_rubyllm_chat if Rails.configuration.observability.auto_instrument_chats
  rescue StandardError => e
    Rails.logger.error "[Observability] Failed to initialize session: #{e.message}"
  end

  def instrument_rubyllm_chat
    return unless observ_session
    return if @instrumenter

    @instrumenter = Observ::ChatInstrumenter.new(
      observ_session,
      self,
      context: observability_context
    )
    @instrumenter.instrument!

  rescue StandardError => e
    Rails.logger.error "[Observability] Failed to instrument chat: #{e.message}"
  end

  def ensure_instrumented!
    return if @instrumenter

    reload_observ_session if observability_session_id && !observ_session
    instrument_rubyllm_chat if observ_session
  end

  def reload_observ_session
    self.observ_session = Observ::Session.find_by(session_id: observability_session_id)
  end

  def ensure_instrumented_if_needed
    return unless Rails.configuration.observability.enabled
    return if @instrumenter
    return unless observability_session_id

    ensure_instrumented!
  rescue StandardError => e
    Rails.logger.error "[Observability] Failed to auto-instrument on find: #{e.message}"
  end
  end
end
