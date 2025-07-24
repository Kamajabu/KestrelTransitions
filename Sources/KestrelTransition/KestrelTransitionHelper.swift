//
//  KestrelTransitionHelper.swift
//  Kestrel
//
//  Created by Kamil Buczel on 20/07/2025.
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
        // Report frame as soon as we're added to the view hierarchy
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
        // Also report when moved to window
        DispatchQueue.main.async {
            self.reportFrame()
        }
    }
    
    func reportFrame() {
        guard !transitionId.isEmpty else { return }
        
        // The bridge is attached as a background to the target view
        // Our immediate superview is the target view we want to report
        guard let targetView = superview else {
            print("[KestrelTransition] ⚠️ Bridge has no superview for id '\(transitionId)'")
            return
        }
        
        // Get the frame in global coordinates
        let globalFrame = targetView.superview?.convert(targetView.frame, to: nil) ?? targetView.frame
        
        // Only report if frame is reasonable (not zero)
        guard globalFrame.width > 0 && globalFrame.height > 0 else {
            print("[KestrelTransition] ⚠️ Bridge found zero-sized frame for id '\(transitionId)', skipping")
            return
        }
        
        print("[KestrelTransition] 📡 Bridge reporting \(frameType) frame for id '\(transitionId)': \(globalFrame)")
        print("[KestrelTransition] 🔍 Bridge details - bridge: \(self.frame), target: \(targetView.frame), global: \(globalFrame)")
        
        switch frameType {
        case .target:
            KestrelTransitionRegistry.shared.setDestinationFrame(globalFrame, for: transitionId)
            // Also complete any pending transitions
            KestrelTransitionRegistry.shared.completePendingTransition(for: transitionId, destinationFrame: globalFrame)
        case .source:
            // Source frames are typically handled by the tap gesture, but we can store them too
            break
        }
    }
}

// MARK: - Kestrel Transition Helper
@MainActor
public class KestrelTransitionHelper {
    
    // MARK: - Frame Capture
    public static func captureFrame(of view: UIView, in coordinateSpace: UIView) -> CGRect {
        let bounds = view.bounds
        let convertedFrame = view.convert(bounds, to: coordinateSpace)
        return convertedFrame
    }
    
    // MARK: - Image Generation
    public static func generateSFSymbolImage(named symbolName: String, size: CGFloat, color: UIColor = .systemBlue) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
        let image = UIImage(systemName: symbolName, withConfiguration: configuration)
        return image?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    // MARK: - View Controller Frame Calculation
    public static func calculateDestinationFrame(for imageSize: CGSize, in viewController: UIViewController, topOffset: CGFloat = 100) -> CGRect {
        let screenWidth = viewController.view.bounds.width
        let imageWidth = min(imageSize.width, screenWidth * 0.6)
        let imageHeight = imageSize.height * (imageWidth / imageSize.width)
        
        let x = (screenWidth - imageWidth) / 2
        let y = topOffset
        
        return CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
    }
}

// MARK: - SwiftUI Integration
public struct KestrelTransitionKey: PreferenceKey {
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
    private var destinationCornerRadii: [String: CGFloat] = [:]
    private var transitionTriggers: [String: () -> Void] = [:]
    private var pendingTransitions: [String: PendingTransition] = [:]
    private var transitionsInProgress: Set<String> = []
    
    private struct PendingTransition {
        let sourceFrame: CGRect
        let image: UIImage
        let imageName: String
        let sourceCornerRadius: CGFloat
    }
    
    private init() {}
    
    public func setupTransition(for navigationController: UINavigationController) {
        print("[KestrelTransition] 🛠️ Setting up transition for navigation controller")
        if transitionDelegate == nil {
            transitionDelegate = KestrelTransitionDelegate()
            print("[KestrelTransition] 🎬 Created new transition delegate")
        }
        navigationController.delegate = transitionDelegate
    }
    
    public func registerTransition(context: KestrelTransitionContext) {
        print("[KestrelTransition] 📋 Registering transition context with delegate")
        transitionsInProgress.insert(context.transitionId)
        transitionDelegate?.setKestrelContext(context)
    }
    
    public func setDestinationFrame(_ frame: CGRect, for id: String) {
        // Don't override frames during active transitions to prevent wrong values
        print("[KestrelTransition] 💾 Storing destination frame for id '\(id)': \(frame)")
        destinationFrames[id] = frame
    }
    
    public func getDestinationFrame(for id: String) -> CGRect? {
        let frame = destinationFrames[id]
        if let frame = frame {
            print("[KestrelTransition] 📝 Retrieved destination frame for id '\(id)': \(frame)")
        } else {
            print("[KestrelTransition] ⚠️ No destination frame found for id '\(id)'")
        }
        return frame
    }
    
    public func setDestinationCornerRadius(_ cornerRadius: CGFloat, for id: String) {
        print("[KestrelTransition] 💾 Storing destination corner radius for id '\(id)': \(cornerRadius)")
        destinationCornerRadii[id] = cornerRadius
    }
    
