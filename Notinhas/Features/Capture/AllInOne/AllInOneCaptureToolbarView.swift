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
        modeButton(for: mode)
      }
    }
    .padding(.horizontal, ToolbarConstants.horizontalPadding)
    .padding(.vertical, ToolbarConstants.verticalPadding)
    .captureFloatingToolbarMaterial()
  }

  private func modeButton(for mode: AllInOneCaptureMode) -> some View {
    let isSelected = session.selectedMode == mode

    return CaptureFloatingToolbarIconButton(
      systemName: mode.systemImage,
      action: { session.selectMode(mode) },
      accessibilityLabel: mode.accessibilityLabel
    )
    .overlay {
      RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
        .strokeBorder(Color.accentColor.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
    }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

#Preview {
  AllInOneCaptureToolbarView(session: AllInOneCaptureSessionState())
    .padding()
}
