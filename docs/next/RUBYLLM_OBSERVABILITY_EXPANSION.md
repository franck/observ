# RubyLLM Observability Expansion Plan

This document outlines the plan to extend Observ's observability capabilities to cover additional RubyLLM methods beyond `chat.ask` and `RubyLLM.embed`.

## Current State

Observ currently instruments:

| Method | Observation Type | Status |
|--------|------------------|--------|
| `chat.ask` | `Observ::Generation` | Implemented |
| `RubyLLM.embed` | `Observ::Embedding` | Implemented |
| `RubyLLM.paint` | `Observ::ImageGeneration` | Implemented |
| `RubyLLM.transcribe` | `Observ::Transcription` | Implemented |

## Remaining Methods

| Method | Purpose | Priority |
|--------|---------|----------|
| `RubyLLM.moderate(text)` | Content moderation | Low |

---

## 1. Image Generation: `RubyLLM.paint`

### Overview

Wraps `RubyLLM.paint` to track image generation calls from providers like OpenAI (DALL-E, GPT-Image) and Google (Imagen).

### New Model: `Observ::ImageGeneration`

Subclass of `Observ::Observation`

### Metrics to Track

| Metric | Type | Description |
|--------|------|-------------|
| `model` | String | The image model used (e.g., `gpt-image-1`, `imagen-3.0-generate-002`) |
| `prompt` | Text | The original prompt |
| `revised_prompt` | Text | The model's revised/enhanced prompt (if available) |
| `size` | String | Image dimensions (e.g., `1024x1024`, `1792x1024`) |
| `cost_usd` | Decimal | Generation cost |
| `latency_ms` | Integer | Time to generate in milliseconds |
| `output_format` | String | `url` or `base64` |
| `mime_type` | String | Image MIME type (e.g., `image/png`) |

### RubyLLM API Reference

```ruby
# Basic usage
image = RubyLLM.paint("A sunset over mountains")

# With options
image = RubyLLM.paint(
  "A panoramic mountain landscape",
  model: "gpt-image-1",
  size: "1792x1024"
)

# Response object
image.url            # URL (for OpenAI)
image.data           # Base64 data (for Imagen)
image.base64?        # Boolean
image.mime_type      # "image/png"
image.revised_prompt # Enhanced prompt (if available)
image.model_id       # Model used
```

### Files to Create/Modify

| Action | File |
|--------|------|
| Create | `app/models/observ/image_generation.rb` |
| Create | `app/services/observ/image_generation_instrumenter.rb` |
| Modify | `app/models/observ/observation.rb` - Add type validation |
| Modify | `app/models/observ/trace.rb` - Add `create_image_generation`, `image_generations` scope |
| Modify | `app/models/observ/session.rb` - Add `instrument_image_generation` |
| Modify | `app/services/observ/concerns/observable_service.rb` - Add helper |
| Modify | `spec/factories/observ/observ_observations.rb` - Add factory |
| Create | `spec/models/observ/image_generation_spec.rb` |
| Create | `spec/services/observ/image_generation_instrumenter_spec.rb` |
| Modify | `README.md` - Add documentation |

### Model Implementation

```ruby
# app/models/observ/image_generation.rb
module Observ
  class ImageGeneration < Observation
    def finalize(output:, usage: {}, cost_usd: 0.0, status_message: nil)
      update!(
        output: output.is_a?(String) ? output : output.to_json,
        usage: (self.usage || {}).merge(usage.stringify_keys),
        cost_usd: cost_usd,
        end_time: Time.current,
        status_message: status_message
      )
    end

    # Image-specific helpers
    def size
      metadata&.dig("size")
    end

    def revised_prompt
      metadata&.dig("revised_prompt")
    end

    def output_format
      metadata&.dig("output_format") # "url" or "base64"
    end

    def mime_type
      metadata&.dig("mime_type")
    end
  end
end
```

### Usage Example

```ruby
session = Observ::Session.create!(user_id: "image_service")
session.instrument_image_generation(context: { operation: "product_image" })

# All RubyLLM.paint calls are now tracked
image = RubyLLM.paint("A modern logo for a tech startup")

session.finalize
```

---

## 2. Audio Transcription: `RubyLLM.transcribe`

### Overview

Wraps `RubyLLM.transcribe` to track audio-to-text transcription calls from providers like OpenAI (Whisper) and Google (Gemini).

### New Model: `Observ::Transcription`

Subclass of `Observ::Observation`

### Metrics to Track

