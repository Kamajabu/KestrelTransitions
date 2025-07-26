//
//  KestrelTransitionRegistry.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 26/07/2025.
//

import UIKit
import SwiftUI

// MARK: - Frame Bridge System

/// A UIViewRepresentable that acts as a bridge to communicate frame information from SwiftUI to UIKit
struct KestrelFrameBridge: UIViewRepresentable {
    let transitionId: String
    let frameType: FrameType
    
    enum FrameType {
        case source
        case target
    }
    
    func makeUIView(context: Context) -> KestrelFrameBeaconView {
        let view = KestrelFrameBeaconView()
        view.transitionId = transitionId
        view.frameType = frameType
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: KestrelFrameBeaconView, context: Context) {
        // Update frame information when SwiftUI updates
        DispatchQueue.main.async {
            uiView.reportFrame()
        }
    }
}

/// A UIView that reports its frame to the transition registry
class KestrelFrameBeaconView: UIView {
    var transitionId: String = ""
    var frameType: KestrelFrameBridge.FrameType = .target
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        DispatchQueue.main.async {
            self.reportFrame()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        reportFrame()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        DispatchQueue.main.async {
            self.reportFrame()
        }
    }
    
    func reportFrame() {
        guard !transitionId.isEmpty else { return }
        
        guard let targetView = superview else {
            kestrelLog(
                "Bridge has no superview for id '\(transitionId)'",
                level: .warning,
                context: transitionId
            )
            return
        }
        
        let globalFrame = targetView.superview?.convert(targetView.frame, to: nil) ?? targetView.frame
        
        guard globalFrame.width > 0 && globalFrame.height > 0 else {
            kestrelLog(
                "Bridge found zero-sized frame for id '\(transitionId)', skipping",
                level: .warning,
                context: transitionId
            )
            return
        }
        
        kestrelLog(
            "Bridge reporting \(frameType) frame for id '\(transitionId)': \(globalFrame)",
            level: .debug,
            context: transitionId
        )
        
        switch frameType {
        case .target:
            KestrelTransitionRegistry.shared.setDestinationFrame(globalFrame, for: transitionId)
            KestrelTransitionRegistry.shared.completePendingTransition(for: transitionId, destinationFrame: globalFrame)
        case .source:
            break
        }
    }
}

// MARK: - SwiftUI Integration

public struct KestrelTransitionSourceKey: PreferenceKey {
    public static var defaultValue: [String: CGRect] = [:]
    
    public static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

public struct KestrelTransitionTargetKey: PreferenceKey {
    public static var defaultValue: [String: CGRect] = [:]
    
    public static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Kestrel Transition Registry

@MainActor
public class KestrelTransitionRegistry: ObservableObject {
    public static let shared = KestrelTransitionRegistry()
    
    private var transitionDelegate: KestrelTransitionDelegate?
    private var destinationFrames: [String: CGRect] = [:]
    private var transitionTriggers: [String: () -> Void] = [:]
    private var pendingTransitions: [String: PendingTransition] = [:]
    private var transitionsInProgress: Set<String> = []
    
    private struct PendingTransition {
        let sourceFrame: CGRect
        let image: UIImage
        let configuration: KestrelTransitionConfiguration
    }
    
    private init() {}
    
    public func setupTransition(for navigationController: UINavigationController) {
        kestrelLog("Setting up transition for navigation controller", level: .info)
        if transitionDelegate == nil {
            transitionDelegate = KestrelTransitionDelegate()
            kestrelLog("Created new transition delegate", level: .info)
        }
        navigationController.delegate = transitionDelegate
    }
    
    public func registerTransition(context: KestrelTransitionContext) {
        kestrelLog(
            "Registering transition context with delegate",
            level: .info,
            context: context.transitionId
        )
        transitionsInProgress.insert(context.transitionId)
        transitionDelegate?.setKestrelContext(context)
    }
    
    public func setDestinationFrame(_ frame: CGRect, for id: String) {
        kestrelLog(
            "Storing destination frame for id '\(id)': \(frame)",
            level: .debug,
            context: id
        )
        destinationFrames[id] = frame
    }
    
    public func getDestinationFrame(for id: String) -> CGRect? {
        let frame = destinationFrames[id]
        if let frame = frame {
            kestrelLog(
                "Retrieved destination frame for id '\(id)': \(frame)",
                level: .debug,
                context: id
            )
        } else {
            kestrelLog(
                "No destination frame found for id '\(id)'",
                level: .warning,
                context: id
            )
        }
        return frame
    }
    
    public func clearTransitionInProgress(_ id: String) {
        kestrelLog(
            "Clearing transition in progress for id '\(id)'",
            level: .debug,
            context: id
        )
        transitionsInProgress.remove(id)
    }
    
    public func registerTransitionTrigger(for id: String, trigger: @escaping () -> Void) {
        kestrelLog(
            "Registering manual trigger for id '\(id)'",
            level: .debug,
            context: id
        )
        transitionTriggers[id] = trigger
    }
    
    public func triggerTransition(for id: String) {
        kestrelLog(
            "Manually triggering transition for id '\(id)'",
            level: .info,
            context: id
        )
        if let trigger = transitionTriggers[id] {
            trigger()
        } else {
            kestrelLog(
                "No manual trigger registered for id '\(id)'",
                level: .warning,
                context: id
            )
        }
    }
    
    public func isDestinationFrameAvailable(for id: String) -> Bool {
        let frame = destinationFrames[id]
        return frame != nil && frame != .zero
    }
    
    public func setPendingTransition(
        id: String,
        sourceFrame: CGRect,
        image: UIImage,
        configuration: KestrelTransitionConfiguration
    ) {
        kestrelLog(
            "Storing pending transition for id '\(id)'",
            level: .debug,
            context: id
        )
        pendingTransitions[id] = PendingTransition(
            sourceFrame: sourceFrame,
            image: image,
            configuration: configuration
        )
    }
    
    public func completePendingTransition(for id: String, destinationFrame: CGRect) {
        guard let pending = pendingTransitions[id] else {
            kestrelLog(
                "No pending transition found for id '\(id)'",
                level: .warning,
                context: id
            )
            return
        }
        
        kestrelLog(
            "Updating pending transition for id '\(id)' with real destination frame: \(destinationFrame)",
            level: .info,
            context: id
        )
        
        let updatedContext = KestrelTransitionContext(
            sourceFrame: pending.sourceFrame,
            destinationFrame: destinationFrame,
            image: pending.image,
            transitionId: id,
            configuration: pending.configuration
        )
        
        transitionDelegate?.setKestrelContext(updatedContext)
        pendingTransitions.removeValue(forKey: id)
        
        kestrelLog(
            "Context updated with real destination frame",
            level: .info,
            context: id
        )
    }
}

// MARK: - UIViewController Extension

public extension UIViewController {
    func setupKestrelTransition() {
        if let navigationController = navigationController {
            KestrelTransitionRegistry.shared.setupTransition(for: navigationController)
        }
    }
}
