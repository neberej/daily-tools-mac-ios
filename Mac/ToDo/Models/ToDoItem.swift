//
//  ToDoItem.swift
//  ToDo
//

import Foundation

struct ToDoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var date: Date

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, date: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.date = date
    }
}
