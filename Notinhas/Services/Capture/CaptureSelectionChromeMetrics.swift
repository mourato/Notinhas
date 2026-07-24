//
//  CaptureSelectionChromeMetrics.swift
//  Notinhas
//

import CoreGraphics

/// Shared visual and hit-test metrics for capture selection chrome (Recording, All-In-One, Markup).
enum CaptureSelectionChromeMetrics {
  static let handleHitSize: CGFloat = 10
  static let cornerHandleLength: CGFloat = 20
  static let edgeHandleLength: CGFloat = 24
  static let handleThickness: CGFloat = 3
  static let continuousBorderWidth: CGFloat = 1.5

  /// Minimum size for a confirmed selection rectangle (refinement / annotating / pre-record).
  static let confirmedMinimumSize: CGFloat = 50
  /// Minimum drag extent while creating a new selection area.
  static let creationMinimumSize: CGFloat = 5

  static var minimumSpanForEdgeHandle: CGFloat {
    cornerHandleLength * 2 + edgeHandleLength
  }
}
