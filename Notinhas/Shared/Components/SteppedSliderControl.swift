//
//  SteppedSliderControl.swift
//  Notinhas
//
//  Slider with adjacent minus/plus stepper buttons for discrete value nudging.
//

import SwiftUI

struct SteppedSliderControl: View {
  @Binding var value: CGFloat
  let step: CGFloat
  let range: ClosedRange<CGFloat>
  var sliderWidth: CGFloat?
  var onEditingChanged: (Bool) -> Void = { _ in }

  init(
    value: Binding<CGFloat>,
    step: CGFloat,
    in range: ClosedRange<CGFloat>,
    sliderWidth: CGFloat? = nil,
    onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) {
    _value = value
    self.step = step
    self.range = range
    self.sliderWidth = sliderWidth
    self.onEditingChanged = onEditingChanged
  }

  private var canDecrement: Bool {
    SteppedValue.nudge(value, by: -step, in: range) < value
  }

  private var canIncrement: Bool {
    SteppedValue.nudge(value, by: step, in: range) > value
  }

  var body: some View {
    HStack(spacing: 4) {
      stepperButton(systemName: "minus", isEnabled: canDecrement, delta: -step)
        .accessibilityLabel("Decrease")

      Slider(
        value: $value.stepped(by: step, in: range),
        in: range,
        onEditingChanged: onEditingChanged
      )
      .controlSize(.small)
      .frame(width: sliderWidth)

      stepperButton(systemName: "plus", isEnabled: canIncrement, delta: step)
        .accessibilityLabel("Increase")
    }
  }

  private func stepperButton(systemName: String, isEnabled: Bool, delta: CGFloat) -> some View {
    Button {
      onEditingChanged(true)
      value = SteppedValue.nudge(value, by: delta, in: range)
      onEditingChanged(false)
    } label: {
      Image(systemName: systemName)
        .font(.system(size: 10, weight: .semibold))
        .frame(width: 20, height: 20)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.35)
  }
}

#if DEBUG
  #Preview {
    struct PreviewHarness: View {
      @State private var value: CGFloat = 4

      var body: some View {
        SteppedSliderControl(
          value: $value,
          step: 0.5,
          in: 1 ... 8,
          sliderWidth: 96
        )
        .padding()
      }
    }

    return PreviewHarness()
  }
#endif
