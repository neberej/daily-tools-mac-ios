//
//  PhotoActionView.swift
//  Effects
//

import SwiftUI

enum PhotoAction {
    case edit
    case effects
}

struct PhotoActionView: View {
    let image: UIImage
    let onSelect: (PhotoAction) -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Choose Action")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Spacer()

            // Photo preview
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
                .padding(.horizontal, 32)

            Spacer()

            // Action cards
            HStack(spacing: 16) {
                actionCard(
                    icon: "slider.horizontal.3",
                    title: "Edit",
                    subtitle: "Crop, resize & more",
                    gradient: [.blue, .cyan]
                ) {
                    onSelect(.edit)
                }

                actionCard(
                    icon: "wand.and.stars",
                    title: "Effects",
                    subtitle: "Filters & styles",
                    gradient: [.purple, .pink]
                ) {
                    onSelect(.effects)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(AppTheme.surfaceBackground.ignoresSafeArea())
    }

    // MARK: - Action Card

    private func actionCard(
        icon: String,
        title: String,
        subtitle: String,
        gradient: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
