# Audio Transcription Service

This guide demonstrates patterns for building services that use RubyLLM's audio transcription capabilities with full observability.

## Overview

RubyLLM provides audio transcription via `RubyLLM.transcribe()`. Observ can instrument these calls to track:
- Audio duration and cost
- Model used (whisper-1, gpt-4o-transcribe, etc.)
- Language detection
- Speaker diarization metadata
- Segments count

## Pattern 1: Simple Transcription Service

A straightforward service that transcribes audio files with observability.

### Service Implementation

```ruby
# app/services/transcription_service.rb
class TranscriptionService
  include Observ::Concerns::ObservableService

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'transcription',
      metadata: {}
    )
  end

  def transcribe(audio_path, language: nil)
    with_observability do |_session|
      # Instrument transcription for observability
      instrument_transcription(context: {
        service: 'transcription',
        audio_path: audio_path.to_s,
        language: language
      })

      # Perform transcription
      result = RubyLLM.transcribe(audio_path, language: language)

      {
        text: result.text,
        duration: result.duration,
        segments: format_segments(result.segments)
      }
    end
  rescue StandardError => e
    Rails.logger.error "[TranscriptionService] Failed: #{e.message}"
    { text: '', duration: 0, segments: [], error: e.message }
  end

  private

  def format_segments(segments)
    return [] unless segments

    segments.map do |segment|
      {
        start: segment.start,
        end: segment.respond_to?(:end) ? segment.end : nil,
        text: segment.text,
        speaker: segment.respond_to?(:speaker) ? segment.speaker : nil
      }.compact
    end
  end
end
```

### Usage

```ruby
# Basic usage
service = TranscriptionService.new
result = service.transcribe("recording.wav")
puts result[:text]

# With observability session (for tracing)
session = Observ::Session.create!(user_id: "user_123")
service = TranscriptionService.new(observability_session: session)
result = service.transcribe("meeting.mp3", language: "en")
```

## Pattern 2: Transcribe + Summarize (Orchestrated)

A more complex pattern that transcribes audio, then uses an LLM to summarize the content.

### Agent for Summarization

```ruby
# app/agents/meeting_summarizer_agent.rb
class MeetingSummarySchema < RubyLLM::Schema
  string :title, description: 'Meeting title or topic', required: true
  array :key_points, of: :string, description: 'Key discussion points', required: true
  array :action_items, of: :string, description: 'Action items with owners', required: true
  string :summary, description: 'Executive summary (2-3 sentences)', required: true
end

class MeetingSummarizerAgent < BaseAgent
  include Observ::PromptManagement

  FALLBACK_SYSTEM_PROMPT = <<~PROMPT
    You are an expert meeting analyst.

    ## YOUR ROLE
    Analyze meeting transcripts and extract key information.

    ## PRINCIPLES
    1. **Accuracy**: Only include information explicitly stated
    2. **Brevity**: Be concise but complete
    3. **Actionable**: Clearly identify action items and owners

    ## OUTPUT FORMAT
    Provide a structured summary with title, key points, action items, and executive summary.
  PROMPT

  use_prompt_management(
    prompt_name: 'meeting-summarizer-system-prompt',
    fallback: FALLBACK_SYSTEM_PROMPT
  )

  def self.schema
    MeetingSummarySchema
  end

  def self.default_model
    'gpt-4o-mini'
  end

  def self.default_model_parameters
    { temperature: 0.3 }
  end

  def self.build_user_prompt(context)
    <<~PROMPT
      Analyze this meeting transcript and provide a structured summary.

      **Duration**: #{context[:duration_minutes]} minutes
      **Participants**: #{context[:participants]&.join(', ') || 'Unknown'}

      <Transcript>
      #{context[:transcript]}
      </Transcript>

      Extract the meeting title, key discussion points, action items, and provide an executive summary.
    PROMPT
  end
end
```

### Orchestrating Service

