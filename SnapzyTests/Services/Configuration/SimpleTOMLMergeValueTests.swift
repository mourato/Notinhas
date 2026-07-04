//
//  SimpleTOMLMergeValueTests.swift
//  SnapzyTests
//
//  Tests for SimpleTOMLValue.merging(override:warnings:keyPath:) — value-level merge and type mismatch.
//

import XCTest
@testable import Snapzy

final class SimpleTOMLMergeValueTests: XCTestCase {

  // MARK: - SimpleTOMLValue.merging direct

  func testTableMergeRecurses() {
    let base = SimpleTOMLValue.table(["a": .string("base"), "b": .bool(true)])
    let override = SimpleTOMLValue.table(["a": .string("user")])
    var warnings: [String] = []

    let result = base.merging(override: override, warnings: &warnings, keyPath: ["root"])

    if case .table(let dict) = result {
      XCTAssertEqual(dict["a"]?.stringValue, "user")
      XCTAssertEqual(dict["b"]?.boolValue, true)
    } else {
      XCTFail("Expected table")
    }
    XCTAssertTrue(warnings.isEmpty)
  }

  func testScalarReplacesScalar() {
    let base = SimpleTOMLValue.string("old")
    let override = SimpleTOMLValue.string("new")
    var warnings: [String] = []

    let result = base.merging(override: override, warnings: &warnings, keyPath: ["key"])

    XCTAssertEqual(result.stringValue, "new")
    XCTAssertTrue(warnings.isEmpty)
  }

  func testArrayReplacesArray() {
    let base = SimpleTOMLValue.array([.string("a"), .string("b")])
    let override = SimpleTOMLValue.array([.string("c")])
    var warnings: [String] = []

    let result = base.merging(override: override, warnings: &warnings, keyPath: ["arr"])

    if case .array(let items) = result {
      XCTAssertEqual(items.count, 1)
      XCTAssertEqual(items[0].stringValue, "c")
    } else {
      XCTFail("Expected array")
    }
    XCTAssertTrue(warnings.isEmpty)
  }

  // MARK: - Type mismatch

  func testTypeMismatchUserWinsAndWarns() throws {
    let base = try SimpleTOMLParser.parse("""
    [general]
    play_sounds = true
    """)
    let override = try SimpleTOMLParser.parse("""
    [general]
    play_sounds = 1
    """)

    let (merged, warnings) = base.merging(override: override)

    XCTAssertEqual(merged.value(at: "general", "play_sounds")?.intValue, 1)
    XCTAssertEqual(warnings.count, 1)
    XCTAssertTrue(warnings[0].contains("general.play_sounds"), "Expected key path in warning: \(warnings[0])")
    XCTAssertTrue(warnings[0].contains("bool"), "Expected 'bool' in warning: \(warnings[0])")
    XCTAssertTrue(warnings[0].contains("integer"), "Expected 'integer' in warning: \(warnings[0])")
  }

  func testTypeMismatchScalarVsTableUserWins() {
    let base = SimpleTOMLValue.string("scalar")
    let override = SimpleTOMLValue.table(["key": .string("val")])
    var warnings: [String] = []

    let result = base.merging(override: override, warnings: &warnings, keyPath: ["section"])

    if case .table(let dict) = result {
      XCTAssertEqual(dict["key"]?.stringValue, "val")
    } else {
      XCTFail("Expected table from override")
    }
    XCTAssertEqual(warnings.count, 1)
    XCTAssertTrue(warnings[0].contains("section"))
    XCTAssertTrue(warnings[0].contains("string"))
    XCTAssertTrue(warnings[0].contains("table"))
  }

  func testNoWarningWhenSameType() {
    let base = SimpleTOMLValue.integer(42)
    let override = SimpleTOMLValue.integer(99)
    var warnings: [String] = []

    _ = base.merging(override: override, warnings: &warnings, keyPath: ["fps"])

    XCTAssertTrue(warnings.isEmpty)
  }

  func testKeyPathInWarningIsDotted() {
    let base = SimpleTOMLValue.bool(true)
    let override = SimpleTOMLValue.string("yes")
    var warnings: [String] = []

    _ = base.merging(override: override, warnings: &warnings, keyPath: ["capture", "screenshot", "show_cursor"])

    XCTAssertEqual(warnings.count, 1)
    XCTAssertTrue(warnings[0].contains("capture.screenshot.show_cursor"), "Warning: \(warnings[0])")
  }
}
