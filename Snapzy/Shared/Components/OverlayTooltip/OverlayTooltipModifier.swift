import AppKit
import Combine
import SwiftUI

extension View {
  /// Shows an Arc-like overlay tooltip on hover.
  func overlayTooltip(
    _ title: String,
    keys: [String] = [],
    secondary: String? = nil,
    edge: OverlayTooltipEdge = .below,
    delay: TimeInterval = 0.35
  ) -> some View {
    modifier(OverlayTooltipModifier(
      content: OverlayTooltipContent(title: title, keys: keys, secondary: secondary),
      edge: edge,
      delay: delay
    ))
  }
}

private final class OverlayTooltipAnchorProxy: ObservableObject {
  weak var view: NSView?

  func screenFrame() -> CGRect? {
    guard let view, let window = view.window else { return nil }
    let inWindow = view.convert(view.bounds, to: nil)
    return window.convertToScreen(inWindow)
  }
}

private struct OverlayTooltipAnchorReader: NSViewRepresentable {
  let proxy: OverlayTooltipAnchorProxy

  func makeNSView(context _: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async { [weak view] in proxy.view = view }
    return view
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    proxy.view = nsView
  }
}

private struct OverlayTooltipModifier: ViewModifier {
  let content: OverlayTooltipContent
  let edge: OverlayTooltipEdge
  let delay: TimeInterval

  @StateObject private var proxy = OverlayTooltipAnchorProxy()
  @State private var owner = UUID()
  @State private var showWorkItem: DispatchWorkItem?

  func body(content viewContent: Content) -> some View {
    viewContent
      .background(OverlayTooltipAnchorReader(proxy: proxy))
      .onHover { hovering in
        if hovering {
          scheduleShow()
        } else {
          cancelAndHide()
        }
      }
      .onDisappear { cancelAndHide() }
  }

  private func scheduleShow() {
    showWorkItem?.cancel()
    let work = DispatchWorkItem {
      guard let frame = proxy.screenFrame() else { return }
      OverlayTooltipPresenter.shared.show(
        content,
        anchorScreenFrame: frame,
        preferred: edge,
        owner: owner
      )
    }
    showWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
  }

  private func cancelAndHide() {
    showWorkItem?.cancel()
    showWorkItem = nil
    OverlayTooltipPresenter.shared.hide(owner: owner)
  }
}
