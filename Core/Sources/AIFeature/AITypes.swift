import Foundation
import MarkdownStorage

// MARK: - Chat Message

public struct ChatMessage: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let role: Role
    public let content: String
    public let timestamp: Date

    public enum Role: String, Equatable, Sendable {
        case user
        case assistant
        case tool
    }

    public init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Chat Result

public struct ChatResult: Equatable, Sendable {
    public let text: String
    public let createdNoteURLs: [URL]

    public init(text: String, createdNoteURLs: [URL] = []) {
        self.text = text
        self.createdNoteURLs = createdNoteURLs
    }
}

// MARK: - Note Tool Context

public struct NoteToolContext: Equatable, Sendable {
    public let files: [MarkdownFile]
    public let selectedFileURL: URL?
    public let editorContent: String
    public let documentsDirectory: URL

    public init(
        files: [MarkdownFile],
        selectedFileURL: URL?,
        editorContent: String,
        documentsDirectory: URL
    ) {
        self.files = files
        self.selectedFileURL = selectedFileURL
        self.editorContent = editorContent
        self.documentsDirectory = documentsDirectory
    }
}

// MARK: - API Keys

public struct APIKeys: Equatable, Sendable {
    public let openRouter: String
    public let openAI: String
    public let anthropic: String

    public init(openRouter: String, openAI: String, anthropic: String) {
        self.openRouter = openRouter
        self.openAI = openAI
        self.anthropic = anthropic
    }
}

// MARK: - AI Error

public enum AIError: LocalizedError, Equatable {
    case noAPIKey
    case emptyResponse
    case apiError(model: String, status: String, detail: String)
    case providerError(String)

    public var errorDescription: String? {
        switch self {
        case .noAPIKey: "No API key set. Open Settings to add an API key."
        case .emptyResponse: "Received an empty response from the model."
        case let .apiError(model, status, detail): "[\(model)] \(status): \(detail)"
        case let .providerError(message): message
        }
    }
}
