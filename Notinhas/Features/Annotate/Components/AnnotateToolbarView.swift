//
//  AnnotateToolbarView.swift
//  Notinhas
//
//  Top toolbar with annotation tools and actions
//

import SwiftUI

private enum AnnotateToolbarActionRegistration: Equatable {
  case annotateDefault
  case crop
}

/// Top toolbar containing all annotation tools
struct AnnotateToolbarView: View {
  @ObservedObject var state: AnnotateState
  @ObservedObject private var annotateShortcutManager = AnnotateShortcutManager.shared
  @AppStorage(PreferencesKeys.backgroundCutoutAutoCropEnabled) private var backgroundCutoutAutoCropEnabled = true

  var body: some View {
    HStack(spacing: WindowSpacingConfiguration.default.toolbarItemSpacing) {
      // Add spacer for traffic lights
      Spacer().frame(width: 0)

      // Undo/Redo
      undoRedoGroup

      ToolbarDivider()

      // Left group: Capture tools
      captureToolsGroup

      ToolbarDivider()

      // Center group: Annotation tools
      annotationToolsGroup

      if state.isCombineMode {
        ToolbarDivider()

        ToolbarButton(icon: "photo.badge.plus", isSelected: false) {
          guard let window = NSApp.keyWindow else { return }
          NotificationCenter.default.post(name: .annotateAddImage, object: window)
        }
        .help(L10n.Combine.pickerTitle)

        ToolbarDivider()
      }

      Spacer()

      registeredActionButtons
    }
    .windowTrafficLightsInset()
    .windowToolbarPadding()
    .animation(.easeInOut(duration: 0.16), value: activeActionRegistration)
    .alert(
      L10n.AnnotateUI.backgroundCutoutTitle,
      isPresented: Binding(
        get: { state.cutoutErrorMessage != nil },
        set: {
          if !$0 {
            state.cutoutErrorMessage = nil
          }
        }
      )
    ) {
      Button(L10n.Common.ok, role: .cancel) {}
    } message: {
      Text(state.cutoutErrorMessage ?? L10n.AnnotateUI.unableToRemoveBackground)
    }
  }

  // MARK: - Tool Groups

  private var captureToolsGroup: some View {
    let cropTitle = L10n.AnnotateUI.crop
    let cropKeys = AnnotateOverlayTooltipKeys.toolKeys(for: .crop, manager: annotateShortcutManager)
    let sidebarTitle = L10n.AnnotateUI.toggleSidebar
    let sidebarKeys = AnnotateOverlayTooltipKeys.actionKeys(
      for: .toggleSidebar,
      manager: annotateShortcutManager
    )

    return HStack(spacing: 4) {
      ToolbarButton(
        icon: "crop",
        isSelected: state.selectedTool == .crop
      ) {
        state.beginCropInteraction()
      }
      .overlayTooltip(cropTitle, keys: cropKeys, edge: .below)
      .accessibilityLabel(accessibilityTitle(cropTitle, keys: cropKeys))

      ToolbarButton(
        icon: "rectangle.on.rectangle",
        isSelected: state.showSidebar,
        highlightColor: .blue
      ) {
        state.toggleSidebarVisibility()
      }
      .overlayTooltip(sidebarTitle, keys: sidebarKeys, edge: .below)
      .accessibilityLabel(accessibilityTitle(sidebarTitle, keys: sidebarKeys))

      ToolbarDivider()

      rotateButtonsGroup
    }
  }

  private var rotateButtonsGroup: some View {
    HStack(spacing: 4) {
      ToolbarButton(icon: "rotate.left", isSelected: false) {
        state.rotateImage(clockwise: false)
      }
      .help(L10n.AnnotateUI.rotateLeft)
      .disabled(!state.canRotateImage)
      .opacity(state.canRotateImage ? 1 : 0.4)

      ToolbarButton(icon: "rotate.right", isSelected: false) {
        state.rotateImage(clockwise: true)
      }
      .help(L10n.AnnotateUI.rotateRight)
      .disabled(!state.canRotateImage)
      .opacity(state.canRotateImage ? 1 : 0.4)
    }
  }

