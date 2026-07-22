//
//  AllInOneCaptureToolbarView.swift
//  Notinhas
//
//  Mode strip for the All-In-One capture session.
//

import SwiftUI

struct AllInOneCaptureToolbarView: View {
  @ObservedObject var session: AllInOneCaptureSessionState

  var body: some View {
    HStack(spacing: ToolbarConstants.itemSpacing) {
      ForEach(session.availableModes) { mode in
        AllInOneCaptureToolbarModeButton(
          mode: mode,
          isSelected: session.selectedMode == mode,
          action: { session.selectMode(mode) }
        )
      }
    }
    .padding(.horizontal, ToolbarConstants.horizontalPadding)
    .padding(.vertical, ToolbarConstants.verticalPadding)
    .captureFloatingToolbarMaterial()
  }
}

private struct AllInOneCaptureToolbarModeButton: View {
  let mode: AllInOneCaptureMode
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: mode.systemImage)
          .font(.system(size: ToolbarConstants.iconSize, weight: .medium))

        Text(mode.compactTitle)
          .font(.system(size: 10, weight: .medium))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .foregroundStyle(foregroundStyle)
      .frame(width: 54, height: 46)
      .background(background)
      .overlay(selectionBorder)
      .contentShape(RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius))
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .accessibilityLabel(mode.accessibilityLabel)
    .accessibilityValue(isSelected ? selectedAccessibilityValue : "")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .animation(reduceMotion ? nil : ToolbarConstants.hoverAnimation, value: isHovered)
    .animation(reduceMotion ? nil : ToolbarConstants.hoverAnimation, value: isSelected)
  }

  private var foregroundStyle: Color {
    if isSelected {
      return colorScheme == .dark ? .white : .primary
    }
    return .primary.opacity(isHovered ? 0.95 : 0.72)
  }

  private var background: some View {
    RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
      .fill(backgroundFill)
  }

  private var backgroundFill: Color {
    if isSelected {
      if reduceTransparency {
        return colorScheme == .dark
          ? Color.white.opacity(0.22)
          : Color.primary.opacity(0.14)
      }
      return Color.accentColor.opacity(colorScheme == .dark ? 0.42 : 0.18)
    }

    if isHovered {
      return Color.primary.opacity(reduceTransparency ? 0.12 : 0.08)
    }

    return .clear
  }

  private var selectionBorder: some View {
    RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
      .strokeBorder(
        isSelected ? Color.primary.opacity(reduceTransparency ? 0.55 : 0.35) : .clear,
        lineWidth: isSelected ? 1.5 : 0
      )
  }

  private var selectedAccessibilityValue: String {
    L10n.AllInOne.modeSelectedAccessibilityValue
  }
}

#Preview {
  AllInOneCaptureToolbarView(session: AllInOneCaptureSessionState())
    .padding()
}
