//
//  Binding+Stepped.swift
//  Notinhas
//
//  Binding extension to enable step snapping and clamping on sliders
//  without showing native macOS tick marks.
//

import SwiftUI

enum SteppedValue {
  static func nudge(_ value: CGFloat, by step: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
    precondition(step != 0, "SteppedValue.nudge requires a non-zero step")
    let snapped = ((value + step) / step).rounded() * step
    return Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
  }

  /// Whether applying `step` (signed) would change `value` after snap+clamp.
  static func canNudge(_ value: CGFloat, by step: CGFloat, in range: ClosedRange<CGFloat>) -> Bool {
    abs(nudge(value, by: step, in: range) - value) > 1e-9
  }
}

extension Binding where Value == CGFloat {
  func stepped(by step: CGFloat, in range: ClosedRange<CGFloat>) -> Binding<CGFloat> {
    Binding(
      get: { self.wrappedValue },
      set: { newValue in
        let snapped = (newValue / step).rounded() * step
        self.wrappedValue = Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
      }
    )
  }
}

extension Binding where Value == Double {
  func stepped(by step: Double, in range: ClosedRange<Double>) -> Binding<Double> {
    Binding(
      get: { self.wrappedValue },
      set: { newValue in
        let snapped = (newValue / step).rounded() * step
        self.wrappedValue = Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
      }
    )
  }
}

extension Binding where Value == Float {
  func stepped(by step: Float, in range: ClosedRange<Float>) -> Binding<Float> {
    Binding(
      get: { self.wrappedValue },
      set: { newValue in
        let snapped = (newValue / step).rounded() * step
        self.wrappedValue = Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
      }
    )
  }
}
