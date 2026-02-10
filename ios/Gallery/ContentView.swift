//
//  ContentView.swift
//  Gallery
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .photos
    @State private var sortNewestFirst: Bool = false

    enum Tab: String, CaseIterable {
        case photos = "Photos"
        case albums = "Albums"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .photos:
                    PhotosTabView(sortNewestFirst: $sortNewestFirst)
                case .albums:
                    AlbumsTabView(sortNewestFirst: $sortNewestFirst)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingBarView(
                selectedTab: $selectedTab,
                sortNewestFirst: $sortNewestFirst
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct FloatingBarView: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var sortNewestFirst: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 8)

            Spacer(minLength: 16)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sortNewestFirst.toggle()
                }
            } label: {
                Image(systemName: sortNewestFirst ? "arrow.down.to.line" : "arrow.up.to.line")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }
}

#Preview {
    ContentView()
        .environmentObject(PhotoLibraryService())
}
