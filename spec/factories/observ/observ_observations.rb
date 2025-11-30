FactoryBot.define do
  factory :observ_observation, class: 'Observ::Observation' do
    observation_id { SecureRandom.uuid }
    association :trace, factory: :observ_trace
    start_time { Time.current }
    name { 'test_observation' }
    metadata { {} }
    level { 'DEFAULT' }

    factory :observ_generation, class: 'Observ::Generation' do
      type { 'Observ::Generation' }
      name { 'llm_call' }
      model { 'gpt-4o-mini' }
      model_parameters { { temperature: 0.7 } }
      usage { { input_tokens: 50, output_tokens: 50, total_tokens: 100 } }
      cost_usd { 0.001 }

      trait :finalized do
        end_time { start_time + 1.second }
        output { 'LLM generated response' }
        finish_reason { 'stop' }
      end

      trait :with_metadata do
        provider_metadata do
          {
            request_id: 'req_123',
            model_version: 'gpt-4o-mini-2024-07-18'
          }
        end
      end

      trait :with_cached_tokens do
        usage do
          {
            input_tokens: 50,
            output_tokens: 50,
            total_tokens: 100,
            cached_input_tokens: 25
          }
        end
      end

      trait :with_reasoning_tokens do
        usage do
          {
            input_tokens: 50,
            output_tokens: 50,
            total_tokens: 100,
            reasoning_tokens: 20
          }
        end
      end
    end

    factory :observ_span, class: 'Observ::Span' do
      type { 'Observ::Span' }
      name { 'tool:test_tool' }
      input { { query: 'test' }.to_json }

      trait :finalized do
        end_time { start_time + 0.5.seconds }
        output { { result: 'success' }.to_json }
      end

      trait :error do
        name { 'error' }
        level { 'ERROR' }
        input do
          {
            error_type: 'StandardError',
            error_message: 'Test error'
          }.to_json
        end
      end
    end

    factory :observ_embedding, class: 'Observ::Embedding' do
      type { 'Observ::Embedding' }
      name { 'embedding' }
      model { 'text-embedding-3-small' }
      usage { { input_tokens: 10, total_tokens: 10 } }
      cost_usd { 0.000001 }
      metadata { { batch_size: 1, dimensions: 1536, vectors_count: 1 } }

      trait :finalized do
        end_time { start_time + 0.2.seconds }
        output { { model: 'text-embedding-3-small', dimensions: 1536, vectors_count: 1 }.to_json }
      end

      trait :batch do
        input { [ 'text 1', 'text 2', 'text 3' ].to_json }
        usage { { input_tokens: 30, total_tokens: 30 } }
        metadata { { batch_size: 3, dimensions: 1536, vectors_count: 3 } }
      end
    end

    factory :observ_image_generation, class: 'Observ::ImageGeneration' do
      type { 'Observ::ImageGeneration' }
      name { 'image_generation' }
      model { 'dall-e-3' }
      cost_usd { 0.04 }
      metadata { { size: '1024x1024', output_format: 'url', mime_type: 'image/png' } }

      trait :finalized do
        end_time { start_time + 5.seconds }
        output { { model: 'dall-e-3', has_url: true, mime_type: 'image/png' }.to_json }
      end

      trait :with_revised_prompt do
        metadata do
          {
            size: '1024x1024',
            output_format: 'url',
            mime_type: 'image/png',
            revised_prompt: 'A detailed, photorealistic image of...'
          }
        end
      end

      trait :base64 do
        metadata do
          {
            size: '1024x1024',
            output_format: 'base64',
            mime_type: 'image/png'
          }
        end
      end
    end

    factory :observ_transcription, class: 'Observ::Transcription' do
      type { 'Observ::Transcription' }
      name { 'transcription' }
      model { 'whisper-1' }
      cost_usd { 0.006 }
      metadata do
        {
          audio_duration_s: 60.0,
          language: 'en',
          segments_count: 12,
          has_diarization: false
        }
      end

      trait :finalized do
        end_time { start_time + 3.seconds }
        output { { text: 'Transcribed audio content...', model: 'whisper-1' }.to_json }
      end

      trait :with_diarization do
        model { 'gpt-4o-transcribe' }
        metadata do
          {
            audio_duration_s: 300.0,
            language: 'en',
            segments_count: 45,
            speakers_count: 3,
            has_diarization: true
          }
        end
      end

      trait :long_audio do
        metadata do
          {
            audio_duration_s: 3600.0,
            language: 'en',
            segments_count: 500,
            has_diarization: false
          }
        end
        cost_usd { 0.36 }
      end

      trait :multilingual do
        metadata do
          {
            audio_duration_s: 120.0,
            language: 'es',
            segments_count: 20,
            has_diarization: false
          }
        end
      end
    end
  end
end
