//
//  ToDoViewModel.swift
//  ToDo
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ToDoSection: Identifiable {
    let id: String
    let label: String
    let itemIDs: [UUID]
}

@MainActor
final class ToDoViewModel: ObservableObject {
    @Published var items: [ToDoItem] = []
    @Published var selectedPeriod: ToDoPeriod = .today
    @Published var referenceDate = Date()

    private let store = ToDoStore()
    private var calendar: Calendar { Calendar.current }

    /// Flat list for "Today"; for other periods use groupedSections.
    var filteredItems: [ToDoItem] {
        let range = dateRange(for: selectedPeriod)
        return items
            .filter { range.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    /// Max 7 subsections: 7 days (This week), 7 weeks (This month), 7 months (This year).
    /// Sections hold IDs only; rows render from items (single source of truth).
    var groupedSections: [ToDoSection] {
        switch selectedPeriod {
        case .today:
            return [ToDoSection(id: "today", label: "Today", itemIDs: filteredItems.map(\.id))]
        case .thisWeek:
            return daySections(count: 7)
        case .thisMonth:
            return weekSections(count: 7)
        case .thisYear:
            return yearSections(count: 7)
        }
    }

    init() {
        items = store.load()
    }

    func fullDateString() -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: referenceDate)
    }

    func shortDateString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    func dateRange(for period: ToDoPeriod) -> ClosedRange<Date> {
        let start: Date
        let end: Date
        switch period {
        case .today:
            start = calendar.startOfDay(for: referenceDate)
            end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
        case .thisWeek:
            start = calendar.startOfDay(for: referenceDate)
            end = calendar.date(byAdding: .day, value: 7, to: start)!.addingTimeInterval(-1)
        case .thisMonth:
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))!
            end = calendar.date(byAdding: .month, value: 1, to: start)!.addingTimeInterval(-1)
        case .thisYear:
            start = calendar.date(from: calendar.dateComponents([.year], from: referenceDate))!
            end = calendar.date(byAdding: .year, value: 1, to: start)!.addingTimeInterval(-1)
        }
        return start ... end
    }

    private func daySections(count: Int) -> [ToDoSection] {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        var result: [ToDoSection] = []
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        for i in 0..<count {
            guard let dayStart = calendar.date(byAdding: .day, value: i, to: startOfToday),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let dayEndExclusive = dayEnd.addingTimeInterval(-0.001)
            let label: String
            if i == 0 { label = "Today" }
            else if i == 1 { label = "Tomorrow" }
            else { label = weekdayFormatter.string(from: dayStart) }
            let sectionItemIDs = items
                .filter { $0.date >= dayStart && $0.date <= dayEndExclusive }
                .sorted { $0.date < $1.date }
                .map(\.id)
            result.append(ToDoSection(id: "day-\(i)", label: label, itemIDs: sectionItemIDs))
        }
        return result
    }

    private func weekSections(count: Int) -> [ToDoSection] {
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate))!
        var result: [ToDoSection] = []
        for i in 0..<count {
            guard let start = calendar.date(byAdding: .weekOfYear, value: i, to: weekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { break }
            let endExclusive = end.addingTimeInterval(-0.001)
            let label = i == 0 ? "This week" : (i == 1 ? "Next week" : "In \(i) weeks")
            let sectionItemIDs = items
                .filter { $0.date >= start && $0.date <= endExclusive }
                .sorted { $0.date < $1.date }
                .map(\.id)
            result.append(ToDoSection(id: "week-\(i)", label: label, itemIDs: sectionItemIDs))
        }
        return result
    }

    private func monthSections(count: Int) -> [ToDoSection] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))!
        var result: [ToDoSection] = []
        for i in 0..<count {
            guard let start = calendar.date(byAdding: .month, value: i, to: monthStart),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { break }
            let endExclusive = end.addingTimeInterval(-0.001)
            let label = i == 0 ? "This month" : (i == 1 ? "Next month" : "In \(i) months")
            let sectionItemIDs = items
                .filter { $0.date >= start && $0.date <= endExclusive }
                .sorted { $0.date < $1.date }
                .map(\.id)
            result.append(ToDoSection(id: "month-\(i)", label: label, itemIDs: sectionItemIDs))
        }
        return result
    }

    private func yearSections(count: Int) -> [ToDoSection] {
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: referenceDate))!
        var result: [ToDoSection] = []
        for i in 0..<count {
            guard let start = calendar.date(byAdding: .year, value: i, to: yearStart),
                  let end = calendar.date(byAdding: .year, value: 1, to: start) else { break }
            let endExclusive = end.addingTimeInterval(-0.001)
            let label = i == 0 ? "This year" : (i == 1 ? "Next year" : "In \(i) years")
            let sectionItemIDs = items
                .filter { $0.date >= start && $0.date <= endExclusive }
                .sorted { $0.date < $1.date }
                .map(\.id)
            result.append(ToDoSection(id: "year-\(i)", label: label, itemIDs: sectionItemIDs))
        }
        return result
    }

    func toggle(_ item: ToDoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[i]
        updated.isCompleted.toggle()
        items[i] = updated
        store.save(items)
    }

    func add(title: String, date: Date) {
        let startOfDay = calendar.startOfDay(for: date)
        let item = ToDoItem(title: title, date: startOfDay)
        items.append(item)
        store.save(items)
    }

    func remove(_ item: ToDoItem) {
        items.removeAll { $0.id == item.id }
        store.save(items)
    }

    func exportToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "todo-list.json"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            guard let data = self.store.exportData(self.items) else { return }
            try? data.write(to: url)
        }
    }

    func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            guard let data = try? Data(contentsOf: url),
                  let loaded = self.store.importFromData(data) else { return }
            self.items = loaded
            self.store.save(self.items)
        }
    }
}
