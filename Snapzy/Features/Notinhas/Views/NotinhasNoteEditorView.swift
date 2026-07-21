import SwiftUI

struct NotinhasNoteEditorView: View {
  let displayNumber: Int
  @Binding var text: String
  @Binding var color: RGBAColor
  @Binding var areaStyle: NotinhasAreaStyle
  let showsAreaStyle: Bool
  let onCommit: () -> Void
  let onCancel: () -> Void
  let onDelete: () -> Void

  @FocusState private var isFocused: Bool

  private let palette: [RGBAColor] = [
    RGBAColor(red: 0.95, green: 0.23, blue: 0.21, alpha: 1),
    RGBAColor(red: 0.98, green: 0.55, blue: 0.09, alpha: 1),
    RGBAColor(red: 0.20, green: 0.60, blue: 0.95, alpha: 1),
    RGBAColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1),
    RGBAColor(red: 0.61, green: 0.35, blue: 0.71, alpha: 1),
    RGBAColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text("\(displayNumber)")
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .frame(width: 22, height: 22)
          .background(Circle().fill(color.color))

        Text(NotinhasL10n.noteEditorTitle)
          .font(.system(size: 13, weight: .semibold))

        Spacer(minLength: 0)

        Menu {
          ForEach(Array(palette.enumerated()), id: \.offset) { index, swatch in
            Button {
              color = swatch
            } label: {
              Label {
                Text(NotinhasL10n.colorSwatch(index + 1))
              } icon: {
                Circle()
                  .fill(swatch.color)
                  .frame(width: 14, height: 14)
              }
            }
          }
        } label: {
          Circle()
            .fill(color.color)
            .frame(width: 22, height: 22)
            .overlay {
              Circle()
                .stroke(Color.primary.opacity(0.25), lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(NotinhasL10n.noteEditorColorButton)
      }

      TextField(NotinhasL10n.noteEditorPlaceholder, text: $text, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3 ... 6)
        .frame(minHeight: 60)
        .focused($isFocused)
        .onSubmit(onCommit)

      if showsAreaStyle {
        Picker(NotinhasL10n.areaStylePickerLabel, selection: $areaStyle) {
          Text(NotinhasL10n.areaStyleOutline).tag(NotinhasAreaStyle.outline)
          Text(NotinhasL10n.areaStyleTinted).tag(NotinhasAreaStyle.tinted)
          Text(NotinhasL10n.areaStyleHatched).tag(NotinhasAreaStyle.hatched)
        }
        .pickerStyle(.segmented)
      }

      HStack {
        Button(role: .destructive) { onDelete() } label: {
          Image(systemName: "trash")
        }
        .help(NotinhasL10n.deleteNote)
        .accessibilityLabel(NotinhasL10n.deleteNote)

        Spacer()

        Button(NotinhasL10n.cancel) { onCancel() }
          .keyboardShortcut(.cancelAction)
        Button(NotinhasL10n.save) { onCommit() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(12)
    .frame(width: 300)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .onAppear { isFocused = true }
  }
}