    public func getDestinationCornerRadius(for id: String) -> CGFloat? {
        let cornerRadius = destinationCornerRadii[id]
        if let cornerRadius = cornerRadius {
            print("[KestrelTransition] 📝 Retrieved destination corner radius for id '\(id)': \(cornerRadius)")
        } else {
            print("[KestrelTransition] ⚠️ No destination corner radius found for id '\(id)', using default")
        }
        return cornerRadius
    }
    
    public func clearTransitionInProgress(_ id: String) {
        print("[KestrelTransition] 📋 Clearing transition in progress for id '\(id)'")
        transitionsInProgress.remove(id)
    }
    
    public func registerTransitionTrigger(for id: String, trigger: @escaping () -> Void) {
        print("[KestrelTransition] 💾 Registering manual trigger for id '\(id)'")
        transitionTriggers[id] = trigger
    }
    
    public func triggerTransition(for id: String) {
        print("[KestrelTransition] 🔥 Manually triggering transition for id '\(id)'")
        if let trigger = transitionTriggers[id] {
            trigger()
        } else {
            print("[KestrelTransition] ⚠️ No manual trigger registered for id '\(id)'")
        }
    }
    
    /// Check if destination frame is available for a given transition ID
    public func isDestinationFrameAvailable(for id: String) -> Bool {
        let frame = destinationFrames[id]
        return frame != nil && frame != .zero
    }
    
    /// Store a pending transition that will be completed once destination frame is available
    public func setPendingTransition(id: String, sourceFrame: CGRect, image: UIImage, imageName: String, sourceCornerRadius: CGFloat) {
        print("[KestrelTransition] 📋 Storing pending transition for id '\(id)'")
        pendingTransitions[id] = PendingTransition(
            sourceFrame: sourceFrame,
            image: image,
            imageName: imageName,
            sourceCornerRadius: sourceCornerRadius
        )
    }
    
    /// Complete a pending transition when destination frame becomes available
    public func completePendingTransition(for id: String, destinationFrame: CGRect) {
        guard let pending = pendingTransitions[id] else {
            print("[KestrelTransition] ⚠️ No pending transition found for id '\(id)'")
            return
        }
        
        print("[KestrelTransition] ✅ Updating pending transition for id '\(id)' with real destination frame: \(destinationFrame)")
        
        // Create updated context with real destination frame
        let updatedContext = KestrelTransitionContext(
            sourceFrame: pending.sourceFrame,
            destinationFrame: destinationFrame,
            image: pending.image,
            imageName: pending.imageName,
            sourceCornerRadius: pending.sourceCornerRadius,
            destinationCornerRadius: getDestinationCornerRadius(for: id) ?? 20,
            transitionId: id
        )
        
        // Update the context with the real destination frame
        transitionDelegate?.setKestrelContext(updatedContext)
        pendingTransitions.removeValue(forKey: id)
        
        print("[KestrelTransition] ✅ Context updated with real destination frame")
    }
}

// MARK: - View Extension for Frame Tracking
public extension View {
    func trackKestrelFrame(id: String, in coordinateSpace: CoordinateSpace = .global) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: KestrelTransitionKey.self,
                    value: [id: geometry.frame(in: coordinateSpace)]
                )
            }
        )
    }
    
    /// Pre-register a view's frame for transition targeting
    /// Useful for ensuring destination frames are available before transitions
    func preRegisterKestrelTarget(id: String, cornerRadius: CGFloat = 20) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: KestrelTransitionTargetKey.self, value: [id: geometry.frame(in: .global)])
                    .onPreferenceChange(KestrelTransitionTargetKey.self) { frames in
                        if let frame = frames[id] {
                            print("[KestrelTransition] 🚀 Pre-registered target frame for id '\(id)': \(frame)")
                            KestrelTransitionRegistry.shared.setDestinationFrame(frame, for: id)
                            KestrelTransitionRegistry.shared.setDestinationCornerRadius(cornerRadius, for: id)
                        }
                    }
            }
        )
    }
    
    func kestrelTransition<Content: View>(
        id: String,
        image: UIImage,
        imageName: String,
        destinationFrame: CGRect,
        @ViewBuilder destination: @escaping () -> Content
    ) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: KestrelTransitionKey.self,
                    value: [id: geometry.frame(in: .global)]
                )
            }
        )
        .onPreferenceChange(KestrelTransitionKey.self) { frames in
            if let sourceFrame = frames[id] {
                let context = KestrelTransitionContext(
                    sourceFrame: sourceFrame,
                    destinationFrame: destinationFrame,
                    image: image,
                    imageName: imageName,
                    sourceCornerRadius: 12, // Default for legacy usage
                    destinationCornerRadius: 20, // Default for legacy usage
                    transitionId: id
                )
                KestrelTransitionRegistry.shared.registerTransition(context: context)
            }
        }
    }
}

// MARK: - UIViewController Extension for Transition Setup
public extension UIViewController {
    func setupKestrelTransition() {
        if let navigationController = navigationController {
            KestrelTransitionRegistry.shared.setupTransition(for: navigationController)
        }
    }
}