  private var annotationToolsGroup: some View {
    HStack(spacing: 4) {
      annotationToolButton(for: .selection)

      ForEach(drawingTools, id: \.self) { tool in
        annotationToolButton(for: tool)
        if tool == .counter {
          notinhasNoteButton
        }
      }

      backgroundCutoutButton
        .padding(.leading, 2)
    }
  }

  private var drawingTools: [AnnotationToolType] {
    AnnotationToolType.drawableTools
  }

  private var notinhasNoteButton: some View {
    ToolbarButton(
      icon: AnnotationToolType.notinhasNote.icon,
      isSelected: state.selectedTool == .notinhasNote
    ) {
      state.activateTool(.notinhasNote)
    }
    .disabled(state.editorMode == .mockup)
    .opacity(state.editorMode == .mockup ? 0.4 : 1)
    .overlayTooltip(
      NotinhasL10n.noteTool,
      keys: notinhasNoteShortcutKeys,
      secondary: NotinhasL10n.noteToolGestureHint,
      edge: .below
    )
    .accessibilityLabel(notinhasNoteAccessibilityLabel)
  }

  /// Keycap symbol for the current note-tool shortcut, or empty when disabled/unset.
  private var notinhasNoteShortcutKeys: [String] {
    AnnotateOverlayTooltipKeys.toolKeys(for: .notinhasNote, manager: annotateShortcutManager)
  }

  /// Spoken label for VoiceOver — includes the shortcut and gesture in words.
  private var notinhasNoteAccessibilityLabel: String {
    let title: String = if let key = notinhasNoteShortcutKeys.first {
      L10n.Common.withShortcut(NotinhasL10n.noteTool, key)
    } else {
      NotinhasL10n.noteTool
    }
    return NotinhasL10n.noteToolTooltip(title: title)
  }

  private var backgroundCutoutButton: some View {
    ToolbarButton(
      icon: state.isCutoutProcessing ? "hourglass" : "wand.and.stars",
      isSelected: state.isCutoutApplied,
      highlightColor: .blue
    ) {
      state.toggleBackgroundCutout()
    }
    .disabled(!state.canUseBackgroundCutout || !state.hasImage || state.isCutoutProcessing)
    .opacity((!state.canUseBackgroundCutout || !state.hasImage) ? 0.4 : 1)
    .help(
      state.canUseBackgroundCutout
        ? (state.isCutoutApplied
          ? L10n.AnnotateUI.backgroundRemovedClickToRestore
          : (backgroundCutoutAutoCropEnabled
            ? L10n.AnnotateUI.removeBackgroundAutoCropsWhenSafe
            : L10n.AnnotateUI.removeBackgroundAutoCropDisabledInSettings))
        : L10n.AnnotateUI.requiresMacOS14OrLater
    )
  }

  private func annotationToolButton(for tool: AnnotationToolType, help: String? = nil) -> some View {
    let title = help ?? tool.displayName
    let keys = AnnotateOverlayTooltipKeys.toolKeys(for: tool, manager: annotateShortcutManager)
    return ToolbarButton(
      icon: tool.icon,
      isSelected: state.selectedTool == tool
    ) {
      state.activateTool(tool)
    }
    .overlayTooltip(title, keys: keys, edge: .below)
    .accessibilityLabel(accessibilityTitle(title, keys: keys))
    .disabled(state.editorMode == .mockup && tool != .selection)
    .opacity(state.editorMode == .mockup && tool != .selection ? 0.4 : 1)
  }

