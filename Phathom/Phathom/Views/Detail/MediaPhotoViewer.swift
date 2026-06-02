import SwiftUI
import UIKit

struct MediaPhotoViewer: View {
    let image: UIImage
    var accessibilityLabel: String = "Photo"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PhotoZoomScrollViewRepresentable(
                image: image,
                accessibilityLabel: accessibilityLabel,
                animateZoom: !accessibilityReduceMotion
            )
            .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            FlatToolbarTextButton(title: "Done", foreground: AppPalette.accent) {
                dismiss()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.pushNavBarTop)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
    }
}

// MARK: - UIKit photo zoom (Photos-style)

private struct PhotoZoomScrollViewRepresentable: UIViewRepresentable {
    let image: UIImage
    let accessibilityLabel: String
    let animateZoom: Bool

    func makeUIView(context: Context) -> PhotoZoomScrollView {
        let view = PhotoZoomScrollView()
        view.configure(image: image, accessibilityLabel: accessibilityLabel, animateZoom: animateZoom)
        return view
    }

    func updateUIView(_ view: PhotoZoomScrollView, context: Context) {
        view.configure(image: image, accessibilityLabel: accessibilityLabel, animateZoom: animateZoom)
    }
}

/// `UIScrollView` + zooming `UIImageView` — fit-to-screen at min zoom, pinch/double-tap beyond.
private final class PhotoZoomScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private var displayedImage: UIImage?
    private var lastLayoutBoundsSize: CGSize = .zero
    private var animateZoom = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bouncesZoom = true
        backgroundColor = .black
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        isAccessibilityElement = false

        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(image: UIImage, accessibilityLabel: String, animateZoom: Bool) {
        self.animateZoom = animateZoom
        imageView.accessibilityLabel = accessibilityLabel

        guard displayedImage !== image else { return }
        displayedImage = image
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        lastLayoutBoundsSize = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateZoomScalesForCurrentBoundsIfNeeded()
        centerContent()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
    }

    private func updateZoomScalesForCurrentBoundsIfNeeded() {
        guard let image = displayedImage else { return }
        let boundsSize = bounds.size
        guard boundsSize.width > 1, boundsSize.height > 1 else { return }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let widthScale = boundsSize.width / imageSize.width
        let heightScale = boundsSize.height / imageSize.height
        let fitScale = min(widthScale, heightScale)
        let maxScale = max(fitScale * 4, fitScale + 1)

        minimumZoomScale = fitScale
        maximumZoomScale = maxScale

        // Snap to fit only when bounds change (rotation / first layout), not while user pinches.
        if boundsSize != lastLayoutBoundsSize {
            lastLayoutBoundsSize = boundsSize
            zoomScale = fitScale
        } else if zoomScale < fitScale - 0.001 {
            zoomScale = fitScale
        } else if zoomScale > maxScale + 0.001 {
            zoomScale = maxScale
        }
    }

    private func centerContent() {
        let boundsSize = bounds.size
        let contentSize = contentSize

        let insetX = max((boundsSize.width - contentSize.width) * 0.5, 0)
        let insetY = max((boundsSize.height - contentSize.height) * 0.5, 0)
        contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let fitScale = minimumZoomScale
        let zoomedScale = min(fitScale * 2.5, maximumZoomScale)

        if zoomScale > fitScale * 1.05 {
            setZoomScale(fitScale, animated: animateZoom)
            return
        }

        let tapPoint = gesture.location(in: imageView)
        let zoomRect = zoomRect(for: zoomedScale, center: tapPoint)
        zoom(to: zoomRect, animated: animateZoom)
    }

    private func zoomRect(for scale: CGFloat, center: CGPoint) -> CGRect {
        let size = bounds.size
        let width = size.width / scale
        let height = size.height / scale
        let originX = center.x - width / 2
        let originY = center.y - height / 2
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
