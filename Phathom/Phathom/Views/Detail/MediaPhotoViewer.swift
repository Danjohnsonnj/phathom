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

            GeometryReader { geometry in
                ZoomableImageView(
                    image: image,
                    containerSize: geometry.size,
                    accessibilityLabel: accessibilityLabel,
                    animateZoom: !accessibilityReduceMotion
                )
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    FlatToolbarTextButton(title: "Done", foreground: AppPalette.accent) {
                        dismiss()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.pushNavBarTop)

                Spacer(minLength: 0)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
    }
}

// MARK: - Zoomable image (UIKit)

private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let containerSize: CGSize
    let accessibilityLabel: String
    let animateZoom: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(image: image, accessibilityLabel: accessibilityLabel, animateZoom: animateZoom)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.isAccessibilityElement = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = accessibilityLabel
        imageView.accessibilityTraits = .image
        scrollView.addSubview(imageView)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.image = image
        context.coordinator.animateZoom = animateZoom
        context.coordinator.photoAccessibilityLabel = accessibilityLabel
        context.coordinator.imageView?.image = image
        context.coordinator.imageView?.accessibilityLabel = accessibilityLabel
        context.coordinator.updateLayout(containerSize: containerSize)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var image: UIImage
        var photoAccessibilityLabel: String
        var animateZoom: Bool
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        private var lastContainerSize: CGSize = .zero

        init(image: UIImage, accessibilityLabel: String, animateZoom: Bool) {
            self.image = image
            self.photoAccessibilityLabel = accessibilityLabel
            self.animateZoom = animateZoom
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        func updateLayout(containerSize: CGSize) {
            guard let scrollView, let imageView else { return }
            guard containerSize.width > 0, containerSize.height > 0 else { return }

            let sizeChanged = containerSize != lastContainerSize
            lastContainerSize = containerSize

            scrollView.frame = CGRect(origin: .zero, size: containerSize)

            imageView.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size

            let fitScale = min(
                containerSize.width / max(image.size.width, 1),
                containerSize.height / max(image.size.height, 1)
            )
            scrollView.minimumZoomScale = fitScale
            scrollView.maximumZoomScale = fitScale * 3

            if sizeChanged || scrollView.zoomScale < fitScale || scrollView.zoomScale > scrollView.maximumZoomScale {
                scrollView.zoomScale = fitScale
            }

            centerImage(in: scrollView)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }

            let minScale = scrollView.minimumZoomScale
            let zoomedScale = min(minScale * 2.5, scrollView.maximumZoomScale)
            let animated = animateZoom

            if scrollView.zoomScale > minScale * 1.01 {
                scrollView.setZoomScale(minScale, animated: animated)
                return
            }

            let tapPoint = gesture.location(in: imageView)
            let zoomRect = zoomRect(for: zoomedScale, center: tapPoint, in: scrollView)
            scrollView.zoom(to: zoomRect, animated: animated)
        }

        private func zoomRect(for scale: CGFloat, center: CGPoint, in scrollView: UIScrollView) -> CGRect {
            let size = scrollView.bounds.size
            let width = size.width / scale
            let height = size.height / scale
            let originX = center.x - width / 2
            let originY = center.y - height / 2
            return CGRect(x: originX, y: originY, width: width, height: height)
        }

        private func centerImage(in scrollView: UIScrollView) {
            let boundsSize = scrollView.bounds.size
            let contentSize = scrollView.contentSize

            let insetX = max((boundsSize.width - contentSize.width) * 0.5, 0)
            let insetY = max((boundsSize.height - contentSize.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }
    }
}