  private var undoRedoGroup: some View {
    let undoKeys = ["⌘", "Z"]
    let redoKeys = ["⌘", "⇧", "Z"]

    return HStack(spacing: 4) {
      ToolbarButton(icon: "arrow.uturn.backward", isSelected: false) {
        state.undo()
      }
      .overlayTooltip(L10n.Common.undo, keys: undoKeys, edge: .below)
      .accessibilityLabel(accessibilityTitle(L10n.Common.undo, keys: undoKeys))
      .disabled(!state.canUndo)
      .opacity(state.canUndo ? 1 : 0.4)

      ToolbarButton(icon: "arrow.uturn.forward", isSelected: false) {
        state.redo()
      }
      .overlayTooltip(L10n.Common.redo, keys: redoKeys, edge: .below)
      .accessibilityLabel(accessibilityTitle(L10n.Common.redo, keys: redoKeys))
      .disabled(!state.canRedo)
      .opacity(state.canRedo ? 1 : 0.4)
    }
  }

  private var activeActionRegistration: AnnotateToolbarActionRegistration {
    if state.selectedTool == .crop, state.isCropActive {
      return .crop
    }

    return .annotateDefault
  }

  @ViewBuilder
  private var registeredActionButtons: some View {
    switch activeActionRegistration {
    case .annotateDefault:
      annotateActionButtons
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    case .crop:
      cropActionButtons
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
  }

  private var annotateActionButtons: some View {
    let saveAsKeys = ["⌘", "⇧", "S"]
    let doneKeys = ["⌘", "S"]

    return HStack(spacing: 8) {
      Button(L10n.Common.saveAs) {
        saveAs()
      }
      .buttonStyle(.bordered)
      .overlayTooltip(L10n.Common.saveAs, keys: saveAsKeys, edge: .below)
      .accessibilityLabel(accessibilityTitle(L10n.Common.saveAs, keys: saveAsKeys))

      Button(L10n.Common.done) {
        done()
      }
      .buttonStyle(.borderedProminent)
      .tint(.blue)
      .overlayTooltip(L10n.Common.done, keys: doneKeys, edge: .below)
      .accessibilityLabel(accessibilityTitle(L10n.Common.done, keys: doneKeys))
    }
  }

  private var cropActionButtons: some View {
    let restoreTitle = "\(L10n.Common.restore) \(L10n.Common.original)"
    let cancelKeys = ["esc"]
    let applyKeys = ["⏎"]

    return HStack(spacing: 8) {
      Button(restoreTitle) {
        state.revertCropToOriginalBounds()
      }
      .buttonStyle(.bordered)
      .overlayTooltip(restoreTitle, edge: .below)

      Button(L10n.Common.cancel) {
        state.cancelCrop()
      }
      .buttonStyle(.bordered)
      .overlayTooltip(L10n.Common.cancel, keys: cancelKeys, edge: .below)
      .accessibilityLabel(accessibilityTitle(L10n.Common.cancel, keys: cancelKeys))

      Button(L10n.Common.apply) {
        state.confirmCropInteraction()
      }
      .buttonStyle(.borderedProminent)
      .tint(.blue)
      .overlayTooltip(L10n.Common.apply, keys: applyKeys, edge: .below)
      .accessibilityLabel(accessibilityTitle(L10n.Common.apply, keys: applyKeys))
    }
  }

  // MARK: - Actions

  private func accessibilityTitle(_ title: String, keys: [String]) -> String {
    guard !keys.isEmpty else { return title }
    let shortcut = keys.joined(separator: "")
    return L10n.Common.withShortcut(title, shortcut)
  }

  private func saveAs() {
    if state.isCombineMode {
      guard let window = NSApp.keyWindow else { return }
      NotificationCenter.default.post(name: .annotateSave, object: window)
    } else {
      AnnotateExporter.saveAs(state: state, closeWindow: true)
    }
  }

  private func done() {
    // Post save notification — controller handles silent save + cache + QA refresh + close
    guard let window = NSApp.keyWindow else { return }
    NotificationCenter.default.post(name: .annotateSave, object: window)
  }
}
