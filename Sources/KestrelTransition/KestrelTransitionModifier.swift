//
//  KestrelTransitionModifier.swift
//  Kestrel
//
//  Created by Kamil Buczel on 21/07/2025.
//

import SwiftUI

// MARK: - Kestrel Transition Modifier
public struct KestrelTransitionModifier: ViewModifier {
    let id: String
    let image: UIImage
    let sourceCornerRadius: CGFloat

    @State private var sourceFrame: CGRect = .zero
    
    public func body(content: Content) -> some View {
        let modifiedContent = content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: KestrelTransitionKey.self, value: [id: geometry.frame(in: .global)])
                }
            )
            .onPreferenceChange(KestrelTransitionKey.self) { frames in
                if let frame = frames[id] {
                    print("[KestrelTransition] 📍 Source frame captured for id '\(id)': \(frame)")
                    sourceFrame = frame
                    // Register manual trigger for external use
                    KestrelTransitionRegistry.shared.registerTransitionTrigger(for: id) {
                        triggerTransition()
                    }
                }
            }
        
        return AnyView(modifiedContent)
    }
    
    private func triggerTransition() {
        let context = KestrelTransitionContext(
            sourceFrame: sourceFrame,
            destinationFrame: .zero,
            image: image,
            sourceCornerRadius: sourceCornerRadius,
            destinationCornerRadius: 0,
            transitionId: id
        )
        KestrelTransitionRegistry.shared.registerTransition(context: context)
    }
    
    /// Public method to manually trigger the transition (for external tap handling)
    public func triggerTransitionManually() {
        triggerTransition()
    }
    
    
}

// MARK: - View Extension for Easy Usage
public extension View {
    /// Adds Kestrel transition capability to any view
    /// - Parameters:
    ///   - id: Unique identifier for this transition
    ///   - image: The image to transition
    ///   - imageName: Name of the SF Symbol or image
    ///   - sourceCornerRadius: Corner radius of the source view
    ///   - enableTapGesture: Whether to automatically handle tap gestures (default: true)
    ///   - onTrigger: Callback when transition is triggered
    func kestrelTransitionSource(
        id: String,
        image: UIImage,
        sourceCornerRadius: CGFloat = 0
    ) -> some View {
        self.modifier(
            KestrelTransitionModifier(
                id: id,
                image: image,
                sourceCornerRadius: sourceCornerRadius
            )
        )
    }
    
}

// MARK: - Kestrel Transition Target Modifier
public struct KestrelTransitionTargetModifier: ViewModifier {
    let targetId: String
    let destinationCornerRadius: CGFloat
    @State private var isVisible: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: KestrelTransitionTargetKey.self, value: [targetId: geometry.frame(in: .global)])
                }
            )
            .onPreferenceChange(KestrelTransitionTargetKey.self) { frames in
                if let frame = frames[targetId] {
                    print("[KestrelTransition] 🎯 Target frame registered for id '\(targetId)': \(frame)")
                    KestrelTransitionRegistry.shared.setDestinationFrame(frame, for: targetId)
                    KestrelTransitionRegistry.shared.setDestinationCornerRadius(destinationCornerRadius, for: targetId)
                    
                    // Check if there's a pending transition waiting for this frame
                    KestrelTransitionRegistry.shared.completePendingTransition(for: targetId, destinationFrame: frame)
                }
            }
            .onAppear {
                setupTransitionCoordination()
                // Immediately register frame if geometry is available
                DispatchQueue.main.async {
                    // Force frame update on appear
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
    }
    
    private func setupTransitionCoordination() {
        // Listen for forward transition completion
        NotificationCenter.default.addObserver(
            forName: Notification.Name("KestrelTransitionImageInPosition"),
            object: nil,
            queue: .main
        ) { _ in
            print("[KestrelTransition] 🌟 Target view becoming visible for id '\(targetId)'")
            withAnimation(.easeOut(duration: 0.6)) {
                isVisible = true
            }
        }
        
        // Listen for back transition start
        NotificationCenter.default.addObserver(
            forName: Notification.Name("KestrelTransitionDismissalStarted"),
            object: nil,
            queue: .main
        ) { _ in
            print("[KestrelTransition] 👻 Target view hiding for dismissal (id: '\(targetId)')")
            isVisible = false
        }
    }
}

// MARK: - View Extension for Easy Usage
public extension View {
    /// Makes this view a Kestrel transition target
    /// The view will be hidden initially and fade in when the transition completes
    /// - Parameters:
    ///   - id: Unique identifier for this transition target
    ///   - destinationCornerRadius: Corner radius of the destination view
    func kestrelTransitionTarget(id: String = "default", destinationCornerRadius: CGFloat = 20) -> some View {
        self.modifier(KestrelTransitionTargetModifier(targetId: id, destinationCornerRadius: destinationCornerRadius))
            .background(
                // Add frame bridge to reliably communicate frame to UIKit
                KestrelFrameBridge(transitionId: id, frameType: .target)
                    .frame(width: 0, height: 0) // Invisible bridge
            )
    }
}

// MARK: - UIKit Integration Helper
public extension UIViewController {
    /// Call this in viewDidLoad to enable Kestrel transitions
    func enableKestrelTransitions() {
        setupKestrelTransition()
    }
}


// MARK: - External Trigger Support
public extension View {
    /// Manually trigger a Kestrel transition for views with enableTapGesture: false
    /// Call this from your custom tap handlers, button actions, etc.
    func triggerKestrelTransition(id: String) {
        KestrelTransitionRegistry.shared.triggerTransition(for: id)
    }
}

// kestrelTransitionSource -> kestrelTransitionTarget
