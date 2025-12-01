# Image Generation Service

This guide demonstrates patterns for building services that use RubyLLM's image generation capabilities with full observability.

## Overview

RubyLLM provides image generation via `RubyLLM.paint()`. Observ can instrument these calls to track:
- Model used (dall-e-3, imagen-3.0, etc.)
- Cost per image
- Image size and format
- Revised prompts (when the model enhances your prompt)
- Output format (URL or base64)

## Pattern 1: Simple Image Generation Service

A straightforward service that generates images with observability.

### Service Implementation

```ruby
# app/services/image_generation_service.rb
class ImageGenerationService
  include Observ::Concerns::ObservableService

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'image_generation',
      metadata: {}
    )
  end

  def generate(prompt, size: '1024x1024', model: 'dall-e-3')
    with_observability do |_session|
      # Instrument image generation for observability
      instrument_image_generation(context: {
        service: 'image_generation',
        prompt_length: prompt.length,
        requested_size: size
      })

      # Generate the image
      result = RubyLLM.paint(prompt, model: model, size: size)

      {
        url: result.url,
        base64: result.base64? ? result.data : nil,
        revised_prompt: result.revised_prompt,
        mime_type: result.mime_type,
        model: result.model_id
      }
    end
  rescue StandardError => e
    Rails.logger.error "[ImageGenerationService] Failed: #{e.message}"
    { error: e.message }
  end
end
```

### Usage

```ruby
# Basic usage
service = ImageGenerationService.new
result = service.generate("A serene mountain landscape at sunset")
puts result[:url]

# With observability session (for tracing)
session = Observ::Session.create!(user_id: "user_123")
service = ImageGenerationService.new(observability_session: session)
result = service.generate(
  "A modern minimalist logo for a tech startup",
  size: '1792x1024',
  model: 'dall-e-3'
)
```

## Pattern 2: Product Image Generator

A service that generates product images with an agent for prompt enhancement.

### Agent for Prompt Enhancement

```ruby
# app/agents/product_image_prompt_agent.rb
class ProductImagePromptSchema < RubyLLM::Schema
  string :enhanced_prompt,
         description: 'Enhanced prompt optimized for image generation',
         required: true

  string :style_keywords,
         description: 'Comma-separated style keywords applied',
         required: true

  string :composition_notes,
         description: 'Notes about the suggested composition',
         required: false
end

class ProductImagePromptAgent < BaseAgent
  include Observ::PromptManagement

  FALLBACK_SYSTEM_PROMPT = <<~PROMPT
    You are an expert at crafting prompts for product photography.

    ## YOUR ROLE
    Transform basic product descriptions into detailed prompts that will
    generate professional, e-commerce quality product images.

    ## PRINCIPLES
    1. **Commercial Quality**: Focus on clean, professional aesthetics
    2. **Lighting**: Specify appropriate lighting (studio, natural, dramatic)
    3. **Background**: Suggest appropriate backgrounds (white, gradient, lifestyle)
    4. **Composition**: Consider angles and focal points
    5. **Style Consistency**: Maintain brand-appropriate styling

    ## OUTPUT
    Provide an enhanced prompt optimized for DALL-E or similar models.
  PROMPT

  use_prompt_management(
    prompt_name: 'product-image-prompt-agent-system-prompt',
    fallback: FALLBACK_SYSTEM_PROMPT
  )

  def self.schema
    ProductImagePromptSchema
  end

  def self.default_model
    'gpt-4o-mini'
  end

  def self.default_model_parameters
    { temperature: 0.7 }
  end

  def self.build_user_prompt(context)
    <<~PROMPT
      Create an optimized image generation prompt for this product:

      **Product**: #{context[:product_name]}
      **Description**: #{context[:description]}
      **Category**: #{context[:category]}
      **Style Preference**: #{context[:style] || 'professional, clean'}
      **Background**: #{context[:background] || 'white studio'}

      Generate a detailed prompt that will produce a high-quality product image.
    PROMPT
  end
end
```

### Orchestrating Service

