require 'rails_helper'

RSpec.describe Observ::ObservabilityInstrumentation, type: :concern do
  let(:test_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'chats'
      include Observ::ObservabilityInstrumentation

      def agent_class_name
        'BaseAgent'
      end

      def current_phase
        'initial'
      end

      def ask(message, **options)
        "Asked: #{message}"
      end

      def complete(&block)
        block.call if block_given?
        "Completed"
      end
    end
  end

  let(:model) { test_class.new }

  describe 'associations' do
    it { expect(test_class.reflect_on_association(:observ_session)).to be_present }
    it { expect(test_class.reflect_on_association(:observ_session).class_name).to eq('Observ::Session') }
    it { expect(test_class.reflect_on_association(:observ_session).options[:optional]).to be_truthy }
  end

  describe 'callbacks' do
    it 'includes after_create callback for initialize_observability_session' do
      callbacks = test_class._create_callbacks.select { |cb| cb.filter == :initialize_observability_session }
      expect(callbacks).not_to be_empty
    end

    it 'includes after_find callback for ensure_instrumented_if_needed' do
      callbacks = test_class._find_callbacks.select { |cb| cb.filter == :ensure_instrumented_if_needed }
      expect(callbacks).not_to be_empty
    end
  end

  describe 'attributes' do
    it 'has instrumenter accessor' do
      expect(model).to respond_to(:instrumenter)
      expect(model).to respond_to(:instrumenter=)
    end
  end

  describe '#ask_with_observability' do
    let(:chat) { create(:chat) }

    it 'ensures instrumentation before asking' do
      expect(chat).to receive(:ensure_instrumented!)
      chat.ask_with_observability('test message')
    end

    it 'calls ask with message and options' do
      allow(chat).to receive(:ensure_instrumented!)
      expect(chat).to receive(:ask).with('test message')
      chat.ask_with_observability('test message')
    end
  end

  describe '#complete_with_observability' do
    let(:chat) { create(:chat) }

    it 'ensures instrumentation before completing' do
      expect(chat).to receive(:ensure_instrumented!)
      chat.complete_with_observability { }
    end

    it 'calls complete with block' do
      allow(chat).to receive(:ensure_instrumented!)
      block_called = false
      chat.complete_with_observability { block_called = true }
      expect(block_called).to be_truthy
    end
  end

  describe '#update_observability_context', observability: true do
    let(:chat) { create(:chat) }

    context 'when observ_session and instrumenter exist' do
      it 'updates session metadata' do
        new_context = { phase: 'research', depth: 'deep' }
        chat.update_observability_context(new_context)
        expect(chat.observ_session.reload.metadata).to include('phase' => 'research', 'depth' => 'deep')
      end

      it 'merges context into instrumenter' do
        new_context = { phase: 'research' }
        instrumenter = chat.instance_variable_get(:@instrumenter)
        original_context = instrumenter.instance_variable_get(:@context).dup

        chat.update_observability_context(new_context)
        updated_context = instrumenter.instance_variable_get(:@context)
        expect(updated_context).to include(original_context.merge(new_context))
      end
    end

    context 'when observ_session is nil' do
      it 'does nothing' do
        chat.update_column(:observability_session_id, nil)
        expect {
          chat.update_observability_context(phase: 'test')
        }.not_to raise_error
      end
    end

    context 'when instrumenter is nil' do
      it 'does nothing' do
        chat.instance_variable_set(:@instrumenter, nil)
        expect {
          chat.update_observability_context(phase: 'test')
        }.not_to raise_error
      end
    end
  end

  describe '#finalize_observability_session', observability: true do
    let(:chat) { create(:chat) }

    context 'when observ_session exists' do
      it 'finalizes the session' do
        chat.finalize_observability_session
        expect(chat.observ_session.reload.end_time).to be_present
      end

      it 'logs finalization' do
        allow(Rails.logger).to receive(:info)
        chat.finalize_observability_session
        expect(Rails.logger).to have_received(:info).with(/Session finalized/)
      end
    end

    context 'when observ_session is nil' do
      it 'does nothing' do
        chat.update_column(:observability_session_id, nil)
        expect {
          chat.finalize_observability_session
        }.not_to raise_error
      end
    end
  end

  describe '#initialize_observability_session', observability: true do
    let(:chat) { build(:chat) }

    context 'when observability is enabled' do
      before do
        allow(Rails.configuration.observability).to receive(:enabled).and_return(true)
        allow(Rails.configuration.observability).to receive(:auto_instrument_chats).and_return(true)
      end

      it 'creates a new observability session' do
        expect {
          chat.save
        }.to change(Observ::Session, :count).by(1)
      end

      it 'sets observability_session_id' do
        chat.save
        expect(chat.observability_session_id).to be_present
      end

      it 'creates session with correct metadata' do
        chat.save
        session = chat.observ_session
        expect(session.metadata['chat_id']).to eq(chat.id)
        expect(session.user_id).to eq("chat_#{chat.id}")
        expect(session.metadata['agent_type']).to be_present
      end

      it 'instruments chat when auto_instrument_chats is true' do
        chat.save
        expect(chat.instance_variable_get(:@instrumenter)).to be_present
      end

      it 'does not instrument when auto_instrument_chats is false' do
        allow(Rails.configuration.observability).to receive(:auto_instrument_chats).and_return(false)
        chat.save
        expect(chat.instance_variable_get(:@instrumenter)).to be_nil
      end
    end

    context 'when observability is disabled' do
      before do
        allow(Rails.configuration.observability).to receive(:enabled).and_return(false)
      end

      it 'does not create observability session' do
        expect {
          chat.save
        }.not_to change(Observ::Session, :count)
      end

      it 'does not set observability_session_id' do
        chat.save
        expect(chat.observability_session_id).to be_nil
      end
    end

    context 'when session creation fails' do
      before do
        allow(Rails.configuration.observability).to receive(:enabled).and_return(true)
        allow(Observ::Session).to receive(:create!).and_raise(StandardError.new('Database error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to initialize session/)
        chat.save
      end

      it 'does not raise error' do
        expect {
          chat.save
        }.not_to raise_error
      end
    end
  end

  describe '#instrument_rubyllm_chat', observability: true do
    let(:chat) { create(:chat) }

    context 'when observ_session exists and instrumenter is nil' do
      before do
        chat.instance_variable_set(:@instrumenter, nil)
      end

      it 'creates a new instrumenter' do
        chat.send(:instrument_rubyllm_chat)
        expect(chat.instance_variable_get(:@instrumenter)).to be_a(Observ::ChatInstrumenter)
      end

      it 'calls instrument! on the instrumenter' do
        expect_any_instance_of(Observ::ChatInstrumenter).to receive(:instrument!)
        chat.send(:instrument_rubyllm_chat)
      end
    end

    context 'when instrumenter already exists' do
      it 'does not create a new instrumenter' do
        original_instrumenter = chat.instance_variable_get(:@instrumenter)
        chat.send(:instrument_rubyllm_chat)
        expect(chat.instance_variable_get(:@instrumenter)).to eq(original_instrumenter)
      end
    end

    context 'when observ_session is nil' do
      it 'does not create instrumenter' do
        chat.update_column(:observability_session_id, nil)
        chat.instance_variable_set(:@instrumenter, nil)
        chat.send(:instrument_rubyllm_chat)
        expect(chat.instance_variable_get(:@instrumenter)).to be_nil
      end
    end

    context 'when instrumentation fails' do
      before do
        chat.instance_variable_set(:@instrumenter, nil)
        allow(Observ::ChatInstrumenter).to receive(:new).and_raise(StandardError.new('Instrumentation error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to instrument chat/)
        chat.send(:instrument_rubyllm_chat)
      end

      it 'does not raise error' do
        expect {
          chat.send(:instrument_rubyllm_chat)
        }.not_to raise_error
      end
    end
  end

  describe '#ensure_instrumented!', observability: true do
    let(:chat) { create(:chat) }

    context 'when instrumenter is present' do
      it 'does nothing' do
        original_instrumenter = chat.instance_variable_get(:@instrumenter)
        chat.send(:ensure_instrumented!)
        expect(chat.instance_variable_get(:@instrumenter)).to eq(original_instrumenter)
      end
    end

    context 'when instrumenter is nil and observ_session is not loaded' do
      before do
        chat.instance_variable_set(:@instrumenter, nil)
        chat.instance_variable_set(:@association_cache, {})
      end

      it 'instruments chat after reloading session' do
        chat.send(:ensure_instrumented!)
        expect(chat.instance_variable_get(:@instrumenter)).to be_present
      end
    end
  end

  describe '#reload_observ_session', observability: true do
    let(:chat) { create(:chat) }

    it 'reloads the observ_session from database' do
      session_id = chat.observability_session_id
      chat.instance_variable_set(:@association_cache, {})
      chat.send(:reload_observ_session)
      expect(chat.observ_session).to be_present
      expect(chat.observ_session.session_id).to eq(session_id)
    end
  end

  describe '#ensure_instrumented_if_needed', observability: true do
    let!(:chat) { create(:chat) }

    context 'when observability is enabled' do
      before do
        allow(Rails.configuration.observability).to receive(:enabled).and_return(true)
      end

      it 'reattaches instrumenter when chat is reloaded' do
        reloaded_chat = Chat.find(chat.id)
        expect(reloaded_chat.instance_variable_get(:@instrumenter)).to be_present
      end

      it 'uses existing session' do
        original_session_id = chat.observability_session_id
        reloaded_chat = Chat.find(chat.id)
        expect(reloaded_chat.observability_session_id).to eq(original_session_id)
      end

      it 'does nothing when instrumenter is already attached' do
        chat.send(:ensure_instrumented_if_needed)
        original_instrumenter = chat.instance_variable_get(:@instrumenter)
        chat.send(:ensure_instrumented_if_needed)
        expect(chat.instance_variable_get(:@instrumenter)).to eq(original_instrumenter)
      end

      it 'does nothing when observability_session_id is nil' do
        chat.update_column(:observability_session_id, nil)
        chat.instance_variable_set(:@instrumenter, nil)
        chat.send(:ensure_instrumented_if_needed)
        expect(chat.instance_variable_get(:@instrumenter)).to be_nil
      end
    end

    context 'when observability is disabled' do
      before do
        allow(Rails.configuration.observability).to receive(:enabled).and_return(false)
      end

      it 'does not attach instrumenter' do
        chat.instance_variable_set(:@instrumenter, nil)
        chat.send(:ensure_instrumented_if_needed)
        expect(chat.instance_variable_get(:@instrumenter)).to be_nil
      end
    end

    context 'when instrumentation fails' do
      before do
        allow(Rails.configuration.observability).to receive(:enabled).and_return(true)
        chat.instance_variable_set(:@instrumenter, nil)
        allow(chat).to receive(:ensure_instrumented!).and_raise(StandardError.new('Instrumentation error'))
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)
        chat.send(:ensure_instrumented_if_needed)
        expect(Rails.logger).to have_received(:error).with(/Failed to auto-instrument on find/)
      end

      it 'does not raise error' do
        expect {
          chat.send(:ensure_instrumented_if_needed)
        }.not_to raise_error
      end
    end
  end
end
