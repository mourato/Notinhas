//
//  OverlayTooltipPresenterTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

@MainActor
final class OverlayTooltipPresenterTests: XCTestCase {
  private var presenter: OverlayTooltipPresenter!

  override func setUp() async throws {
    try await super.setUp()
    presenter = OverlayTooltipPresenter.shared
  }

  func testHide_onlyHidesForMatchingOwner() {
    let ownerA = UUID()
    let ownerB = UUID()
    let content = OverlayTooltipContent(title: "Test", keys: ["R"])
    let anchor = CGRect(x: 200, y: 200, width: 40, height: 28)

    presenter.show(content, anchorScreenFrame: anchor, preferred: .below, owner: ownerA)
    XCTAssertEqual(presenter.testingCurrentOwner, ownerA)

    presenter.hide(owner: ownerB)
    XCTAssertEqual(presenter.testingCurrentOwner, ownerA, "hide from non-owner must not clear tooltip")

    presenter.hide(owner: ownerA)
    XCTAssertNil(presenter.testingCurrentOwner, "hide from current owner must clear tooltip")
  }
}
