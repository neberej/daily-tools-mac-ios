//
//  FavoriteSubredditsStore.swift
//  Shared
//

import SwiftUI

class FavoriteSubredditsStore: ObservableObject {
    private static let storageKey = "favorite_subreddits"

    @Published var subreddits: [String] {
        didSet {
            save()
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([String].self, from: data) {
            self.subreddits = saved
        } else {
            self.subreddits = AppConfig.Reddit.defaultSubreddits
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(subreddits) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !subreddits.contains(trimmed) else { return }
        subreddits.append(trimmed)
    }

    func remove(at offsets: IndexSet) {
        subreddits.remove(atOffsets: offsets)
    }

    func move(from source: IndexSet, to destination: Int) {
        subreddits.move(fromOffsets: source, toOffset: destination)
    }
}
