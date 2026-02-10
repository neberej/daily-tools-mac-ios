//
//  HNService.swift
//  HackerNews
//

import Foundation

@MainActor
class HNService: ObservableObject {
    @Published var stories: [HNItem] = []
    @Published var isLoading = false
    @Published var currentFeed: HNFeed = .top

    private var allStoryIDs: [Int] = []
    private var loadedCount = 0
    private let batchSize = AppConfig.HackerNews.itemBatchSize
    private let baseURL = AppConfig.HackerNews.baseURL
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    func loadFeed(_ feed: HNFeed) async {
        guard !isLoading else { return }
        let isRefresh = (feed == currentFeed && !stories.isEmpty)
        currentFeed = feed
        isLoading = true

        // Only clear the list when switching feeds, not on pull-to-refresh.
        // This keeps existing stories visible while new data loads.
        if !isRefresh {
            stories = []
        }
        allStoryIDs = []
        loadedCount = 0

        do {
            let ids = try await fetchStoryIDs(feed: feed)
            allStoryIDs = ids
            let firstBatch = Array(ids.prefix(batchSize))
            let items = await fetchItems(ids: firstBatch)
            loadedCount = firstBatch.count
            stories = items
        } catch {
            // On refresh failure, keep existing stories intact.
            // On initial load failure, stories stays empty.
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, loadedCount < allStoryIDs.count else { return }
        isLoading = true

        let nextBatch = Array(allStoryIDs[loadedCount..<min(loadedCount + batchSize, allStoryIDs.count)])
        let items = await fetchItems(ids: nextBatch)
        loadedCount += nextBatch.count
        stories.append(contentsOf: items)

        isLoading = false
    }

    func fetchItem(id: Int) async -> HNItem? {
        guard let url = URL(string: "\(baseURL)/item/\(id).json") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            return try JSONDecoder().decode(HNItem.self, from: data)
        } catch {
            return nil
        }
    }

    /// Fetches a full comment tree recursively for the given IDs.
    func fetchCommentTree(ids: [Int]) async -> [CommentNode] {
        await withTaskGroup(of: (Int, CommentNode?).self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask { [self] in
                    guard let item = await self.fetchItem(id: id) else { return (index, nil) }
                    guard item.deleted != true, item.dead != true else { return (index, nil) }
                    let children = await self.fetchCommentTree(ids: item.kids ?? [])
                    return (index, CommentNode(item: item, children: children))
                }
            }

            var results: [(Int, CommentNode?)] = []
            for await result in group {
                results.append(result)
            }
            return results
                .sorted { $0.0 < $1.0 }
                .compactMap { $0.1 }
        }
    }

    // MARK: - Private

    private func fetchStoryIDs(feed: HNFeed) async throws -> [Int] {
        guard let url = URL(string: "\(baseURL)/\(feed.endpoint).json") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([Int].self, from: data)
    }

    private func fetchItems(ids: [Int]) async -> [HNItem] {
        await withTaskGroup(of: (Int, HNItem?).self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask { [self] in
                    let item = await self.fetchItem(id: id)
                    return (index, item)
                }
            }

            var results: [(Int, HNItem?)] = []
            for await result in group {
                results.append(result)
            }
            return results
                .sorted { $0.0 < $1.0 }
                .compactMap { $0.1 }
                .filter { $0.isStory }
        }
    }
}

// MARK: - Comment Tree Node

struct CommentNode: Identifiable {
    let id: Int
    let item: HNItem
    let children: [CommentNode]

    init(item: HNItem, children: [CommentNode]) {
        self.id = item.id
        self.item = item
        self.children = children
    }
}
