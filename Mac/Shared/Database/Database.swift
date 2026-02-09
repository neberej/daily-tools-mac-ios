//
//  Database.swift
//  Shared
//
//  Lightweight SQLite wrapper: open at path, execute, fetch rows.
//  No migrations. Each app opens its own file (e.g. Application Support/AppName/data.sqlite).
//

import Foundation
import SQLite3

// MARK: - App support URL (no hardcoded paths)

public extension FileManager {
    /// Returns Application Support subdirectory for the app, creating it if needed.
    /// Example: `try FileManager.default.appSupportURL(appName: "ToDo")`
    func appSupportURL(appName: String) throws -> URL {
        let base = urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(appName, isDirectory: true)
        try createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

// MARK: - Binding (parameter values)

public enum DatabaseBinding {
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
    case bool(Bool)
    case null
}

// MARK: - Row (typed column access)

public struct DatabaseRow {
    private let columnNames: [String]
    private let values: [DatabaseBinding?]

    init(columnNames: [String], values: [DatabaseBinding?]) {
        self.columnNames = columnNames
        self.values = values
    }

    public func int(_ name: String) -> Int? {
        guard let i = index(of: name), let val = values.at(i), case .int(let v) = val else { return nil }
        return Int(v)
    }

    public func int64(_ name: String) -> Int64? {
        guard let i = index(of: name), let val = values.at(i), case .int(let v) = val else { return nil }
        return v
    }

    public func double(_ name: String) -> Double? {
        guard let i = index(of: name), let val = values.at(i), case .double(let v) = val else { return nil }
        return v
    }

    public func text(_ name: String) -> String? {
        guard let i = index(of: name), let val = values.at(i), case .text(let v) = val else { return nil }
        return v
    }

    public func blob(_ name: String) -> Data? {
        guard let i = index(of: name), let val = values.at(i), case .blob(let v) = val else { return nil }
        return v
    }

    public func date(_ name: String) -> Date? {
        guard let t = double(name) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    public func bool(_ name: String) -> Bool? {
        guard let i = index(of: name), let val = values.at(i) else { return nil }
        if case .int(let v) = val { return v != 0 }
        return nil
    }

    public func uuid(_ name: String) -> UUID? {
        guard let s = text(name) else { return nil }
        return UUID(uuidString: s)
    }

    private func index(of name: String) -> Int? {
        columnNames.firstIndex { $0.caseInsensitiveCompare(name) == .orderedSame }
    }
}

private extension Array {
    func at(_ index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - Database

public final class Database {
    private(set) var db: OpaquePointer?

    private init(db: OpaquePointer?) {
        self.db = db
    }

    deinit {
        close()
    }

    /// Closes the connection and frees resources. Safe to call multiple times.
    public func close() {
        guard let ptr = db else { return }
        sqlite3_close(ptr)
        db = nil
    }

    /// Opens (or creates) a SQLite file at the given URL.
    public static func open(at url: URL) throws -> Database {
        var ptr: OpaquePointer?
        let path = url.path
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(path, &ptr, flags, nil)
        guard rc == SQLITE_OK, let db = ptr else {
            if let db = ptr { sqlite3_close(db) }
            throw DatabaseError.open(String(cString: sqlite3_errstr(rc)))
        }
        return Database(db: db)
    }

    /// Executes a non-returning statement (CREATE, INSERT, UPDATE, DELETE).
    public func execute(_ sql: String, parameters: [DatabaseBinding] = []) throws {
        try prepare(sql, parameters: parameters) { stmt in
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.prepare(self.lastMessage)
            }
        }
    }

    /// Runs a SELECT and returns rows. Map each row to your model (e.g. ToDoItem).
    public func fetch(_ sql: String, parameters: [DatabaseBinding] = []) throws -> [DatabaseRow] {
        var rows: [DatabaseRow] = []
        try _fetch(sql, parameters: parameters) { rows.append($0) }
        return rows
    }

    /// Runs a SELECT and maps each row to a value. Returns `[T]`.
    public func fetch<T>(_ sql: String, parameters: [DatabaseBinding] = [], map: (DatabaseRow) -> T) throws -> [T] {
        try fetch(sql, parameters: parameters).map(map)
    }

    private func _fetch(_ sql: String, parameters: [DatabaseBinding], each: (DatabaseRow) -> Void) throws {
        try prepare(sql, parameters: parameters) { stmt in
            let columnCount = sqlite3_column_count(stmt)
            var names: [String] = []
            for i in 0..<columnCount {
                let c = sqlite3_column_name(stmt, i).map { String(cString: $0) } ?? ""
                names.append(c)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                var values: [DatabaseBinding?] = []
                for i in 0..<columnCount {
                    switch sqlite3_column_type(stmt, Int32(i)) {
                    case SQLITE_INTEGER:
                        values.append(.int(sqlite3_column_int64(stmt, Int32(i))))
                    case SQLITE_FLOAT:
                        values.append(.double(sqlite3_column_double(stmt, Int32(i))))
                    case SQLITE_TEXT:
                        if let p = sqlite3_column_text(stmt, Int32(i)) {
                            values.append(.text(String(cString: p)))
                        } else {
                            values.append(.null)
                        }
                    case SQLITE_BLOB:
                        if let p = sqlite3_column_blob(stmt, Int32(i)) {
                            let len = Int(sqlite3_column_bytes(stmt, Int32(i)))
                            values.append(.blob(Data(bytes: p, count: len)))
                        } else {
                            values.append(.null)
                        }
                    default:
                        values.append(.null)
                    }
                }
                each(DatabaseRow(columnNames: names, values: values))
            }
        }
    }

    private func prepare(_ sql: String, parameters: [DatabaseBinding], step: (OpaquePointer) throws -> Void) throws {
        guard let connection = db else { throw DatabaseError.prepare("database is closed") }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else {
            throw DatabaseError.prepare(lastMessage)
        }
        defer { sqlite3_finalize(s) }
        for (i, param) in parameters.enumerated() {
            let idx = Int32(i + 1)
            switch param {
            case .int(let v): sqlite3_bind_int64(s, idx, v)
            case .double(let v): sqlite3_bind_double(s, idx, v)
            case .text(let v): sqlite3_bind_text(s, idx, (v as NSString).utf8String, -1, SQLITE_TRANSIENT)
            case .blob(let v): v.withUnsafeBytes { sqlite3_bind_blob(s, idx, $0.baseAddress, Int32(v.count), SQLITE_TRANSIENT) }
            case .bool(let v): sqlite3_bind_int64(s, idx, v ? 1 : 0)
            case .null: sqlite3_bind_null(s, idx)
            }
        }
        try step(s)
    }

    private var lastMessage: String {
        guard let db = db else { return "no connection" }
        return String(cString: sqlite3_errmsg(db))
    }
}

public enum DatabaseError: Error {
    case open(String)
    case prepare(String)
}

// SQLITE_TRANSIENT for bind: copy the buffer
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
