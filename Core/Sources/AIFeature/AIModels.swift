import Foundation

// MARK: - Supported Model Catalogs
//
// Single source of truth for provider model lists and routing.
// Update these when providers release new models.

public enum AIModels {

    // MARK: - OpenRouter (catch-all, uses provider/model format)

    public static let openRouter: [String] = [
        "anthropic/claude-sonnet-4.5",
        "anthropic/claude-opus-4.5",
        "google/gemini-3-flash-preview",
        "google/gemini-2.5-flash",
        "google/gemini-2.5-flash-lite",
        "deepseek/deepseek-v3.2",
        "moonshotai/kimi-k2.5",
        "minimax/minimax-m2.1",
        "x-ai/grok-4.1-fast",
        "z-ai/glm-5",
    ]

    // MARK: - OpenAI (direct API)

    public static let openAI: [String] = [
        "gpt-5.2", "gpt-5.1", "gpt-5-mini", "gpt-5-nano", "gpt-4.1",
    ]

    // MARK: - Anthropic (direct API)

    public static let anthropic: [String] = [
        "claude-opus-4-6", "claude-sonnet-4-5-20250929",
        "claude-haiku-4-5-20251001", "claude-sonnet-4-20250514",
    ]

    // MARK: - Routing Sets

    /// Model IDs that should route to the Anthropic provider.
    /// Includes aliases so custom model entries still route correctly.
    public static let anthropicRouting: Set<String> = {
        var set = Set(anthropic)
        // Common aliases
        set.insert("claude-sonnet-4-5")
        set.insert("claude-haiku-4-5")
        return set
    }()

    /// Model IDs that should route to the OpenAI provider.
    public static let openAIRouting: Set<String> = Set(openAI)
}
