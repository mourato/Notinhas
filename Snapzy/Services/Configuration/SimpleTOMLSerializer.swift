//
//  SimpleTOMLSerializer.swift
//  Snapzy
//
//  Serializes a SimpleTOMLDocument back to a TOML-formatted string.
//  Used to write the lean user-config.toml override layer.
//

import Foundation

extension SimpleTOMLDocument {
  /// Serialize this document to TOML.
  /// Root-level scalars are emitted first; tables become `[section]` headers.
  /// Key order within each level is sorted for deterministic output.
  func toTOML() -> String {
    var lines: [String] = []
    SimpleTOMLSerializer.appendScalars(from: root, to: &lines)
    SimpleTOMLSerializer.appendSections(from: root, prefix: [], to: &lines)
    if lines.isEmpty { return "\n" }
    return lines.joined(separator: "\n") + "\n"
  }
}

enum SimpleTOMLSerializer {
  static func appendScalars(
    from table: [String: SimpleTOMLValue],
    to lines: inout [String]
  ) {
    for key in table.keys.sorted() {
      switch table[key]! {
      case .table:
        break
      default:
        if let valueStr = inlineValue(table[key]!) {
          lines.append("\(key) = \(valueStr)")
        }
      }
    }
  }

  static func appendSections(
    from table: [String: SimpleTOMLValue],
    prefix: [String],
    to lines: inout [String]
  ) {
    for key in table.keys.sorted() {
      guard case .table(let child) = table[key] else { continue }
      let sectionPath = (prefix + [key]).joined(separator: ".")
      if !lines.isEmpty, lines.last != "" { lines.append("") }
      lines.append("[\(sectionPath)]")
      appendScalars(from: child, to: &lines)
      appendSections(from: child, prefix: prefix + [key], to: &lines)
    }
  }

  /// Returns the inline TOML string for a scalar/array value, nil for tables.
  static func inlineValue(_ value: SimpleTOMLValue) -> String? {
    switch value {
    case .string(let s): return quoteString(s)
    case .bool(let b):   return b ? "true" : "false"
    case .integer(let i): return "\(i)"
    case .double(let d):
      let formatted = d.rounded() == d ? String(format: "%.1f", d) : "\(d)"
      return formatted
    case .array(let items):
      let encoded = items.compactMap { inlineValue($0) }.joined(separator: ", ")
      return "[\(encoded)]"
    case .table:
      return nil
    }
  }

  private static func quoteString(_ s: String) -> String {
    let escaped = s
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\t", with: "\\t")
    return "\"\(escaped)\""
  }
}
