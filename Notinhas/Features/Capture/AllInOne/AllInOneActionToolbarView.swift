//
//  AllInOneActionToolbarView.swift
//  Notinhas
//
//  Dimensions, aspect lock, and primary Capture action for All-In-One.
//

import SwiftUI

struct AllInOneActionToolbarView: View {
  @ObservedObject var session: AllInOneCaptureSessionState

  var body: some View {
    HStack(spacing: ToolbarConstants.itemSpacing) {
      if session.selectedMode.showsDimensionsBar, let rect = session.currentRect {
        AllInOneDimensionsBarView(rect: rect) { updated in
          session.updateRect(updated)
        }

        CaptureFloatingToolbarDivider()
      }

      Button(action: session.confirmCapture) {
        Text(L10n.AllInOne.captureButton)
          .font(.system(size: 13, weight: .semibold))
          .padding(.horizontal, 14)
          .padding(.vertical, 6)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
      .accessibilityLabel(L10n.AllInOne.captureButtonAccessibility)
    }
    .padding(.horizontal, ToolbarConstants.horizontalPadding)
    .padding(.vertical, ToolbarConstants.verticalPadding)
    .captureFloatingToolbarMaterial()
  }
}

#Preview {
  let session = AllInOneCaptureSessionState()
  session.currentRect = CGRect(x: 100, y: 200, width: 640, height: 360)
  return AllInOneActionToolbarView(session: session)
    .padding()
}
