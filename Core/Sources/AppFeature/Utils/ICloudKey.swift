@preconcurrency import Foundation
import Sharing

/// A custom `SharedKey` that reads/writes `NSUbiquitousKeyValueStore` and mirrors
/// values to local `UserDefaults` as a fallback. Subscribes to
/// `NSUbiquitousKeyValueStore.didChangeExternallyNotification` for remote changes.
public struct ICloudKey<Value: Sendable>: SharedKey {
    private let key: String
    nonisolated(unsafe) private let store: NSUbiquitousKeyValueStore
    nonisolated(unsafe) private let defaults: UserDefaults

    public struct ID: Hashable {
        let key: String
    }

    public var id: ID { ID(key: key) }

    init(key: String, store: NSUbiquitousKeyValueStore = .default, defaults: UserDefaults = .standard) {
        self.key = key
        self.store = store
        self.defaults = defaults
    }

    public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        // Try iCloud KVS first, then fall back to local UserDefaults
        if let value = store.object(forKey: key) as? Value {
            continuation.resume(with: .success(value))
        } else if let value = defaults.object(forKey: key) as? Value {
            continuation.resume(with: .success(value))
        } else {
            continuation.resume(with: .success(nil))
        }
    }

    public func save(_ value: Value, context: SaveContext, continuation: SaveContinuation) {
        // Write to both iCloud KVS and local UserDefaults
        store.set(value, forKey: key)
        defaults.set(value, forKey: key)
        continuation.resume()
    }

    public func subscribe(
        context: LoadContext<Value>, subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        let kvsStore = store
        let localDefaults = defaults
        let observedKey = key
        let observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvsStore,
            queue: nil
        ) { notification in
            guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
                  changedKeys.contains(observedKey) else { return }
            if let value = kvsStore.object(forKey: observedKey) as? Value {
                localDefaults.set(value, forKey: observedKey)
                subscriber.yield(with: .success(value))
            }
        }
        let token = UncheckedSendableBox(observer)
        return SharedSubscription {
            NotificationCenter.default.removeObserver(token.value)
        }
    }
}

// MARK: - SharedReaderKey extensions for `.iCloud("key")` syntax

extension SharedReaderKey {
    public static func iCloud(_ key: String) -> Self where Self == ICloudKey<String> {
        ICloudKey(key: key)
    }

    public static func iCloud(_ key: String) -> Self where Self == ICloudKey<Bool> {
        ICloudKey(key: key)
    }

    public static func iCloud(_ key: String) -> Self where Self == ICloudKey<Int> {
        ICloudKey(key: key)
    }

    public static func iCloud(_ key: String) -> Self where Self == ICloudKey<Double> {
        ICloudKey(key: key)
    }
}

// MARK: - RawRepresentable support for enums like SortField

public struct ICloudRawRepresentableKey<Value: RawRepresentable & Sendable>: SharedKey where Value.RawValue: Sendable {
    private let key: String
    nonisolated(unsafe) private let store: NSUbiquitousKeyValueStore
    nonisolated(unsafe) private let defaults: UserDefaults

    public struct ID: Hashable {
        let key: String
    }

    public var id: ID { ID(key: key) }

    init(key: String, store: NSUbiquitousKeyValueStore = .default, defaults: UserDefaults = .standard) {
        self.key = key
        self.store = store
        self.defaults = defaults
    }

    public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        if let raw = store.object(forKey: key) as? Value.RawValue,
           let value = Value(rawValue: raw) {
            continuation.resume(with: .success(value))
        } else if let raw = defaults.object(forKey: key) as? Value.RawValue,
                  let value = Value(rawValue: raw) {
            continuation.resume(with: .success(value))
        } else {
            continuation.resume(with: .success(nil))
        }
    }

    public func save(_ value: Value, context: SaveContext, continuation: SaveContinuation) {
        store.set(value.rawValue, forKey: key)
        defaults.set(value.rawValue, forKey: key)
        continuation.resume()
    }

    public func subscribe(
        context: LoadContext<Value>, subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        let kvsStore = store
        let localDefaults = defaults
        let observedKey = key
        let observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvsStore,
            queue: nil
        ) { notification in
            guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
                  changedKeys.contains(observedKey) else { return }
            if let raw = kvsStore.object(forKey: observedKey) as? Value.RawValue,
               let value = Value(rawValue: raw) {
                localDefaults.set(raw, forKey: observedKey)
                subscriber.yield(with: .success(value))
            }
        }
        let token = UncheckedSendableBox(observer)
        return SharedSubscription {
            NotificationCenter.default.removeObserver(token.value)
        }
    }
}

extension SharedReaderKey {
    public static func iCloud<Value: RawRepresentable<String> & Sendable>(
        _ key: String
    ) -> Self where Self == ICloudRawRepresentableKey<Value> {
        ICloudRawRepresentableKey(key: key)
    }
}

// MARK: - Sendable wrapper for NSObjectProtocol

private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
