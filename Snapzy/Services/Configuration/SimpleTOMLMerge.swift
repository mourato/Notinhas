//
//  SimpleTOMLMerge.swift
//  Snapzy
//
//  Deep-merge two TOML documents: base + override.
//  Both `.table` → recurse children. Arrays and scalars → override replaces base.
//

extension SimpleTOMLValue {
  /// Returns a new value = `self` (base) with `override` deep-merged on top.
  /// Type mismatch: override wins; a warning is appended with the dotted key path.
  func merging(
    override: SimpleTOMLValue,
    warnings: inout [String],
    keyPath: [String] = []
  ) -> SimpleTOMLValue {
    if case .table(let baseDict) = self, case .table(let overrideDict) = override {
      var merged = baseDict
      for (key, overrideValue) in overrideDict {
        let childPath = keyPath + [key]
        if let baseValue = baseDict[key] {
          merged[key] = baseValue.merging(override: overrideValue, warnings: &warnings, keyPath: childPath)
        } else {
          merged[key] = overrideValue
        }
      }
      return .table(merged)
    }

    if !isSameCase(as: override) {
      let dotted = keyPath.isEmpty ? "<root>" : keyPath.joined(separator: ".")
      warnings.append("type override at \(dotted): \(caseName) -> \(override.caseName)")
    }

    return override
  }

  private func isSameCase(as other: SimpleTOMLValue) -> Bool {
    switch (self, other) {
    case (.string, .string), (.bool, .bool), (.integer, .integer),
         (.double, .double), (.array, .array), (.table, .table):
      return true
    default:
      return false
    }
  }

  var caseName: String {
    switch self {
    case .string: return "string"
    case .bool: return "bool"
    case .integer: return "integer"
    case .double: return "double"
    case .array: return "array"
    case .table: return "table"
    }
  }
}

extension SimpleTOMLDocument {
  /// Returns a new document = `self` (base) with `override` deep-merged on top.
  /// Keys absent in `override` are kept from base unchanged.
  func merging(override: SimpleTOMLDocument) -> (document: SimpleTOMLDocument, warnings: [String]) {
    var warnings: [String] = []
    var mergedRoot = root

    for (key, overrideValue) in override.root {
      if let baseValue = root[key] {
        mergedRoot[key] = baseValue.merging(override: overrideValue, warnings: &warnings, keyPath: [key])
      } else {
        mergedRoot[key] = overrideValue
      }
    }

    return (SimpleTOMLDocument(root: mergedRoot), warnings)
  }
}
