import Foundation
import SwiftUI

/// Searchable emoji picker with category filters and broad Unicode coverage.
struct EmojiPickerView: View {
    let onSelect: (String) -> Void

    @State private var searchText: String = ""
    @State private var selectedCategory: EmojiPickerCategory = .smileys

    private static let columns = [GridItem(.adaptive(minimum: 38, maximum: 42), spacing: 8)]
    private static let allEntries: [EmojiEntry] = EmojiCatalog.build()

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool {
        !trimmedSearch.isEmpty
    }

    private var visibleEntries: [EmojiEntry] {
        if isSearching {
            let tokens = trimmedSearch.split(separator: " ").map(String.init)
            return Self.allEntries.filter { entry in
                tokens.allSatisfy { token in
                    entry.emoji.contains(token) || entry.keywords.contains(token)
                }
            }
        }

        if selectedCategory == .all {
            return Self.allEntries
        }
        return Self.allEntries.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchBar
            categoryStrip
            emojiGrid
            footer
        }
        .padding(12)
        #if os(macOS)
        .frame(width: 380, height: 440)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        #endif
        .background(Theme.backgroundSecondary)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textMuted)

            #if os(iOS)
            TextField("Search emoji", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(Theme.text)
            #else
            TextField("Search emoji", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.text)
            #endif

            if !searchText.isEmpty {
                Button {
                    Haptics.play(.light)
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear emoji search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.backgroundTertiary)
        )
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EmojiPickerCategory.displayOrder) { category in
                    Button {
                        Haptics.play(.selection)
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(category.title)
                                .font(Theme.monoXSmall)
                        }
                        .foregroundStyle(selectedCategory == category ? Theme.background : Theme.textDim)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedCategory == category ? Theme.accent : Theme.backgroundTertiary)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private var emojiGrid: some View {
        if visibleEntries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "face.smiling.inverse")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textMuted)
                Text("No emoji match your search")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        } else {
            ScrollView {
                LazyVGrid(columns: Self.columns, spacing: 8) {
                    ForEach(visibleEntries) { entry in
                        Button {
                            Haptics.play(.selection)
                            onSelect(entry.emoji)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.backgroundTertiary.opacity(0.9))
                                Text(entry.emoji)
                                    .font(.system(size: 23))
                            }
                            .frame(height: 38)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.border.opacity(0.65), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("\(visibleEntries.count) shown")
                .font(Theme.monoXSmall)
                .foregroundStyle(Theme.textMuted)

            Spacer()

            Button {
                Haptics.play(.warning)
                onSelect("")
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Remove icon")
                        .font(Theme.monoSmall)
                }
                .foregroundStyle(Theme.textDim)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
}

private struct EmojiEntry: Identifiable, Hashable {
    let emoji: String
    let keywords: String
    let category: EmojiPickerCategory

    var id: String { emoji }
}

private enum EmojiPickerCategory: String, CaseIterable, Identifiable {
    case smileys
    case people
    case animals
    case food
    case travel
    case objects
    case symbols
    case flags
    case all

    static var displayOrder: [EmojiPickerCategory] {
        [.smileys, .people, .animals, .food, .travel, .objects, .symbols, .flags, .all]
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smileys: "Smileys"
        case .people: "People"
        case .animals: "Animals"
        case .food: "Food"
        case .travel: "Travel"
        case .objects: "Objects"
        case .symbols: "Symbols"
        case .flags: "Flags"
        case .all: "All"
        }
    }

    var icon: String {
        switch self {
        case .smileys: "face.smiling"
        case .people: "hand.raised"
        case .animals: "pawprint"
        case .food: "fork.knife"
        case .travel: "airplane"
        case .objects: "wrench.and.screwdriver"
        case .symbols: "sparkles"
        case .flags: "flag"
        case .all: "circle.grid.3x3.fill"
        }
    }

    var sortIndex: Int {
        switch self {
        case .smileys: 0
        case .people: 1
        case .animals: 2
        case .food: 3
        case .travel: 4
        case .objects: 5
        case .symbols: 6
        case .flags: 7
        case .all: 8
        }
    }
}

private enum EmojiCatalog {
    static func build() -> [EmojiEntry] {
        var entriesByEmoji: [String: EmojiEntry] = [:]

        func insert(_ emoji: String, keywords: String, category: EmojiPickerCategory) {
            guard !emoji.isEmpty else { return }
            if entriesByEmoji[emoji] == nil {
                entriesByEmoji[emoji] = EmojiEntry(
                    emoji: emoji,
                    keywords: keywords.lowercased(),
                    category: category
                )
            }
        }

        for scalar in candidateScalars() {
            guard scalar.properties.isEmoji else { continue }
            let name = (scalar.properties.name ?? "").lowercased()
            guard !name.isEmpty, !shouldSkip(scalar, name: name) else { continue }

            let emoji = emojiString(for: scalar)
            let category = inferCategory(from: name)
            insert(emoji, keywords: name, category: category)

            if scalar.properties.isEmojiModifierBase {
                for tone in skinTones {
                    insert(
                        emoji + tone.value,
                        keywords: "\(name) \(tone.keywords)",
                        category: category
                    )
                }
            }
        }

        for region in Locale.Region.isoRegions {
            let code = region.identifier
            if let flag = flagEmoji(for: code) {
                let localized = Locale.current.localizedString(forRegionCode: code)?.lowercased() ?? ""
                insert(flag, keywords: "flag \(code.lowercased()) \(localized)", category: .flags)
            }
        }

        return entriesByEmoji.values.sorted { lhs, rhs in
            if lhs.category.sortIndex != rhs.category.sortIndex {
                return lhs.category.sortIndex < rhs.category.sortIndex
            }
            let lv = lhs.emoji.unicodeScalars.first?.value ?? 0
            let rv = rhs.emoji.unicodeScalars.first?.value ?? 0
            if lv == rv { return lhs.emoji < rhs.emoji }
            return lv < rv
        }
    }

    private static func candidateScalars() -> [UnicodeScalar] {
        let ranges: [ClosedRange<UInt32>] = [
            0x2600...0x27BF,
            0x1F000...0x1FAFF,
        ]
        var scalars: [UnicodeScalar] = []
        for range in ranges {
            for value in range {
                if let scalar = UnicodeScalar(value) {
                    scalars.append(scalar)
                }
            }
        }
        return scalars
    }

    private static func shouldSkip(_ scalar: UnicodeScalar, name: String) -> Bool {
        let value = scalar.value

        if scalar.properties.isEmojiModifier || scalar.properties.isJoinControl {
            return true
        }
        if value == 0xFE0F || value == 0x20E3 || value == 0x200D {
            return true
        }
        if value == 0x0023 || value == 0x002A || (0x0030...0x0039).contains(value) {
            return true
        }
        if (0x1F1E6...0x1F1FF).contains(value) {
            return true
        }

        let blockedNameFragments = [
            "squared",
            "button",
            "input symbol",
            "mahjong tile",
            "domino tile",
            "playing card",
            "copyright sign",
            "registered sign",
            "trade mark sign",
            "double vertical bar",
            "black square",
            "white square",
            "small square",
            "large square",
            "arrow",
            "pause",
            "stop",
            "record",
            "rewind",
            "fast-forward",
        ]
        return blockedNameFragments.contains { name.contains($0) }
    }

    private static func inferCategory(from name: String) -> EmojiPickerCategory {
        if containsAny(name, smileyFragments) { return .smileys }
        if containsAny(name, peopleFragments) { return .people }
        if containsAny(name, animalNatureFragments) { return .animals }
        if containsAny(name, foodFragments) { return .food }
        if containsAny(name, travelFragments) { return .travel }
        if containsAny(name, objectFragments) { return .objects }
        return .symbols
    }

    private static func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0) }
    }

    private static func emojiString(for scalar: UnicodeScalar) -> String {
        let base = String(scalar)
        if scalar.properties.isEmojiPresentation {
            return base
        } else {
            return base + "\u{FE0F}"
        }
    }

    private static let skinTones: [(value: String, keywords: String)] = [
        ("\u{1F3FB}", "light skin tone"),
        ("\u{1F3FC}", "medium-light skin tone"),
        ("\u{1F3FD}", "medium skin tone"),
        ("\u{1F3FE}", "medium-dark skin tone"),
        ("\u{1F3FF}", "dark skin tone"),
    ]

    private static let smileyFragments = [
        "face", "smile", "grin", "laugh", "wink", "frown", "cry", "kiss", "emotion", "heart eyes",
    ]

    private static let peopleFragments = [
        "person", "people", "man", "woman", "boy", "girl", "baby", "family", "hand", "finger", "thumb",
        "palm", "clap", "leg", "foot", "eye", "ear", "nose", "mouth", "brain", "teacher", "doctor",
        "police", "judge", "farmer", "cook", "mechanic", "artist", "pilot", "astronaut", "ninja",
    ]

    private static let animalNatureFragments = [
        "animal", "cat", "dog", "bird", "fish", "monkey", "insect", "bug", "flower", "plant", "tree",
        "leaf", "herb", "mushroom", "sun", "moon", "star", "cloud", "rain", "snow", "fire", "water",
    ]

    private static let foodFragments = [
        "food", "drink", "beverage", "fruit", "vegetable", "bread", "rice", "meat", "cake", "cookie",
        "coffee", "tea", "beer", "wine", "cocktail", "pizza", "burger", "sushi", "ramen", "bento",
        "chopsticks", "fork", "spoon", "knife",
    ]

    private static let travelFragments = [
        "car", "bus", "taxi", "truck", "train", "tram", "metro", "subway", "airplane", "helicopter",
        "rocket", "ship", "boat", "map", "compass", "camping", "tent", "house", "building", "hotel",
        "castle", "stadium", "bridge", "mountain", "beach", "volcano", "city",
    ]

    private static let objectFragments = [
        "book", "notebook", "paper", "pencil", "pen", "folder", "calendar", "clock", "watch", "phone",
        "computer", "laptop", "keyboard", "mouse", "camera", "microphone", "headphone", "light bulb",
        "battery", "money", "credit card", "gem", "key", "lock", "tool", "hammer", "wrench", "gear",
        "scissors", "package", "backpack", "bag", "gift",
    ]

    private static func flagEmoji(for regionCode: String) -> String? {
        let upper = regionCode.uppercased()
        guard upper.count == 2 else { return nil }
        let chars = Array(upper.utf8)
        guard chars.count == 2,
              chars[0] >= 65, chars[0] <= 90,
              chars[1] >= 65, chars[1] <= 90 else {
            return nil
        }

        let base: UInt32 = 0x1F1E6
        let firstValue = base + UInt32(chars[0] - 65)
        let secondValue = base + UInt32(chars[1] - 65)
        guard let first = UnicodeScalar(firstValue),
              let second = UnicodeScalar(secondValue) else {
            return nil
        }
        return String(first) + String(second)
    }
}
