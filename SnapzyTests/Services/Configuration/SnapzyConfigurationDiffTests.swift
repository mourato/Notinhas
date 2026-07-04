//
//  SnapzyConfigurationDiffTests.swift
//  SnapzyTests
//
//  Tests for leaf-level dotted-key diff (Phase 04, reused by Phase 06).
//

import XCTest
@testable import Snapzy

final class SnapzyConfigurationDiffTests: XCTestCase {

  private func doc(_ root: [String: SimpleTOMLValue]) -> SimpleTOMLDocument {
    SimpleTOMLDocument(root: root)
  }

  func testIdenticalDocsProduceNoDiff() {
    let base = doc(["a": .string("x"), "b": .bool(true)])
    let entries = SnapzyConfigurationDiff.diff(base: base, override: base)
    XCTAssertTrue(entries.isEmpty)
  }

  func testChangedLeafProducesEntry() {
    let base     = doc(["a": .string("old")])
    let override = doc(["a": .string("new")])
    let entries  = SnapzyConfigurationDiff.diff(base: base, override: override)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].dottedKey, "a")
    XCTAssertEqual(entries[0].baseValue, .string("old"))
    XCTAssertEqual(entries[0].overrideValue, .string("new"))
    XCTAssertTrue(entries[0].isChanged)
  }

  func testKeyOnlyInOverrideIsReported() {
    let base     = doc([:])
    let override = doc(["x": .integer(1)])
    let entries  = SnapzyConfigurationDiff.diff(base: base, override: override)
    XCTAssertEqual(entries.count, 1)
    XCTAssertTrue(entries[0].isOnlyInOverride)
  }

  func testKeyOnlyInBaseIsReported() {
    let base     = doc(["y": .bool(false)])
    let override = doc([:])
    let entries  = SnapzyConfigurationDiff.diff(base: base, override: override)
    XCTAssertEqual(entries.count, 1)
    XCTAssertTrue(entries[0].isOnlyInBase)
  }

  func testNestedTablesDiffedRecursively() {
    let base     = SimpleTOMLDocument(root: ["cap": .table(["fmt": .string("png")])])
    let override = SimpleTOMLDocument(root: ["cap": .table(["fmt": .string("webp")])])
    let entries  = SnapzyConfigurationDiff.diff(base: base, override: override)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].dottedKey, "cap.fmt")
    XCTAssertTrue(entries[0].isChanged)
  }

  func testUnchangedNestedKeyNotIncluded() {
    let tableVal: [String: SimpleTOMLValue] = ["fmt": .string("png"), "cursor": .bool(true)]
    let base     = SimpleTOMLDocument(root: ["cap": .table(tableVal)])
    let override = SimpleTOMLDocument(root: ["cap": .table(["fmt": .string("webp"), "cursor": .bool(true)])])
    let entries  = SnapzyConfigurationDiff.diff(base: base, override: override)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].dottedKey, "cap.fmt")
  }

  func testDottedKeyFormatIsCorrect() {
    let base     = SimpleTOMLDocument(root: ["a": .table(["b": .table(["c": .integer(1)])])])
    let override = SimpleTOMLDocument(root: ["a": .table(["b": .table(["c": .integer(2)])])])
    let entries  = SnapzyConfigurationDiff.diff(base: base, override: override)
    XCTAssertEqual(entries.first?.dottedKey, "a.b.c")
  }
}
