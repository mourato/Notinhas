//
//  PreferencesAnnotateSettingsView.swift
//  Snapzy
//
//  Annotate preferences tab for editor behavior settings.
//

import SwiftUI

struct AnnotateSettingsView: View {
  @AppStorage(PreferencesKeys.annotateClipboardImageOpenBehavior)
  private var annotateClipboardImageOpenBehavior = AnnotateClipboardImageBehavior.ask.rawValue
  @AppStorage(PreferencesKeys.annotateCloseAfterDrag) private var annotateCloseAfterDrag = true
  @AppStorage(PreferencesKeys.annotateBringForwardAfterDrag)
  private var annotateBringForwardAfterDrag = false
  @AppStorage(PreferencesKeys.annotateQuickPropertiesSyncEnabled)
  private var annotateQuickPropertiesSyncEnabled = true
  @AppStorage(PreferencesKeys.annotateCombineSaveAsEdit)
  private var annotateCombineSaveAsEdit = true
  @AppStorage(PreferencesKeys.notinhasImgurClientID) private var notinhasImgurClientID = ""
  @AppStorage(PreferencesKeys.notinhasNotesPanelSide) private var notinhasNotesPanelSide = NotinhasNotesPanelSide.default.rawValue

  var body: some View {
    Form {
      Section(L10n.PreferencesAnnotate.behaviorSection) {
        SettingRow(
          icon: "slider.horizontal.3",
          title: L10n.PreferencesAnnotate.quickPropertiesSyncTitle,
          description: L10n.PreferencesAnnotate.quickPropertiesSyncDescription
        ) {
          Toggle("", isOn: $annotateQuickPropertiesSyncEnabled)
            .labelsHidden()
        }

        SettingRow(
          icon: "rectangle.stack",
          title: L10n.PreferencesAnnotate.combineSaveAsEditTitle,
          description: L10n.PreferencesAnnotate.combineSaveAsEditDescription
        ) {
          Toggle("", isOn: $annotateCombineSaveAsEdit)
            .labelsHidden()
        }

        SettingRow(
          icon: "doc.on.clipboard",
          title: L10n.PreferencesAnnotate.clipboardTitle,
          description: L10n.PreferencesAnnotate.clipboardDescription
        ) {
          Picker("", selection: $annotateClipboardImageOpenBehavior) {
            ForEach(AnnotateClipboardImageBehavior.allCases) { behavior in
              Text(behavior.displayName).tag(behavior.rawValue)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .fixedSize()
          .frame(width: 180, alignment: .trailing)
        }

        SettingRow(
          icon: "arrow.up.forward.app",
          title: L10n.PreferencesAnnotate.closeAfterDragTitle,
          description: L10n.PreferencesAnnotate.closeAfterDragDescription
        ) {
          Toggle("", isOn: $annotateCloseAfterDrag)
            .labelsHidden()
        }

        SettingRow(
          icon: "macwindow",
          title: L10n.PreferencesAnnotate.bringForwardAfterDragTitle,
          description: L10n.PreferencesAnnotate.bringForwardAfterDragDescription
        ) {
          Toggle("", isOn: $annotateBringForwardAfterDrag)
            .labelsHidden()
        }
        .disabled(annotateCloseAfterDrag)
      }

      Section(NotinhasL10n.settingsSection) {
        SettingRow(
          icon: "sidebar.left",
          title: NotinhasL10n.panelSideTitle,
          description: NotinhasL10n.panelSideDescription
        ) {
          Picker("", selection: $notinhasNotesPanelSide) {
            Text(NotinhasL10n.left).tag(NotinhasNotesPanelSide.left.rawValue)
            Text(NotinhasL10n.right).tag(NotinhasNotesPanelSide.right.rawValue)
          }
          .labelsHidden()
          .pickerStyle(.segmented)
          .frame(width: 180, alignment: .trailing)
        }

        SettingRow(
          icon: "photo.on.rectangle.angled",
          title: NotinhasL10n.imgurClientIDTitle,
          description: NotinhasL10n.imgurClientIDHelp
        ) {
          TextField(
            NotinhasL10n.imgurClientIDPlaceholder,
            text: $notinhasImgurClientID
          )
            .textFieldStyle(.roundedBorder)
            .frame(width: 180)
        }
      }
    }
    .formStyle(.grouped)
    .onAppear {
      NotinhasImgurConfiguration.migratePanelSideIfNeeded()
    }
  }
}

#Preview {
  AnnotateSettingsView()
    .frame(width: 600, height: 550)
}