```ruby
# app/services/meeting_processor_service.rb
class MeetingProcessorService
  include Observ::Concerns::ObservableService

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'meeting_processor',
      metadata: {}
    )
  end

  def process(audio_path)
    with_observability do |_session|
      # Step 1: Transcribe the audio
      transcript = transcribe_audio(audio_path)
      return error_result("Transcription failed") if transcript[:error]

      # Step 2: Summarize with LLM
      summary = summarize_transcript(transcript)

      build_result(transcript, summary)
    end
  rescue StandardError => e
    Rails.logger.error "[MeetingProcessorService] Failed: #{e.message}"
    error_result(e.message)
  end

  private

  # Step 1: Transcription
  def transcribe_audio(audio_path)
    # Instrument for observability
    instrument_transcription(context: {
      service: 'meeting_processor',
      step: 'transcription'
    })

    result = RubyLLM.transcribe(audio_path)

    {
      text: result.text,
      duration: result.duration,
      speakers: extract_speakers(result),
      segments: result.segments
    }
  rescue StandardError => e
    { error: e.message }
  end

  # Step 2: LLM Summarization
  def summarize_transcript(transcript)
    chat = RubyLLM.chat(model: MeetingSummarizerAgent.model)
    chat.with_instructions(MeetingSummarizerAgent.system_prompt)
    chat.with_schema(MeetingSummarizerAgent.schema)

    model_params = MeetingSummarizerAgent.model_parameters
    chat.with_params(**model_params) if model_params.any?

    # Instrument chat for observability
    instrument_chat(chat, context: {
      service: 'meeting_processor',
      agent_class: MeetingSummarizerAgent,
      step: 'summarization',
      transcript_length: transcript[:text].length
    })

    context = {
      transcript: transcript[:text],
      duration_minutes: (transcript[:duration] / 60.0).round(1),
      participants: transcript[:speakers]
    }

    prompt = MeetingSummarizerAgent.build_user_prompt(context)
    response = chat.ask(prompt)

    symbolize_keys(response.content)
  end

  def extract_speakers(result)
    return [] unless result.segments&.any?
    return [] unless result.segments.first.respond_to?(:speaker)

    result.segments.map(&:speaker).compact.uniq
  end

  def build_result(transcript, summary)
    {
      transcript: {
        text: transcript[:text],
        duration_seconds: transcript[:duration],
        speakers: transcript[:speakers]
      },
      summary: {
        title: summary[:title],
        key_points: summary[:key_points],
        action_items: summary[:action_items],
        executive_summary: summary[:summary]
      },
      metadata: {
        processed_at: Time.current.iso8601
      }
    }
  end

  def error_result(message)
    {
      transcript: { text: '', duration_seconds: 0, speakers: [] },
      summary: { title: '', key_points: [], action_items: [], executive_summary: '' },
      error: message
    }
  end

  def symbolize_keys(hash)
    hash.is_a?(Hash) ? hash.transform_keys(&:to_sym) : hash
  end
end
```

### Usage

```ruby
# Process a meeting recording
service = MeetingProcessorService.new
result = service.process("team-standup.mp3")

puts "Meeting: #{result[:summary][:title]}"
puts "Duration: #{result[:transcript][:duration_seconds] / 60} minutes"
puts "Key Points:"
result[:summary][:key_points].each { |point| puts "  - #{point}" }
```

## Pattern 3: Voice Note Assistant

A service that transcribes voice notes and processes them based on detected intent.

```ruby
# app/agents/voice_note_classifier_agent.rb
class VoiceNoteClassificationSchema < RubyLLM::Schema
  string :intent,
         description: 'Detected intent',
         enum: %w[reminder note task question unknown],
         required: true

  string :extracted_time,
         description: 'Extracted time/date if present (ISO8601)',
         required: false

  array :tags,
        of: :string,
        description: 'Relevant tags for categorization',
        required: false

  string :priority,
         description: 'Priority level',
         enum: %w[low medium high],
         required: false
end

class VoiceNoteClassifierAgent < BaseAgent
  include Observ::PromptManagement

  FALLBACK_SYSTEM_PROMPT = <<~PROMPT
    You are a voice note classifier.

    Analyze the transcribed voice note and determine:
    1. The user's intent (reminder, note, task, question, or unknown)
    2. Any mentioned times or dates
    3. Relevant tags for organization
    4. Priority level if it's a task

    Be accurate and only extract information explicitly stated.
  PROMPT

  use_prompt_management(
    prompt_name: 'voice-note-classifier-system-prompt',
    fallback: FALLBACK_SYSTEM_PROMPT
  )

  def self.schema
    VoiceNoteClassificationSchema
  end

  def self.default_model
    'gpt-4o-mini'
  end

  def self.default_model_parameters
    { temperature: 0.2 }
  end
end

# app/services/voice_note_service.rb
class VoiceNoteService
  include Observ::Concerns::ObservableService

  def initialize(user, observability_session: nil)
    @user = user

    initialize_observability(
      observability_session,
      service_name: 'voice_note',
      metadata: { user_id: user.id }
    )
  end

  def process(audio_path)
    with_observability do |_session|
      # Transcribe
      instrument_transcription(context: { step: 'transcription' })
      transcription = RubyLLM.transcribe(audio_path, language: @user.preferred_language)

      # Classify intent and process
      classification = classify_voice_note(transcription.text)

      case classification[:intent]
      when 'reminder'
        create_reminder(transcription.text, classification)
      when 'note'
        create_note(transcription.text, classification)
      when 'task'
        create_task(transcription.text, classification)
      else
        { type: 'unknown', text: transcription.text }
      end
    end
  end

  private

  def classify_voice_note(text)
    chat = RubyLLM.chat(model: VoiceNoteClassifierAgent.model)
    chat.with_instructions(VoiceNoteClassifierAgent.system_prompt)
    chat.with_schema(VoiceNoteClassifierAgent.schema)

    instrument_chat(chat, context: {
      step: 'classification',
      text_length: text.length
    })

    response = chat.ask(text)
    response.content.transform_keys(&:to_sym)
  end

  def create_reminder(text, classification)
    {
      type: 'reminder',
      text: text,
      due_at: classification[:extracted_time],
      created: true
    }
  end

  def create_note(text, classification)
    {
      type: 'note',
      text: text,
      tags: classification[:tags] || [],
      created: true
    }
  end

  def create_task(text, classification)
    {
      type: 'task',
      text: text,
      priority: classification[:priority] || 'medium',
      created: true
    }
  end
end
```

