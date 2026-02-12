//
//  EffectsBrowserView.swift
//  Effects
//

import CoreImage
import SwiftUI

struct EffectsBrowserView: View {
    let sourceImage: UIImage
    let sourceCIImage: CIImage
    let onReset: () -> Void

    @State private var selectedCategory: EffectCategory = .film
    @State private var selectedDefinition: EffectDefinition?
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 0) {
            topBar

            sourcePreview

            categoryPills
                .padding(.top, 12)

            effectGrid
                .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .background(AppTheme.surfaceBackground.ignoresSafeArea())
        .fullScreenCover(isPresented: $showDetail) {
            if let def = selectedDefinition {
                EffectDetailView(
                    definition: def,
                    sourceImage: sourceImage,
                    sourceCIImage: sourceCIImage,
                    onDismiss: { showDetail = false }
                )
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                onReset()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Effects")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Source Preview

    private var sourcePreview: some View {
        Image(uiImage: sourceImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            .padding(.top, 4)
    }

    // MARK: - Category Pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(EffectCategory.allCases) { category in
                    categoryPill(category)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func categoryPill(_ category: EffectCategory) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(category.rawValue)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedCategory == category ? .white : .white.opacity(0.5))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    selectedCategory == category
                        ? .white.opacity(0.15)
                        : .white.opacity(0.05),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Effect Grid

    private let effectColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var effectGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: effectColumns, spacing: 16) {
                ForEach(filteredDefinitions) { def in
                    EffectPreviewCard(
                        definition: def,
                        sourceImage: sourceCIImage,
                        isSelected: selectedDefinition?.id == def.id,
                        action: {
                            selectedDefinition = def
                            showDetail = true
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private var filteredDefinitions: [EffectDefinition] {
        EffectRegistry.effects(for: selectedCategory)
    }
}
