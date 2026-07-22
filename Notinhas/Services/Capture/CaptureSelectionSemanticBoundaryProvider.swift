//
//  CaptureSelectionSemanticBoundaryProvider.swift
//  Notinhas
//
//  Non-prompting semantic boundary lookup for capture selection snapping.
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
protocol CaptureSelectionSemanticBoundaryProviding: AnyObject {
  func semanticRect(at screenPoint: CGPoint, ownerPID: Int32?) -> CGRect?
  func semanticCandidates(
    at screenPoint: CGPoint,
    ownerPID: Int32?,
    handle: CaptureSelectionResizeHandle
  ) -> [CaptureSelectionSnappingCandidate]
  func clearCache()
}

@MainActor
final class CaptureSelectionSemanticBoundaryProvider: CaptureSelectionSemanticBoundaryProviding {
  private let snapshotProvider: AXSnapshotProviding
  private let isTrusted: () -> Bool

  private struct CacheKey: Equatable {
    let quantizedX: Int
    let quantizedY: Int
    let ownerPID: Int32?
  }

  private var cacheKey: CacheKey?
  private var cachedRect: CGRect?

  init(
    snapshotProvider: AXSnapshotProviding = AXAccessibilitySnapshotProvider(),
    isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() }
  ) {
    self.snapshotProvider = snapshotProvider
    self.isTrusted = isTrusted
  }

  func semanticRect(at screenPoint: CGPoint, ownerPID: Int32?) -> CGRect? {
    guard isTrusted() else {
      clearCache()
      return nil
    }

    let key = CacheKey(
      quantizedX: Int(screenPoint.x.rounded()),
      quantizedY: Int(screenPoint.y.rounded()),
      ownerPID: ownerPID
    )

    if cacheKey == key, let cachedRect {
      return cachedRect
    }

    guard
      let snapshot = snapshotProvider.snapshot(at: screenPoint, pid: ownerPID),
      let meaningful = AXElementInspector.findMeaningful(snapshot),
      let rect = AXElementInspector.screenRect(forTopLeftRect: meaningful.rect),
      rect.width > 0,
      rect.height > 0
    else {
      clearCache()
      return nil
    }

    cacheKey = key
    cachedRect = rect
    return rect
  }

  func clearCache() {
    cacheKey = nil
    cachedRect = nil
  }

  func semanticCandidates(
    at screenPoint: CGPoint,
    ownerPID: Int32?,
    handle: CaptureSelectionResizeHandle
  ) -> [CaptureSelectionSnappingCandidate] {
    guard let rect = semanticRect(at: screenPoint, ownerPID: ownerPID) else {
      return []
    }

    let activeEdges = CaptureSelectionSnapping.activeEdges(for: handle)
    return CaptureSelectionSnapping.semanticCandidates(for: rect)
      .filter { activeEdges.contains($0.edge) }
  }
}
