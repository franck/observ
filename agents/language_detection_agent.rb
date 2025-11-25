class LanguageDetectionSchema < RubyLLM::Schema
  string :language_code,
         description: 'ISO 639-1 language code (2 letters, e.g., "en", "fr", "es") or "unknown" if cannot determine',
         required: true

  string :confidence,
         description: 'Confidence level of the detection',
         enum: %w[high medium low],
         required: true

  string :detected_language,
         description: 'Full name of the detected language in English (e.g., "English", "French", "Spanish")',
         required: true
end

class LanguageDetectionAgent < BaseAgent
  include Observ::AgentSelectable
  include Observ::PromptManagement

  # Fallback system prompt
  FALLBACK_LANGUAGE_DETECTION_PROMPT = <<~PROMPT
    You are a language detection specialist. Your task is to identify the language of the text provided by the user.

    <Task>
    Analyze the input text and determine its language.
    Return the ISO 639-1 language code (2 letters), confidence level, and the full language name.
    </Task>

    <Instructions>
    1. Carefully analyze the text to identify the language
    2. Return the two-letter ISO 639-1 code (e.g., "en", "fr", "es", "de", "it", "pt", "nl", "ru", "ja", "zh", "ar", "ko")
    3. If the text contains multiple languages, return the code for the predominant language
    4. If you cannot determine the language with confidence, return "unknown"
    5. Assess your confidence level based on the clarity and amount of text provided:
       - high: Clear indicators, sufficient text, unambiguous
       - medium: Some indicators present, limited text, or mixed language hints
       - low: Very limited text, unclear indicators, or highly ambiguous
    6. Provide the full English name of the detected language
    </Instructions>

    <Examples>
    Input: "Hello, how are you?"
    Output: {"language_code": "en", "confidence": "high", "detected_language": "English"}

    Input: "Bonjour, comment allez-vous?"
    Output: {"language_code": "fr", "confidence": "high", "detected_language": "French"}

    Input: "Hola"
    Output: {"language_code": "es", "confidence": "medium", "detected_language": "Spanish"}

    Input: "xyz"
    Output: {"language_code": "unknown", "confidence": "low", "detected_language": "Unknown"}
    </Examples>
  PROMPT

  # Enable prompt management with fallback
  use_prompt_management(
    prompt_name: 'language-detection-agent-system-prompt',
    fallback: FALLBACK_LANGUAGE_DETECTION_PROMPT
  )

  # Schema for structured output
  def self.schema
    LanguageDetectionSchema
  end

  # Default model for language detection
  def self.default_model
    'gpt-4.1-nano'
  end

  # Display name for UI
  def self.display_name
    'Language Detection'
  end

  # Describe what this agent does
  def self.description
    'Detects the language of input text and returns the ISO 639-1 language code'
  end

  # Category for grouping in UI
  def self.category
    'Utilities'
  end

  # No tools needed for this agent
  def self.tools
    []
  end

  def self.initial_greeting
    <<~GREETING
      # 🌍 Language Detection Agent

      I can identify the language of any text and return its ISO 639-1 code.

      Simply provide me with text, and I'll respond with the language code:
      - **en** for English
      - **fr** for French
      - **es** for Spanish
      - **de** for German
      - And many more...

      What text would you like me to analyze?
    GREETING
  end
end
