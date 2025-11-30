# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Observ::Concerns::ObservableService do
  let(:test_service_class) do
    Class.new do
      include Observ::Concerns::ObservableService

      def initialize(observability_session: nil, metadata: {})
        initialize_observability(
          observability_session,
          service_name: 'test_service',
          metadata: metadata
        )
      end

      def perform
        with_observability do |session|
          { result: 'success', session_id: session&.session_id }
        end
      end

      def perform_with_error
        with_observability do |_session|
          raise StandardError, 'Something went wrong'
        end
      end

      def perform_with_chat(chat)
        with_observability do |_session|
          instrument_chat(chat, context: { operation: 'test' })
          { result: 'instrumented' }
        end
      end

      def perform_with_image_generation
        with_observability do |_session|
          instrument_image_generation(context: { operation: 'product_image' })
          { result: 'image_instrumented' }
        end
      end
    end
  end

  describe '#initialize_observability' do
    context 'when observability is enabled' do
      before do
        allow(Rails.configuration.observability).to receive(:enabled).and_return(true)
      end

      it 'creates a new session when none provided' do
        service = test_service_class.new

        expect(service.observability).to be_a(Observ::Session)
        expect(service.observability.user_id).to eq('test_service_service')
        expect(service.observability.metadata).to include('agent_type' => 'test_service', 'standalone' => true)
      end

      it 'uses provided session' do
        existing_session = create(:observ_session)
        service = test_service_class.new(observability_session: existing_session)

        expect(service.observability).to eq(existing_session)
      end

      it 'disables observability when passed false' do
        service = test_service_class.new(observability_session: false)

        expect(service.observability).to be_nil
      end

      it 'includes custom metadata in session' do
        service = test_service_class.new(metadata: { custom_key: 'custom_value' })

        expect(service.observability.metadata).to include('custom_key' => 'custom_value')
      end
    end

    context 'when observability is disabled' do
      before do
        allow(Rails.configuration.observability).to receive(:enabled).and_return(false)
      end

      it 'does not create a session' do
        service = test_service_class.new

        expect(service.observability).to be_nil
      end
    end
  end

  describe '#with_observability' do
    before do
      allow(Rails.configuration.observability).to receive(:enabled).and_return(true)
    end

    it 'yields the session to the block' do
      service = test_service_class.new
      result = service.perform

      expect(result[:session_id]).to eq(service.observability.session_id)
    end

    it 'returns the block result' do
      service = test_service_class.new
      result = service.perform

      expect(result[:result]).to eq('success')
    end

    it 'finalizes owned session on success' do
      service = test_service_class.new
      session = service.observability

      expect(session).to receive(:finalize)
      service.perform
    end

    it 'does not finalize session when not owned' do
      existing_session = create(:observ_session)
      service = test_service_class.new(observability_session: existing_session)

      expect(existing_session).not_to receive(:finalize)
      service.perform
    end

    it 'finalizes owned session on error and re-raises' do
      service = test_service_class.new
      session = service.observability

      expect(session).to receive(:finalize)
      expect { service.perform_with_error }.to raise_error(StandardError, 'Something went wrong')
    end

    it 'works when observability is nil' do
      service = test_service_class.new(observability_session: false)
      result = service.perform

      expect(result[:result]).to eq('success')
      expect(result[:session_id]).to be_nil
    end
  end

  describe '#instrument_chat' do
    before do
      allow(Rails.configuration.observability).to receive(:enabled).and_return(true)
    end

    let(:chat) do
      chat_double = double('Chat', id: 1, model: double(id: 'gpt-4o-mini'))
      allow(chat_double).to receive(:on_tool_call)
      allow(chat_double).to receive(:on_tool_result)
      allow(chat_double).to receive(:on_new_message)
      allow(chat_double).to receive(:on_end_message)
      chat_double
    end

    it 'instruments chat through session' do
      service = test_service_class.new
      session = service.observability

      expect(session).to receive(:instrument_chat).with(chat, context: { operation: 'test' })
      service.perform_with_chat(chat)
    end

    it 'does nothing when observability is disabled' do
      service = test_service_class.new(observability_session: false)

      # Should not raise
      result = service.perform_with_chat(chat)
      expect(result[:result]).to eq('instrumented')
    end
  end

  describe '#instrument_image_generation' do
    before do
      allow(Rails.configuration.observability).to receive(:enabled).and_return(true)
    end

    it 'instruments image generation through session' do
      service = test_service_class.new
      session = service.observability

      expect(session).to receive(:instrument_image_generation).with(context: { operation: 'product_image' })
      service.perform_with_image_generation
    end

    it 'does nothing when observability is disabled' do
      service = test_service_class.new(observability_session: false)

      # Should not raise
      result = service.perform_with_image_generation
      expect(result[:result]).to eq('image_instrumented')
    end
  end
end