```ruby
# app/services/product_image_service.rb
class ProductImageService
  include Observ::Concerns::ObservableService

  SIZES = {
    thumbnail: '256x256',
    standard: '1024x1024',
    wide: '1792x1024',
    tall: '1024x1792'
  }.freeze

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'product_image',
      metadata: {}
    )
  end

  def generate(product, size: :standard, style: nil)
    with_observability do |_session|
      # Step 1: Enhance the prompt with LLM
      enhanced = enhance_prompt(product, style)

      # Step 2: Generate the image
      image = generate_image(enhanced[:enhanced_prompt], size)

      build_result(product, enhanced, image)
    end
  rescue StandardError => e
    Rails.logger.error "[ProductImageService] Failed: #{e.message}"
    error_result(e.message)
  end

  private

  # Step 1: LLM prompt enhancement
  def enhance_prompt(product, style)
    chat = RubyLLM.chat(model: ProductImagePromptAgent.model)
    chat.with_instructions(ProductImagePromptAgent.system_prompt)
    chat.with_schema(ProductImagePromptAgent.schema)

    model_params = ProductImagePromptAgent.model_parameters
    chat.with_params(**model_params) if model_params.any?

    # Instrument chat for observability
    instrument_chat(chat, context: {
      service: 'product_image',
      agent_class: ProductImagePromptAgent,
      step: 'prompt_enhancement',
      product_id: product.id
    })

    context = {
      product_name: product.name,
      description: product.description,
      category: product.category,
      style: style
    }

    prompt = ProductImagePromptAgent.build_user_prompt(context)
    response = chat.ask(prompt)

    symbolize_keys(response.content)
  end

  # Step 2: Image generation
  def generate_image(prompt, size)
    image_size = SIZES[size] || SIZES[:standard]

    # Instrument for observability
    instrument_image_generation(context: {
      service: 'product_image',
      step: 'generation',
      size: image_size
    })

    result = RubyLLM.paint(prompt, size: image_size)

    {
      url: result.url,
      data: result.base64? ? result.data : nil,
      revised_prompt: result.revised_prompt,
      mime_type: result.mime_type
    }
  end

  def build_result(product, enhanced, image)
    {
      product_id: product.id,
      original_description: product.description,
      enhanced_prompt: enhanced[:enhanced_prompt],
      style_keywords: enhanced[:style_keywords],
      image: {
        url: image[:url],
        base64: image[:data],
        revised_prompt: image[:revised_prompt],
        mime_type: image[:mime_type]
      },
      metadata: {
        generated_at: Time.current.iso8601
      }
    }
  end

  def error_result(message)
    {
      product_id: nil,
      image: { url: nil, base64: nil },
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
product = Product.find(123)
service = ProductImageService.new
result = service.generate(product, size: :wide, style: 'luxury minimalist')

puts "Enhanced prompt: #{result[:enhanced_prompt]}"
puts "Image URL: #{result[:image][:url]}"
```

## Pattern 3: Content Illustration Service

A service that analyzes text content and generates relevant illustrations.