### Usage

```ruby
user = User.find(123)
service = VoiceNoteService.new(user)
result = service.process("voice-memo.m4a")

case result[:type]
when 'reminder'
  puts "Reminder set for #{result[:due_at]}: #{result[:text]}"
when 'task'
  puts "Task created (#{result[:priority]} priority): #{result[:text]}"
when 'note'
  puts "Note saved with tags #{result[:tags].join(', ')}"
end
```

## Observability Benefits

When using `instrument_transcription`, Observ captures:

| Metric | Description |
|--------|-------------|
| `audio_duration_s` | Length of audio in seconds |
| `cost_usd` | Calculated cost based on model pricing |
| `model` | Transcription model used (whisper-1, etc.) |
| `language` | Detected or specified language |
| `segments_count` | Number of transcript segments |
| `speakers_count` | Number of speakers (if diarization enabled) |
| `has_diarization` | Whether speaker diarization was performed |

### Viewing in Observ Dashboard

All transcription calls appear in the session trace view, showing:
- Audio processing time
- Cost per transcription
- Full transcript text (truncated in UI)
- Relationship to subsequent LLM calls

## Best Practices

### 1. Always Instrument Transcription

```ruby
# Good: Instrument before calling transcribe
instrument_transcription(context: { operation: 'meeting_notes' })
result = RubyLLM.transcribe(audio_path)

# Bad: No observability
result = RubyLLM.transcribe(audio_path)
```

### 2. Include Meaningful Context

```ruby
instrument_transcription(context: {
  service: 'voice_assistant',
  step: 'initial_transcription',
  user_id: user.id,
  audio_source: 'mobile_app'
})
```

### 3. Handle Long Audio Appropriately

For very long recordings, consider logging a warning:

```ruby
def transcribe_long_audio(audio_path)
  # Check duration first if you have metadata
  metadata = extract_audio_metadata(audio_path)

  if metadata[:duration] > 3600 # > 1 hour
    Rails.logger.warn "[TranscriptionService] Long audio: #{metadata[:duration]}s"
  end

  instrument_transcription(context: {
    service: 'transcription',
    expected_duration_s: metadata[:duration],
    is_long_audio: metadata[:duration] > 3600
  })

  RubyLLM.transcribe(audio_path)
end
```

### 4. Chain Transcription with LLM Processing

The most common pattern combines transcription with LLM analysis:

1. **Transcribe** - Convert audio to text
2. **Process** - Use LLM to analyze, summarize, or classify
3. **Act** - Take action based on results

```ruby
with_observability do |session|
  # All operations under one session for unified tracing
  instrument_transcription(context: { step: 'transcribe' })
  transcript = RubyLLM.transcribe(audio)

  instrument_chat(chat, context: { step: 'analyze' })
  analysis = chat.ask("Analyze: #{transcript.text}")
end
```

### 5. Use Speaker Diarization When Needed

For multi-speaker audio like meetings:

```ruby
result = RubyLLM.transcribe(
  audio_path,
  model: 'gpt-4o-transcribe',
  speaker_names: ['Alice', 'Bob', 'Charlie']
)

# Access speaker-attributed segments
result.segments.each do |segment|
  puts "#{segment.speaker}: #{segment.text}"
end
```

## Checklist

When building a transcription service:

- [ ] Include `Observ::Concerns::ObservableService`
- [ ] Call `initialize_observability` in constructor
- [ ] Use `instrument_transcription` before `RubyLLM.transcribe`
- [ ] Include meaningful context (service name, step, metadata)
- [ ] Handle transcription errors gracefully
- [ ] Consider audio duration for long recordings
- [ ] Chain with LLM processing under same session if needed
- [ ] Provide fallback responses on failure
