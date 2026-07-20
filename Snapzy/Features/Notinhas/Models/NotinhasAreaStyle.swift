//
//  NotinhasAreaStyle.swift
//  Snapzy
//
//  Visual styles for rectangular Notinhas notes.
//

import Foundation

nonisolated enum NotinhasAreaStyle: String, Codable, CaseIterable, Equatable, Identifiable {
  case outline
  case tinted
  case hatched

  var id: String {
    rawValue
  }

  static let `default` = NotinhasAreaStyle.outline
}
