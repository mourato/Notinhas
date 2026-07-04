//
//  SimpleTOMLMergeDocumentTests.swift
//  SnapzyTests
//
//  Tests for SimpleTOMLDocument.merging(override:) — document-level deep-merge.
//

import XCTest
@testable import Snapzy

final class SimpleTOMLMergeDocumentTests: XCTestCase {

  func testEmptyOverrideReturnsCopyOfBase() throws {
    let base = try SimpleTOMLParser.parse("""
    schema_version = 1
    [general]
    language = "en"
    play_sounds = true
    """)
    let override = SimpleTOMLDocument()

    let (merged, warnings) = base.merging(override: override)

    XCTAssertEqual(merged.value(at: "schema_version")?.intValue, 1)
    XCTAssertEqual(merged.value(at: "general", "language")?.stringValue, "en")
    XCTAssertEqual(merged.value(at: "general", "play_sounds")?.boolValue, true)
    XCTAssertTrue(warnings.isEmpty)
  }

  func testUserOverridesScalarLeaf() throws {
    let base = try SimpleTOMLParser.parse("""
    [general]
    language = "en"
    play_sounds = true
    """)
    let override = try SimpleTOMLParser.parse("""
    [general]
    language = "vi"
    """)

    let (merged, warnings) = base.merging(override: override)

    XCTAssertEqual(merged.value(at: "general", "language")?.stringValue, "vi")
    XCTAssertEqual(merged.value(at: "general", "play_sounds")?.boolValue, true)
    XCTAssertTrue(warnings.isEmpty)
  }

  func testUserOnlyKeyAddedToMerged() throws {
    let base = try SimpleTOMLParser.parse("""
    [general]
    language = "en"
    """)
    let override = try SimpleTOMLParser.parse("""
    [general]
    appearance = "dark"
    """)

    let (merged, warnings) = base.merging(override: override)

    XCTAssertEqual(merged.value(at: "general", "language")?.stringValue, "en")
    XCTAssertEqual(merged.value(at: "general", "appearance")?.stringValue, "dark")
    XCTAssertTrue(warnings.isEmpty)
  }

  func testArrayReplaces() throws {
    let base = try SimpleTOMLParser.parse("""
    [quick_access]
    actions_order = ["copy", "edit"]
    """)
    let override = try SimpleTOMLParser.parse("""
    [quick_access]
    actions_order = ["delete"]
    """)

    let (merged, warnings) = base.merging(override: override)

    XCTAssertEqual(merged.value(at: "quick_access", "actions_order")?.stringArrayValue, ["delete"])
    XCTAssertTrue(warnings.isEmpty)
  }

  func testNestedTablesMergeRecursively() throws {
    let base = try SimpleTOMLParser.parse("""
    [capture.screenshot]
    format = "png"
    show_cursor = false

    [capture.naming]
    screenshot_template = "base_template"
    """)
    let override = try SimpleTOMLParser.parse("""
    [capture.screenshot]
    format = "webp"

    [capture.naming]
    recording_template = "user_recording"
    """)

    let (merged, warnings) = base.merging(override: override)

    XCTAssertEqual(merged.value(at: "capture", "screenshot", "format")?.stringValue, "webp")
    XCTAssertEqual(merged.value(at: "capture", "screenshot", "show_cursor")?.boolValue, false)
    XCTAssertEqual(merged.value(at: "capture", "naming", "screenshot_template")?.stringValue, "base_template")
    XCTAssertEqual(merged.value(at: "capture", "naming", "recording_template")?.stringValue, "user_recording")
    XCTAssertTrue(warnings.isEmpty)
  }

  func testThreeLevelNestedMerge() throws {
    let base = try SimpleTOMLParser.parse("""
    [shortcuts.global.fullscreen]
    key = "3"
    modifiers = ["command", "shift"]
    enabled = true
    """)
    let override = try SimpleTOMLParser.parse("""
    [shortcuts.global.fullscreen]
    key = "4"
    """)

    let (merged, warnings) = base.merging(override: override)

    XCTAssertEqual(merged.value(at: "shortcuts", "global", "fullscreen", "key")?.stringValue, "4")
    XCTAssertEqual(merged.value(at: "shortcuts", "global", "fullscreen", "enabled")?.boolValue, true)
    XCTAssertTrue(warnings.isEmpty)
  }

  func testRootLevelScalarMerge() throws {
    let base = try SimpleTOMLParser.parse("""
    schema_version = 1
    snapzy_min_version = "1.20.0"
    """)
    let override = try SimpleTOMLParser.parse("""
    schema_version = 1
    """)

    let (merged, warnings) = base.merging(override: override)

    XCTAssertEqual(merged.value(at: "schema_version")?.intValue, 1)
    XCTAssertEqual(merged.value(at: "snapzy_min_version")?.stringValue, "1.20.0")
    XCTAssertTrue(warnings.isEmpty)
  }
}
