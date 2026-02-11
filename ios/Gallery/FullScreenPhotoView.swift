//
//  FullScreenPhotoView.swift
//  Gallery
//

import SwiftUI
import UIKit
import Photos

// MARK: - SwiftUI Shell

struct FullScreenPhotoView: View {
    let assets: [PHAsset]
    let initialIndex: Int
    let onDismiss: () -> Void

    @EnvironmentObject var library: PhotoLibraryService
    @State private var currentIndex: Int
    @State private var showControls = true
    @State private var showAddToAlbumSheet = false
    @State private var addToAlbumMessage: String?
    @State private var showToast = false
    @State private var currentImage: UIImage?

    init(assets: [PHAsset], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.assets = assets
        self.initialIndex = min(max(0, initialIndex), max(0, assets.count - 1))
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: min(max(0, initialIndex), max(0, assets.count - 1)))
    }

    private var displayedAsset: PHAsset? {
        guard currentIndex >= 0, currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PagedPhotoViewRepresentable(
                assets: assets,
                initialIndex: initialIndex,
                library: library,
                onPageChanged: { index, image in
                    currentIndex = index
                    currentImage = image
                },
                onSingleTap: {
                    withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
                },
                onDismiss: { onDismiss() }
            )
            .ignoresSafeArea()

            if showControls {
                controlsOverlay
            }

            if showToast, let message = addToAlbumMessage {
                toastView(message: message)
            }
        }
        .statusBarHidden(!showControls)
        .sheet(isPresented: $showAddToAlbumSheet) {
            if let asset = displayedAsset {
                AddToAlbumSheetView(
                    asset: asset,
                    onDismiss: { showAddToAlbumSheet = false },
                    onAdded: { message in
                        addToAlbumMessage = message
                        showAddToAlbumSheet = false
                        showToast = true
                    }
                )
                .environmentObject(library)
            }
        }
        .onChange(of: showToast) { _, visible in
            if visible {
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    await MainActor.run {
                        showToast = false
                        addToAlbumMessage = nil
                    }
                }
            }
        }
    }

    private func toastView(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.bottom, 100)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeOut(duration: 0.25), value: showToast)
    }

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            // Top bar with gradient — buttons are hittable
            HStack {
                Button("Done") { onDismiss() }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.leading, 16)
                    .padding(.top, 8)

                Spacer()

                if displayedAsset != nil {
                    HStack(spacing: 20) {
                        Button {
                            showAddToAlbumSheet = true
                        } label: {
                            Image(systemName: "folder.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                        if let image = currentImage {
                            ShareLink(
                                item: Image(uiImage: image),
                                preview: SharePreview("Photo", image: Image(uiImage: image))
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.4), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .allowsHitTesting(false)
            )

            // Middle area: pass all touches through to UIKit
            Spacer()
                .allowsHitTesting(false)

            // Bottom indicator: non-interactive
            if assets.count > 1 {
                Text("\(currentIndex + 1) of \(assets.count)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 40)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - UIKit Bridge: UIViewControllerRepresentable

struct PagedPhotoViewRepresentable: UIViewControllerRepresentable {
    let assets: [PHAsset]
    let initialIndex: Int
    let library: PhotoLibraryService
    let onPageChanged: (Int, UIImage?) -> Void
    let onSingleTap: () -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> PagedPhotoPageViewController {
        let vc = PagedPhotoPageViewController(
            assets: assets,
            initialIndex: initialIndex,
            library: library,
            onPageChanged: onPageChanged,
            onSingleTap: onSingleTap,
            onDismiss: onDismiss
        )
        return vc
    }

    func updateUIViewController(_ uiViewController: PagedPhotoPageViewController, context: Context) {
        // Static content; nothing to update.
    }
}

// MARK: - UIPageViewController (swipe left/right between photos)

final class PagedPhotoPageViewController: UIPageViewController,
    UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {

    private let assets: [PHAsset]
    private let library: PhotoLibraryService
    private let onPageChanged: (Int, UIImage?) -> Void
    private let onSingleTap: () -> Void
    private let onDismiss: () -> Void
    private var currentIdx: Int
    private var isDismissing = false

    init(assets: [PHAsset], initialIndex: Int, library: PhotoLibraryService,
         onPageChanged: @escaping (Int, UIImage?) -> Void,
         onSingleTap: @escaping () -> Void,
         onDismiss: @escaping () -> Void) {
        self.assets = assets
        self.library = library
        self.onPageChanged = onPageChanged
        self.onSingleTap = onSingleTap
        self.onDismiss = onDismiss
        self.currentIdx = initialIndex
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [
            .interPageSpacing: 20
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        dataSource = self
        delegate = self

        let initial = makeZoomVC(for: currentIdx)
        setViewControllers([initial], direction: .forward, animated: false)

        // Swipe down to dismiss
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    // MARK: Swipe down to dismiss

    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .ended, .cancelled:
            if translation.y > 80 || velocity.y > 600 {
                onDismiss()
            }
        default:
            break
        }
    }

    // Only start dismiss pan when dragging downward and not zoomed in
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        // Must be primarily vertical and downward
        guard velocity.y > 0, abs(velocity.y) > abs(velocity.x) * 1.5 else { return false }
        // Don't allow if current photo is zoomed in
        if let zoomVC = viewControllers?.first as? ZoomablePhotoViewController,
           zoomVC.isZoomed { return false }
        return true
    }

    // Allow simultaneous recognition so page swiping still works
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        false // don't fire with page scroll at the same time
    }

    private func makeZoomVC(for index: Int) -> ZoomablePhotoViewController {
        ZoomablePhotoViewController(
            asset: assets[index],
            index: index,
            library: library,
            onSingleTap: onSingleTap,
            onImageLoaded: { [weak self] idx, image in
                guard let self, idx == self.currentIdx else { return }
                self.onPageChanged(idx, image)
            }
        )
    }

    // MARK: DataSource

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? ZoomablePhotoViewController else { return nil }
        let prev = vc.index - 1
        guard prev >= 0 else { return nil }
        return makeZoomVC(for: prev)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? ZoomablePhotoViewController else { return nil }
        let next = vc.index + 1
        guard next < assets.count else { return nil }
        return makeZoomVC(for: next)
    }

    // MARK: Delegate

    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard completed,
              let vc = viewControllers?.first as? ZoomablePhotoViewController else { return }
        currentIdx = vc.index
        onPageChanged(vc.index, vc.loadedImage)
    }
}

// MARK: - Zoomable Photo (UIScrollView + UIImageView per page)

final class ZoomablePhotoViewController: UIViewController, UIScrollViewDelegate {
    let asset: PHAsset
    let index: Int
    private let library: PhotoLibraryService
    private let onSingleTap: () -> Void
    private let onImageLoaded: (Int, UIImage?) -> Void

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private(set) var loadedImage: UIImage?

    /// True when zoomed in past minimum scale (used by dismiss gesture)
    var isZoomed: Bool { scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 }

    init(asset: PHAsset, index: Int, library: PhotoLibraryService,
         onSingleTap: @escaping () -> Void,
         onImageLoaded: @escaping (Int, UIImage?) -> Void) {
        self.asset = asset
        self.index = index
        self.library = library
        self.onSingleTap = onSingleTap
        self.onImageLoaded = onImageLoaded
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Scroll view
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)

        // Image view
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)

        // Spinner
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Double-tap to zoom
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        // Single-tap to toggle controls (requires double-tap to fail first)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)

        loadImage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let image = loadedImage else { return }
        layoutImage(image)
    }

    // MARK: Image loading

    private func loadImage() {
        spinner.startAnimating()
        let scale = UIScreen.main.scale
        let bounds = UIScreen.main.bounds.size

        let targetSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        Task { [weak self] in
            guard let self else { return }
            let image = await self.library.requestImage(
                for: self.asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                highQuality: true
            )
            await MainActor.run {
                self.spinner.stopAnimating()
                guard let image else { return }
                self.loadedImage = image
                self.imageView.image = image
                self.layoutImage(image)
                self.onImageLoaded(self.index, image)
            }
        }
    }

    // MARK: Layout

    private func layoutImage(_ image: UIImage) {
        let viewSize = scrollView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return }

        let imageSize = image.size
        let widthScale = viewSize.width / imageSize.width
        let heightScale = viewSize.height / imageSize.height
        let fitScale = min(widthScale, heightScale)

        // Set imageView to the fitted size at scale 1
        let fittedWidth = imageSize.width * fitScale
        let fittedHeight = imageSize.height * fitScale
        imageView.frame = CGRect(x: 0, y: 0, width: fittedWidth, height: fittedHeight)
        scrollView.contentSize = CGSize(width: fittedWidth, height: fittedHeight)

        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = max(5, 1 / fitScale) // allow zooming to real pixel size
        scrollView.zoomScale = 1

        centerImage()
    }

    private func centerImage() {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width * scrollView.zoomScale) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height * scrollView.zoomScale) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    // MARK: UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    // MARK: Gestures

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let tapPoint = gesture.location(in: imageView)
            let targetScale = min(scrollView.maximumZoomScale, 3.0)
            let zoomRect = zoomRect(scale: targetScale, center: tapPoint)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }

    @objc private func handleSingleTap() {
        onSingleTap()
    }

    private func zoomRect(scale: CGFloat, center: CGPoint) -> CGRect {
        let size = CGSize(
            width: scrollView.bounds.width / scale,
            height: scrollView.bounds.height / scale
        )
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
