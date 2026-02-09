//
//  ToDoStore.swift
//  ToDo
//
//  Persists ToDoItem in SQLite via Shared/Database. Uses Application Support/ToDo/data.sqlite.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.mactools.ToDo", category: "store")

final class ToDoStore {
    private let database: Database?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let key = "com.mactools.todo.items" // fallback UserDefaults key if DB fails

    private static let tableName = "todo_items"

    init(appName: String = "ToDo") {
        var db: Database?
        do {
            let url = try FileManager.default.appSupportURL(appName: appName)
                .appendingPathComponent("data.sqlite")
            db = try Database.open(at: url)
            try Self.createTableIfNeeded(db!)
        } catch {
            db = nil
        }
        self.database = db
    }

    private static func createTableIfNeeded(_ db: Database) throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS \(Self.tableName) (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                is_completed INTEGER NOT NULL DEFAULT 0,
                date REAL NOT NULL
            )
            """)
    }

    func load() -> [ToDoItem] {
        guard let db = database else {
            return UserDefaults.standard.data(forKey: key)
                .flatMap { try? decoder.decode([ToDoItem].self, from: $0) } ?? []
        }
        do {
            let rows = try db.fetch("SELECT id, title, is_completed, date FROM \(Self.tableName) ORDER BY date")
            return rows.compactMap { row -> ToDoItem? in
                guard let id = row.uuid("id"),
                      let title = row.text("title"),
                      let isCompleted = row.bool("is_completed"),
                      let date = row.date("date") else { return nil }
                return ToDoItem(id: id, title: title, isCompleted: isCompleted, date: date)
            }
        } catch {
            return []
        }
    }

    func save(_ items: [ToDoItem]) {
        guard let db = database else {
            if let data = try? encoder.encode(items) {
                UserDefaults.standard.set(data, forKey: key)
            }
            return
        }
        do {
            try db.execute("BEGIN TRANSACTION")
            try db.execute("DELETE FROM \(Self.tableName)")
            for item in items {
                try db.execute(
                    "INSERT INTO \(Self.tableName) (id, title, is_completed, date) VALUES (?, ?, ?, ?)",
                    parameters: [
                        .text(item.id.uuidString),
                        .text(item.title),
                        .bool(item.isCompleted),
                        .double(item.date.timeIntervalSince1970)
                    ]
                )
            }
            try db.execute("COMMIT")
        } catch {
            try? db.execute("ROLLBACK")
            logger.error("Failed to save ToDo items: \(error.localizedDescription)")
        }
    }

    func exportData(_ items: [ToDoItem]) -> Data? {
        try? encoder.encode(items)
    }

    func importFromData(_ data: Data) -> [ToDoItem]? {
        try? decoder.decode([ToDoItem].self, from: data)
    }
}
