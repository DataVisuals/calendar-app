import SwiftUI
import AppKit

// Custom view modifier to handle scroll wheel events
struct ScrollWheelModifier: ViewModifier {
    let onScroll: (NSEvent) -> Void

    func body(content: Content) -> some View {
        ScrollWheelHostingView(onScroll: onScroll) {
            content
        }
    }
}

// NSViewRepresentable that wraps content and captures scroll events
struct ScrollWheelHostingView<Content: View>: NSViewRepresentable {
    let onScroll: (NSEvent) -> Void
    let content: Content

    init(onScroll: @escaping (NSEvent) -> Void, @ViewBuilder content: () -> Content) {
        self.onScroll = onScroll
        self.content = content()
    }

    func makeNSView(context: Context) -> ScrollWheelContainerView {
        let view = ScrollWheelContainerView(onScroll: onScroll)
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        return view
    }

    func updateNSView(_ nsView: ScrollWheelContainerView, context: Context) {
        nsView.onScroll = onScroll
        // Update the hosting view's root view
        if let hostingView = nsView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

class ScrollWheelContainerView: NSView {
    var onScroll: (NSEvent) -> Void

    init(onScroll: @escaping (NSEvent) -> Void) {
        self.onScroll = onScroll
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll(event)
        // Don't call super to prevent default scroll behavior
    }
}

extension View {
    func onScrollWheel(perform action: @escaping (NSEvent) -> Void) -> some View {
        self.modifier(ScrollWheelModifier(onScroll: action))
    }
}
