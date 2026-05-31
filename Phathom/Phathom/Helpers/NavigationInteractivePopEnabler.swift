import SwiftUI
import UIKit

/// Re-enables `UINavigationController` edge-swipe pop when SwiftUI hides the system back button.
///
/// Wired on ``DetailPushNavBar``. See `docs/decisions.md` — **2026-05-31 Push nav — interactive edge-swipe back**.
struct NavigationInteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> EnablerViewController {
        EnablerViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: EnablerViewController, context: Context) {
        uiViewController.coordinator = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }

    final class EnablerViewController: UIViewController {
        var coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigationController else { return }
            guard let popGesture = navigationController.interactivePopGestureRecognizer else { return }
            coordinator.navigationController = navigationController
            popGesture.isEnabled = true
            popGesture.delegate = coordinator
        }
    }
}
