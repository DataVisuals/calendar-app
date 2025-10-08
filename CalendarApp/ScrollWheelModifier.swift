import SwiftUI
import AppKit

// Custom view modifier to handle scroll wheel events
struct ScrollWheelModifier: ViewModifier {
    let onScroll: (NSEvent) -> Void
    
    func body(content: Content) -> some View {
        content.overlay(
            ScrollWheelView(onScroll: onScroll)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        )
    }
}

// NSView wrapper to capture scroll wheel events
struct ScrollWheelView: NSViewRepresentable {
    let onScroll: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> ScrollWheelNSView {
        ScrollWheelNSView(onScroll: onScroll)
    }
    
    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

class ScrollWheelNSView: NSView {
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
        super.scrollWheel(with: event)
    }
}

extension View {
    func onScrollWheel(perform action: @escaping (NSEvent) -> Void) -> some View {
        self.modifier(ScrollWheelModifier(onScroll: action))
    }
}
