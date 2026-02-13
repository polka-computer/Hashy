import Conduit
import Dependencies
import DependenciesMacros
import Foundation
import MarkdownStorage

// MARK: - AI Client

public struct AIClient: Sendable {
    public var sendMessage: @Sendable (
        _ apiKey: String,
        _ model: String,
        _ messages: [ChatMessage],
        _ noteContext: String?,
        _ toolContext: NoteToolContext,
        _ onToolCall: @Sendable (String) async -> Void
    ) async throws -> ChatResult
}

// MARK: - Live Implementation

extension AIClient: DependencyKey {
    public static let liveValue = AIClient(
        sendMessage: { apiKey, model, messages, noteContext, toolContext, onToolCall in
            guard !apiKey.isEmpty else { throw AIError.noAPIKey }

            let modelShort = model.split(separator: "/").last.map(String.init) ?? model

            // Build system prompt
            let existingTags = Set(toolContext.files.flatMap(\.tags)).sorted()
            let systemText = SystemPromptBuilder.build(
                noteCount: toolContext.files.count,
                existingTags: existingTags,
                currentNoteContext: noteContext
            )

            // Build tools
            let tools: [any Tool] = [
                CreateNoteTool(context: toolContext),
                ReadNoteTool(context: toolContext),
                UpdateNoteMetadataTool(context: toolContext),
                UpdateNoteContentTool(context: toolContext),
                DeleteNoteTool(context: toolContext),
                SearchNotesTool(context: toolContext),
                RenameNoteTool(context: toolContext),
                ListTagsTool(context: toolContext),
                ReadCurrentNoteTool(context: toolContext),
                FullTextSearchTool(context: toolContext),
                ListNotesTool(context: toolContext),
            ]

            // Create provider and executor
            let provider = OpenAIProvider(endpoint: .openRouter, apiKey: apiKey)
            let executor = ToolExecutor(tools: tools)

            // Build API messages
            var apiMessages: [Message] = [.system(systemText)]
            for msg in messages {
                if msg.role == .tool { continue }
                switch msg.role {
                case .user:
                    apiMessages.append(.user(msg.content))
                case .assistant:
                    apiMessages.append(.assistant(msg.content))
                case .tool:
                    break
                }
            }

            await onToolCall("→ \(modelShort) · \(apiMessages.count - 1) messages · \(toolContext.files.count) notes")

            // Config with tools
            let config = GenerateConfig.default.tools(tools)

            // Conversation loop (max 10 rounds for batch operations)
            var createdURLs: [URL] = []
            var maxRounds = 10

            while maxRounds > 0 {
                maxRounds -= 1

                let result = try await provider.generate(
                    messages: apiMessages,
                    model: OpenAIModelID(model),
                    config: config
                )

                // Check for tool calls
                if result.hasToolCalls {
                    // Add assistant message with tool calls
                    apiMessages.append(result.assistantMessage())

                    // Execute each tool call via executor
                    let toolOutputs = try await executor.execute(toolCalls: result.toolCalls)

                    for (index, toolCall) in result.toolCalls.enumerated() {
                        // Track created URLs from create_note calls
                        if toolCall.toolName == "create_note" {
                            let argsJSON = toolCall.arguments.jsonString
                            if let data = argsJSON.data(using: .utf8),
                               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let title = args["title"] as? String {
                                let docsDir = toolContext.documentsDirectory
                                let files = try? FileManager.default.contentsOfDirectory(
                                    at: docsDir,
                                    includingPropertiesForKeys: nil
                                )
                                if let url = files?.sorted(by: {
                                    ($0.lastPathComponent) > ($1.lastPathComponent)
                                }).first(where: { $0.pathExtension == "md" }) {
                                    createdURLs.append(url)
                                }
                            }
                        }

                        // Build summary
                        let summary = buildToolSummary(
                            name: toolCall.toolName,
                            argsJSON: toolCall.arguments.jsonString
                        )
                        await onToolCall(summary)

                        // Add tool result message
                        if index < toolOutputs.count {
                            apiMessages.append(.toolOutput(toolOutputs[index]))
                        }
                    }
                    continue
                }

                // No tool calls — return text
                let text = result.text
                guard !text.isEmpty else { throw AIError.emptyResponse }
                return ChatResult(text: text, createdNoteURLs: createdURLs)
            }

            return ChatResult(text: "Done.", createdNoteURLs: createdURLs)
        }
    )

    public static let testValue = AIClient(
        sendMessage: { _, _, _, _, _, _ in ChatResult(text: "test") }
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
    public var aiClient: AIClient {
        get { self[AIClient.self] }
        set { self[AIClient.self] = newValue }
    }
}

// MARK: - Helpers

private func buildToolSummary(name: String, argsJSON: String) -> String {
    let args: [String: Any]? = {
        guard let data = argsJSON.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }()

    switch name {
    case "create_note":
        let title = args?["title"] as? String ?? "note"
        let icon = args?["icon"] as? String ?? "📝"
        return "\(icon) Created \"\(title)\""
    case "read_note":
        let title = args?["title"] as? String ?? "note"
        return "📖 Read \"\(title)\""
    case "update_note_metadata":
        let title = args?["title"] as? String ?? "note"
        let icon = args?["icon"] as? String ?? "✏️"
        return "\(icon) Updated \"\(title)\""
    case "update_note_content":
        let title = args?["title"] as? String ?? "note"
        return "📝 Updated content of \"\(title)\""
    case "delete_note":
        let title = args?["title"] as? String ?? "note"
        return "🗑 Deleted \"\(title)\""
    case "search_notes":
        return "🔍 Searched notes"
    case "rename_note":
        let newTitle = args?["newTitle"] as? String ?? "note"
        return "✏️ Renamed to \"\(newTitle)\""
    case "list_tags":
        return "🏷 Listed tags"
    case "read_current_note":
        return "📖 Read current note"
    case "full_text_search":
        return "🔍 Full-text search"
    case "list_notes":
        return "📋 Listed notes"
    default:
        return "⚠ \(name)"
    }
}