```ruby
# app/agents/illustration_concept_agent.rb
class IllustrationConceptSchema < RubyLLM::Schema
  string :concept,
         description: 'Main visual concept to illustrate',
         required: true

  string :style,
         description: 'Recommended artistic style',
         enum: %w[realistic cartoon minimalist abstract watercolor sketch],
         required: true

  string :mood,
         description: 'Emotional mood of the illustration',
         required: true

  string :image_prompt,
         description: 'Complete prompt for image generation',
         required: true

  array :key_elements,
        of: :string,
        description: 'Key visual elements to include',
        required: true
end

class IllustrationConceptAgent < BaseAgent
  include Observ::PromptManagement

  FALLBACK_SYSTEM_PROMPT = <<~PROMPT
    You are a creative director specializing in editorial illustration.

    ## YOUR ROLE
    Analyze text content and create compelling visual concepts for illustrations.

    ## PRINCIPLES
    1. **Relevance**: The illustration must enhance the content's message
    2. **Visual Impact**: Create striking, memorable imagery
    3. **Clarity**: The concept should be immediately understandable
    4. **Style Match**: Choose styles appropriate for the content tone

    ## OUTPUT
    Provide a complete concept including style, mood, and a detailed image prompt.
  PROMPT

  use_prompt_management(
    prompt_name: 'illustration-concept-agent-system-prompt',
    fallback: FALLBACK_SYSTEM_PROMPT
  )

  def self.schema
    IllustrationConceptSchema
  end

  def self.default_model
    'gpt-4o-mini'
  end

  def self.default_model_parameters
    { temperature: 0.8 }
  end
end

# app/services/content_illustration_service.rb
class ContentIllustrationService
  include Observ::Concerns::ObservableService

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'content_illustration',
      metadata: {}
    )
  end

  def illustrate(content, content_type: 'article')
    with_observability do |_session|
      # Step 1: Analyze content and create concept
      concept = create_illustration_concept(content, content_type)

      # Step 2: Generate the illustration
      illustration = generate_illustration(concept)

      {
        concept: {
          main_idea: concept[:concept],
          style: concept[:style],
          mood: concept[:mood],
          elements: concept[:key_elements]
        },
        illustration: illustration,
        metadata: {
          content_type: content_type,
          generated_at: Time.current.iso8601
        }
      }
    end
  rescue StandardError => e
    Rails.logger.error "[ContentIllustrationService] Failed: #{e.message}"
    { error: e.message }
  end

  private

  def create_illustration_concept(content, content_type)
    chat = RubyLLM.chat(model: IllustrationConceptAgent.model)
    chat.with_instructions(IllustrationConceptAgent.system_prompt)
    chat.with_schema(IllustrationConceptAgent.schema)

    instrument_chat(chat, context: {
      service: 'content_illustration',
      step: 'concept_creation',
      content_type: content_type,
      content_length: content.length
    })

    prompt = <<~PROMPT
      Create an illustration concept for this #{content_type}:

      <Content>
      #{content.truncate(2000)}
      </Content>

      Design a compelling visual that captures the essence of this content.
    PROMPT

    response = chat.ask(prompt)
    response.content.transform_keys(&:to_sym)
  end

  def generate_illustration(concept)
    instrument_image_generation(context: {
      service: 'content_illustration',
      step: 'generation',
      style: concept[:style],
      mood: concept[:mood]
    })

    result = RubyLLM.paint(concept[:image_prompt], size: '1792x1024')

    {
      url: result.url,
      base64: result.base64? ? result.data : nil,
      prompt_used: concept[:image_prompt],
      revised_prompt: result.revised_prompt
    }
  end
end
```

### Usage

```ruby
article_content = <<~ARTICLE
  The Future of Remote Work: How AI is Reshaping the Modern Office

  As companies worldwide adapt to hybrid work models, artificial intelligence
  is playing an increasingly central role in how teams collaborate...
ARTICLE

service = ContentIllustrationService.new
result = service.illustrate(article_content, content_type: 'article')

puts "Concept: #{result[:concept][:main_idea]}"
puts "Style: #{result[:concept][:style]}"
puts "Illustration URL: #{result[:illustration][:url]}"
```

## Pattern 4: Avatar Generation Service

A service for generating user avatars with different styles.

```ruby
# app/services/avatar_generation_service.rb
class AvatarGenerationService
  include Observ::Concerns::ObservableService

  STYLES = {
    professional: 'professional headshot, corporate style, neutral background, high quality',
    artistic: 'artistic portrait, vibrant colors, creative style, painterly',
    cartoon: 'cartoon avatar, friendly, colorful, simple background',
    gaming: 'gaming avatar, dynamic pose, fantasy elements, dramatic lighting',
    minimalist: 'minimalist portrait, simple lines, limited color palette, clean design'
  }.freeze

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'avatar_generation',
      metadata: {}
    )
  end

  def generate(description, style: :professional)
    with_observability do |_session|
      style_modifier = STYLES[style] || STYLES[:professional]
      prompt = build_avatar_prompt(description, style_modifier)

      instrument_image_generation(context: {
        service: 'avatar_generation',
        style: style.to_s,
        description_length: description.length
      })

      result = RubyLLM.paint(prompt, size: '1024x1024')

      {
        url: result.url,
        base64: result.base64? ? result.data : nil,
        style: style,
        prompt_used: prompt,
        revised_prompt: result.revised_prompt,
        generated_at: Time.current.iso8601
      }
    end
  rescue StandardError => e
    Rails.logger.error "[AvatarGenerationService] Failed: #{e.message}"
    { error: e.message }
  end

  # Generate multiple style variants
  def generate_variants(description, styles: [:professional, :artistic, :cartoon])
    with_observability do |_session|
      styles.map do |style|
        {
          style: style,
          result: generate_single_variant(description, style)
        }
      end
    end
  end

  private

  def build_avatar_prompt(description, style_modifier)
    "Portrait avatar: #{description}. Style: #{style_modifier}. " \
      "Square format, centered composition, suitable for profile picture."
  end

  def generate_single_variant(description, style)
    style_modifier = STYLES[style] || STYLES[:professional]
    prompt = build_avatar_prompt(description, style_modifier)

    instrument_image_generation(context: {
      service: 'avatar_generation',
      step: 'variant',
      style: style.to_s
    })

    result = RubyLLM.paint(prompt, size: '1024x1024')

    {
      url: result.url,
      base64: result.base64? ? result.data : nil,
      revised_prompt: result.revised_prompt
    }
  rescue StandardError => e
    { error: e.message }
  end
end
```

