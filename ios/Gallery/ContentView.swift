//
//  ContentView.swift
//  Gallery
//

import SwiftUI
import Photos

struct ContentView: View {
    @State private var selectedTab: Tab = .photos
    @State private var sortNewestFirst: Bool = false
    @State private var scrollToEdge: ScrollEdge?

    enum Tab: String, CaseIterable {
        case photos = "Photos"
        case albums = "Albums"
        case favorites = "Favorites"
    }

    enum ScrollEdge {
        case top, bottom
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .photos:
                    PhotosTabView(sortNewestFirst: $sortNewestFirst, scrollToEdge: $scrollToEdge)
                case .favorites:
                    FavoritesTabView(sortNewestFirst: $sortNewestFirst)
                case .albums:
                    AlbumsTabView(sortNewestFirst: $sortNewestFirst)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingBarView(
                selectedTab: $selectedTab,
                sortNewestFirst: $sortNewestFirst,
                scrollToEdge: $scrollToEdge
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct FloatingBarView: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var sortNewestFirst: Bool
    @Binding var scrollToEdge: ContentView.ScrollEdge?

    @State private var atBottom = true  // track which end we last scrolled to

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        if tab == .favorites {
                            Image(systemName: selectedTab == .favorites ? "heart.fill" : "heart")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(selectedTab == .favorites ? .pink : .secondary)
                                .frame(width: 44, height: 44)
                        } else {
                            Text(tab.rawValue)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 8)

            Spacer(minLength: 12)

            // Sort order
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sortNewestFirst.toggle()
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)

            // Scroll to top / bottom
            Button {
                if atBottom {
                    scrollToEdge = .top
                } else {
                    scrollToEdge = .bottom
                }
                atBottom.toggle()
            } label: {
                Image(systemName: atBottom ? "arrow.up.to.line" : "arrow.down.to.line")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
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
