//
//  ToDoContentView.swift
//  ToDo
//
//  Calendar period view: Today / This week / This month / This year.
//  Grouped lists (7 days, 7 weeks, 7 months), + opens add dialog with date picker.
//

import SwiftUI

enum ToDoPeriod: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This week"
    case thisMonth = "This month"
    case thisYear = "This year"
}

struct ToDoContentView: View {
    @StateObject private var viewModel = ToDoViewModel()
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            dateHeader
            periodButtons
            listContent
            addButtonBar
            bottomToolbar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground(.primary)
        .sheet(isPresented: $showAddSheet) {
            AddToDoSheet(viewModel: viewModel, isPresented: $showAddSheet)
        }
    }

    private var dateHeader: some View {
        Text(viewModel.fullDateString())
            .font(.system(size: AppTheme.FontSize.title, weight: .semibold))
            .foregroundColor(AppTheme.primaryText)
            .padding(.vertical, AppTheme.Spacing.md)
    }

    private var periodButtons: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(ToDoPeriod.allCases, id: \.rawValue) { period in
                Button(period.rawValue) {
                    viewModel.selectedPeriod = period
                }
                .secondaryButtonStyle()
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .stroke(viewModel.selectedPeriod == period ? AppTheme.primary : Color.clear, lineWidth: 2)
                )
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.md)
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ThemedSectionHeader(viewModel.selectedPeriod.rawValue)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    ForEach(viewModel.groupedSections) { section in
                        sectionHeader(section.label)
                        ForEach(section.itemIDs, id: \.self) { id in
                            if let index = viewModel.items.firstIndex(where: { $0.id == id }) {
                                itemRow(item: viewModel.items[index])
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: AppTheme.FontSize.subheadline, weight: .semibold))
            .foregroundColor(AppTheme.secondaryText)
            .padding(.top, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.xs)
    }

    private func itemRow(item: ToDoItem) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Button {
                viewModel.toggle(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(item.isCompleted ? AppTheme.primary : AppTheme.secondaryText)
            }
            .buttonStyle(.plain)
            Text(item.title)
                .font(.system(size: AppTheme.FontSize.body))
                .foregroundColor(item.isCompleted ? AppTheme.secondaryText : AppTheme.primaryText)
                .strikethrough(item.isCompleted)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(viewModel.shortDateString(for: item.date))
                .font(.system(size: AppTheme.FontSize.caption))
                .foregroundColor(AppTheme.tertiaryText)
            Button {
                viewModel.remove(item)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.error)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
    }

    private var addButtonBar: some View {
        HStack {
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.primary)
            }
            .buttonStyle(.plain)
            .help("Add todo")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var bottomToolbar: some View {
        AppBottomToolbar(open: { viewModel.importFromFile() }, save: { viewModel.exportToFile() })
    }
}

// MARK: - Add item sheet (dialog)

struct AddToDoSheet: View {
    @ObservedObject var viewModel: ToDoViewModel
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var useToday = true
    @State private var selectedDate = Date()

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("New to-do")
                .font(.system(size: AppTheme.FontSize.headline, weight: .semibold))
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Item", text: $title)
                .textFieldStyle(ThemedTextFieldStyle())

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Toggle("Today", isOn: $useToday)
                    .toggleStyle(.checkbox)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !useToday {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
            }

            HStack(spacing: AppTheme.Spacing.md) {
                Button("Cancel") {
                    isPresented = false
                }
                .secondaryButtonStyle()
                Button("Add") {
                    addAndDismiss()
                }
                .primaryButtonStyle()
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(minWidth: 320, minHeight: 280, alignment: .leading)
    }

    private func addAndDismiss() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let date = useToday ? Date() : selectedDate
        viewModel.add(title: t, date: date)
        title = ""
        isPresented = false
    }
}
