//
//  CaptureFloatingToolbarChrome.swift
//  Notinhas
//
//  Shared SwiftUI chrome for floating capture HUD toolbars (ungated).
//

import SwiftUI

// MARK: - Divider

struct CaptureFloatingToolbarDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color.primary.opacity(0.15))
      .frame(width: 1, height: ToolbarConstants.dividerHeight)
      .padding(.horizontal, 4)
  }
}

// MARK: - Icon Button

struct CaptureFloatingToolbarIconButtonLabel: View {
  let systemName: String
  var iconSize: CGFloat = ToolbarConstants.iconSize
  let isHovered: Bool

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: iconSize, weight: .medium))
      .foregroundColor(.primary.opacity(isHovered ? 1.0 : 0.85))
      .frame(
        width: ToolbarConstants.iconButtonSize,
        height: ToolbarConstants.iconButtonSize
      )
      .background(
        RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
          .fill(Color.primary.opacity(isHovered ? 0.1 : 0))
      )
      .contentShape(RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius))
      .animation(ToolbarConstants.hoverAnimation, value: isHovered)
  }
}

struct CaptureFloatingToolbarIconButton: View {
  let systemName: String
  let action: () -> Void
  let accessibilityLabel: String

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      CaptureFloatingToolbarIconButtonLabel(systemName: systemName, isHovered: isHovered)
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .accessibilityLabel(accessibilityLabel)
  }
}

// MARK: - Material Background

extension View {
  func captureFloatingToolbarMaterial() -> some View {
    background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: ToolbarConstants.toolbarCornerRadius))
  }
}