### Usage

```ruby
service = AvatarGenerationService.new

# Single avatar
result = service.generate(
  "A friendly person with glasses and short brown hair",
  style: :professional
)
puts result[:url]

# Multiple variants
variants = service.generate_variants(
  "A creative designer with colorful accessories",
  styles: [:professional, :artistic, :cartoon]
)

variants.each do |variant|
  puts "#{variant[:style]}: #{variant[:result][:url]}"
end
```

## Observability Benefits

When using `instrument_image_generation`, Observ captures:

| Metric | Description |
|--------|-------------|
| `model` | Image model used (dall-e-3, imagen-3.0, etc.) |
| `cost_usd` | Cost per image generation |
| `size` | Requested image dimensions |
| `revised_prompt` | Model's enhanced version of your prompt |
| `output_format` | Whether result is URL or base64 |
| `mime_type` | Image format (image/png, image/jpeg, etc.) |

### Viewing in Observ Dashboard

All image generation calls appear in the session trace view, showing:
- Generation time
- Cost per image
- Original vs revised prompts
- Relationship to preceding LLM calls (if prompt was enhanced)

## Best Practices

### 1. Always Instrument Image Generation

```ruby
# Good: Instrument before calling paint
instrument_image_generation(context: { operation: 'product_photo' })
result = RubyLLM.paint(prompt)

# Bad: No observability
result = RubyLLM.paint(prompt)
```

### 2. Include Meaningful Context

```ruby
instrument_image_generation(context: {
  service: 'product_catalog',
  step: 'hero_image',
  product_id: product.id,
  style: 'lifestyle',
  requested_size: '1792x1024'
})
```

### 3. Use LLM for Prompt Enhancement

Raw user prompts often produce mediocre results. Use an LLM to enhance prompts:

```ruby
with_observability do |session|
  # Step 1: Enhance prompt with LLM
  instrument_chat(chat, context: { step: 'prompt_enhancement' })
  enhanced = chat.ask("Enhance this image prompt: #{user_prompt}")

  # Step 2: Generate with enhanced prompt
  instrument_image_generation(context: { step: 'generation' })
  image = RubyLLM.paint(enhanced.content)
end
```

### 4. Handle Different Output Formats

```ruby
result = RubyLLM.paint(prompt)

if result.base64?
  # Save base64 data directly
  decoded = Base64.decode64(result.data)
  File.binwrite("image.png", decoded)
else
  # Download from URL
  image_data = URI.open(result.url).read
  File.binwrite("image.png", image_data)
end
```

### 5. Track Revised Prompts

DALL-E 3 often revises your prompt. Track this for quality improvement:

```ruby
result = RubyLLM.paint(original_prompt)

if result.revised_prompt != original_prompt
  Rails.logger.info "Prompt was revised:"
  Rails.logger.info "  Original: #{original_prompt}"
  Rails.logger.info "  Revised: #{result.revised_prompt}"
end
```

### 6. Use Appropriate Sizes

Choose sizes based on use case:

```ruby
SIZES = {
  thumbnail: '256x256',      # Previews, icons
  square: '1024x1024',       # Social media, avatars
  landscape: '1792x1024',    # Hero images, banners
  portrait: '1024x1792'      # Mobile, stories
}
```

## Checklist

When building an image generation service:

- [ ] Include `Observ::Concerns::ObservableService`
- [ ] Call `initialize_observability` in constructor
- [ ] Use `instrument_image_generation` before `RubyLLM.paint`
- [ ] Include meaningful context (service name, step, metadata)
- [ ] Consider using LLM for prompt enhancement
- [ ] Handle both URL and base64 output formats
- [ ] Track revised prompts for quality insights
- [ ] Choose appropriate image sizes for use case
- [ ] Provide fallback responses on failure
- [ ] Log errors with sufficient context