| Metric | Type | Description |
|--------|------|-------------|
| `model` | String | The transcription model (e.g., `whisper-1`, `gpt-4o-transcribe`) |
| `audio_duration_s` | Decimal | Length of audio in seconds |
| `language` | String | Detected or specified language (ISO 639-1) |
| `segments_count` | Integer | Number of transcript segments |
| `speakers_count` | Integer | Number of speakers (for diarization) |
| `cost_usd` | Decimal | Transcription cost |
| `latency_ms` | Integer | Processing time in milliseconds |
| `has_diarization` | Boolean | Whether speaker diarization was used |

### RubyLLM API Reference

```ruby
# Basic transcription
transcription = RubyLLM.transcribe("meeting.wav")

# With options
transcription = RubyLLM.transcribe(
  "interview.mp3",
  model: "gpt-4o-transcribe",
  language: "es"
)

# With diarization
transcription = RubyLLM.transcribe(
  "team-meeting.wav",
  model: "gpt-4o-transcribe-diarize",
  speaker_names: ["Alice", "Bob"],
  speaker_references: ["alice-voice.wav", "bob-voice.wav"]
)

# Response object
transcription.text      # Full transcript text
transcription.model     # Model used
transcription.duration  # Audio duration in seconds
transcription.segments  # Array of segments with timestamps
```

### Files to Create/Modify

| Action | File |
|--------|------|
| Create | `app/models/observ/transcription.rb` |
| Create | `app/services/observ/transcription_instrumenter.rb` |
| Modify | `app/models/observ/observation.rb` - Add type validation |
| Modify | `app/models/observ/trace.rb` - Add `create_transcription`, `transcriptions` scope |
| Modify | `app/models/observ/session.rb` - Add `instrument_transcription` |
| Modify | `app/services/observ/concerns/observable_service.rb` - Add helper |
| Modify | `spec/factories/observ/observ_observations.rb` - Add factory |
| Create | `spec/models/observ/transcription_spec.rb` |
| Create | `spec/services/observ/transcription_instrumenter_spec.rb` |
| Modify | `README.md` - Add documentation |

### Model Implementation

```ruby
# app/models/observ/transcription.rb
module Observ
  class Transcription < Observation
    def finalize(output:, usage: {}, cost_usd: 0.0, status_message: nil)
      update!(
        output: output.is_a?(String) ? output : output.to_json,
        usage: (self.usage || {}).merge(usage.stringify_keys),
        cost_usd: cost_usd,
        end_time: Time.current,
        status_message: status_message
      )
    end

    # Transcription-specific helpers
    def audio_duration_s
      metadata&.dig("audio_duration_s")
    end

    def language
      metadata&.dig("language")
    end

    def segments_count
      metadata&.dig("segments_count") || 0
    end

    def speakers_count
      metadata&.dig("speakers_count")
    end

    def has_diarization?
      metadata&.dig("has_diarization") || false
    end
  end
end
```

### Usage Example

```ruby
session = Observ::Session.create!(user_id: "transcription_service")
session.instrument_transcription(context: { operation: "meeting_notes" })

# All RubyLLM.transcribe calls are now tracked
transcript = RubyLLM.transcribe("meeting.wav", language: "en")

session.finalize
```

---

## 3. Content Moderation: `RubyLLM.moderate`

### Overview

Wraps `RubyLLM.moderate` to track content moderation calls for safety filtering.

### New Model: `Observ::Moderation`

Subclass of `Observ::Observation`

### Metrics to Track

| Metric | Type | Description |
|--------|------|-------------|
| `model` | String | The moderation model (e.g., `omni-moderation-latest`) |
| `flagged` | Boolean | Whether content was flagged |
| `categories` | JSON | Hash of category boolean flags |
| `category_scores` | JSON | Hash of category confidence scores (0.0-1.0) |
| `flagged_categories` | Array | List of categories that triggered flagging |
| `latency_ms` | Integer | Processing time in milliseconds |

### RubyLLM API Reference

```ruby
# Basic moderation
result = RubyLLM.moderate("Some user input text")

# Response object
result.flagged?           # Boolean
result.categories         # Hash of category => boolean
result.category_scores    # Hash of category => float (0.0-1.0)
result.flagged_categories # Array of flagged category names
result.model              # Model used
result.id                 # Moderation ID
```

### Moderation Categories

- `sexual` - Sexually explicit content
- `hate` - Hate speech based on identity
- `harassment` - Harassing or threatening content
- `self-harm` - Self-harm promotion
- `sexual/minors` - Sexual content involving minors
- `hate/threatening` - Hateful content with threats
- `violence` - Violence promotion
- `violence/graphic` - Graphic violent content
- `self-harm/intent` - Intent to self-harm
- `self-harm/instructions` - Self-harm instructions
- `harassment/threatening` - Threatening harassment

