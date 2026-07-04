//
//  SnapzyConfigurationWriteRouterTests.swift
//  SnapzyTests
//
//  Tests for write-routing modes (Phase 04).
//

import XCTest
@testable import Snapzy

final class SnapzyConfigurationWriteRouterTests: XCTestCase {

  // MARK: - Helpers

  private func doc(_ pairs: [String: SimpleTOMLValue]) -> SimpleTOMLDocument {
    SimpleTOMLDocument(root: pairs)
  }

  private func nestedDoc(_ section: String, _ pairs: [String: SimpleTOMLValue]) -> SimpleTOMLDocument {
    SimpleTOMLDocument(root: [section: .table(pairs)])
  }

  // MARK: - perKey mode

  func testPerKeyNeverWritesBuiltIn() {
    let current = doc(["a": .string("new")])
    let builtIn = doc(["a": .string("old")])
    let userConfig = SimpleTOMLDocument()  // empty

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current, builtInDoc: builtIn, userConfigDoc: userConfig, mode: .perKey)

    XCTAssertFalse(routing.shouldWriteBuiltIn)
  }

  func testPerKeyDoesNotWriteUserConfigWhenEmpty() {
    let current = doc(["a": .string("new")])
    let builtIn = doc(["a": .string("old")])
    let userConfig = SimpleTOMLDocument()

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current, builtInDoc: builtIn, userConfigDoc: userConfig, mode: .perKey)

    XCTAssertNil(routing.userConfigDoc)
  }

  func testPerKeyUpdatesExistingUserConfigKeys() throws {
    let current = nestedDoc("capture", ["format": .string("webp"), "cursor": .bool(false)])
    let builtIn  = nestedDoc("capture", ["format": .string("png"),  "cursor": .bool(true)])
    let userConfig = nestedDoc("capture", ["format": .string("png")])  // only format in user-config

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current, builtInDoc: builtIn, userConfigDoc: userConfig, mode: .perKey)

    XCTAssertFalse(routing.shouldWriteBuiltIn)
    let updatedUser = try XCTUnwrap(routing.userConfigDoc)
    // format key exists in user-config → updated to "webp"
    XCTAssertEqual(updatedUser.value(at: "capture", "format")?.stringValue, "webp")
    // cursor does NOT exist in user-config → absent from user update
    XCTAssertNil(updatedUser.value(at: "capture", "cursor"))
  }

  func testPerKeyDoesNotAddNewKeysToUserConfig() {
    let current = nestedDoc("capture", ["format": .string("webp"), "quality": .integer(90)])
    let userConfig = nestedDoc("capture", ["format": .string("png")])  // only format

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current, builtInDoc: SimpleTOMLDocument(), userConfigDoc: userConfig, mode: .perKey)

    // quality is not in user-config → must not appear in the routed user doc
    XCTAssertNil(routing.userConfigDoc?.value(at: "capture", "quality"))
  }

  // MARK: - primary mode

  func testPrimaryNeverWritesBuiltIn() {
    let current = doc(["a": .string("new")])
    let builtIn  = doc(["a": .string("old")])

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current, builtInDoc: builtIn, userConfigDoc: SimpleTOMLDocument(), mode: .primary)

    XCTAssertFalse(routing.shouldWriteBuiltIn)
  }

  func testPrimaryWritesChangedKeysToUserConfig() throws {
    let current  = nestedDoc("capture", ["format": .string("webp"), "cursor": .bool(true)])
    let builtIn  = nestedDoc("capture", ["format": .string("png"),  "cursor": .bool(true)])
    // cursor unchanged → should NOT appear in user-config

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current, builtInDoc: builtIn, userConfigDoc: SimpleTOMLDocument(), mode: .primary)

    let userDoc = try XCTUnwrap(routing.userConfigDoc)
    XCTAssertEqual(userDoc.value(at: "capture", "format")?.stringValue, "webp", "changed key present")
    XCTAssertNil(userDoc.value(at: "capture", "cursor"), "unchanged key absent (lean)")
  }

  func testPrimaryAccumulatesChangedKeysIntoExistingUserConfig() throws {
    let current = nestedDoc("capture", ["format": .string("webp"), "quality": .integer(80)])
    let builtIn  = nestedDoc("capture", ["format": .string("png"),  "quality": .integer(90)])
    // Pre-existing user override for quality
    let existingUser = nestedDoc("capture", ["quality": .integer(75)])

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current, builtInDoc: builtIn, userConfigDoc: existingUser, mode: .primary)

    let userDoc = try XCTUnwrap(routing.userConfigDoc)
    XCTAssertEqual(userDoc.value(at: "capture", "format")?.stringValue, "webp", "new changed key added")
    XCTAssertEqual(userDoc.value(at: "capture", "quality")?.intValue, 80, "existing key updated from current")
  }

  func testPrimaryUserConfigIsLeanNeverAFullExport() throws {
    // current has many keys, only one differs from built-in
    let currentRoot: [String: SimpleTOMLValue] = [
      "a": .string("same"),
      "b": .integer(1),
      "c": .bool(true),
      "d": .string("CHANGED"),
    ]
    let builtInRoot: [String: SimpleTOMLValue] = [
      "a": .string("same"),
      "b": .integer(1),
      "c": .bool(true),
      "d": .string("original"),
    ]
    let current = SimpleTOMLDocument(root: currentRoot)
    let builtIn = SimpleTOMLDocument(root: builtInRoot)

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current, builtInDoc: builtIn, userConfigDoc: SimpleTOMLDocument(), mode: .primary)

    let userDoc = try XCTUnwrap(routing.userConfigDoc)
    let leafKeys = SnapzyConfigurationWriteRouter.leafKeys(in: userDoc.root)
    XCTAssertEqual(leafKeys.count, 1, "lean: only 1 changed key written")
    XCTAssertEqual(userDoc.value(at: "d")?.stringValue, "CHANGED")
  }
}