### Files to Create/Modify

| Action | File |
|--------|------|
| Create | `app/models/observ/moderation.rb` |
| Create | `app/services/observ/moderation_instrumenter.rb` |
| Modify | `app/models/observ/observation.rb` - Add type validation |
| Modify | `app/models/observ/trace.rb` - Add `create_moderation`, `moderations` scope |
| Modify | `app/models/observ/session.rb` - Add `instrument_moderation` |
| Modify | `app/services/observ/concerns/observable_service.rb` - Add helper |
| Modify | `spec/factories/observ/observ_observations.rb` - Add factory |
| Create | `spec/models/observ/moderation_spec.rb` |
| Create | `spec/services/observ/moderation_instrumenter_spec.rb` |
| Modify | `README.md` - Add documentation |

### Model Implementation

```ruby
# app/models/observ/moderation.rb
module Observ
  class Moderation < Observation
    def finalize(output:, usage: {}, cost_usd: 0.0, status_message: nil)
      update!(
        output: output.is_a?(String) ? output : output.to_json,
        usage: (self.usage || {}).merge(usage.stringify_keys),
        cost_usd: cost_usd,
        end_time: Time.current,
        status_message: status_message
      )
    end

    # Moderation-specific helpers
    def flagged?
      metadata&.dig("flagged") || false
    end

    def categories
      metadata&.dig("categories") || {}
    end

    def category_scores
      metadata&.dig("category_scores") || {}
    end

    def flagged_categories
      metadata&.dig("flagged_categories") || []
    end

    def highest_score_category
      return nil if category_scores.empty?
      category_scores.max_by { |_, score| score }&.first
    end
  end
end
```

### Usage Example

```ruby
session = Observ::Session.create!(user_id: "content_filter")
session.instrument_moderation(context: { operation: "user_input_check" })

# All RubyLLM.moderate calls are now tracked
result = RubyLLM.moderate(user_input)

if result.flagged?
  # Handle flagged content
end

session.finalize
```

---

## Implementation Order

1. **Image Generation** (`RubyLLM.paint`)
   - Common use case for product images, marketing, etc.
   - Straightforward API similar to embeddings
   - Estimated effort: 2-3 hours

2. **Transcription** (`RubyLLM.transcribe`)
   - More complex with diarization support
   - Useful for meeting notes, podcast processing
   - Estimated effort: 3-4 hours

3. **Moderation** (`RubyLLM.moderate`)
   - Simpler API but specialized use case
   - Important for content safety workflows
   - Estimated effort: 2 hours

---

## Architecture Notes

### Why Separate Observation Types?

Instead of a generic `Observ::ApiCall` type, we use specialized subclasses because:

1. **Type-safe accessors** - Each type has domain-specific methods (e.g., `transcription.duration`, `image.size`)
2. **Cleaner scopes** - `trace.transcriptions`, `trace.image_generations` vs generic filtering
3. **Better documentation** - Clear what each observation type represents
4. **Validation rules** - Each type can have specific validations
5. **Dashboard views** - Can show type-specific metrics and visualizations

### STI Implementation

All observation types use Single Table Inheritance (STI):

```ruby
# app/models/observ/observation.rb
validates :type, presence: true, inclusion: { 
  in: %w[
    Observ::Generation 
    Observ::Span 
    Observ::Embedding
    Observ::ImageGeneration
    Observ::Transcription
    Observ::Moderation
  ] 
}
```

### Cost Aggregation

Each new observation type should be included in cost aggregation:

```ruby
# app/models/observ/trace.rb
def update_aggregated_metrics
  new_total_cost = [
    generations.sum(:cost_usd),
    embeddings.sum(:cost_usd),
    image_generations.sum(:cost_usd),
    transcriptions.sum(:cost_usd),
    moderations.sum(:cost_usd)
  ].compact.sum

  # ... rest of implementation
end
```

---

## Testing Strategy

Each new observation type should have:

1. **Model spec** - Test all helper methods and finalize behavior
2. **Instrumenter spec** - Test wrapping, tracking, error handling
3. **Factory** - With relevant traits (e.g., `:finalized`, `:flagged`)
4. **Integration tests** - Verify cost aggregation and trace scopes

---

## Future Considerations

### Multi-modal Instrumentation

As RubyLLM evolves to support more multi-modal operations (e.g., image input to chat), consider:

- Tracking attachment types in generations
- Linking related observations (e.g., transcription -> chat)
- Composite traces for multi-step workflows

### Dashboard Enhancements

With new observation types, the dashboard could show:

- Cost breakdown by observation type
- Usage trends per API category
- Model comparison across types
- Latency percentiles by operation
