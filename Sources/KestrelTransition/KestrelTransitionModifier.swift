//
//  KestrelTransitionModifier.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 21/07/2025.
//

import SwiftUI

// MARK: - Kestrel Transition Source Modifier

public struct KestrelTransitionModifier: ViewModifier {
    let id: String
    let image: UIImage
    let configuration: KestrelTransitionConfiguration

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
                    kestrelLog(
                        "Source frame captured for id '\(id)': \(frame)",
                        level: .debug,
                        context: id
                    )
                    sourceFrame = frame
                    
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
            transitionId: id,
            configuration: configuration
        )
        KestrelTransitionRegistry.shared.registerTransition(context: context)
    }
}

// MARK: - Kestrel Transition Target Modifier

public struct KestrelTransitionTargetModifier: ViewModifier {
    let targetId: String
    
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
                    kestrelLog(
                        "Target frame registered for id '\(targetId)': \(frame)",
                        level: .debug,
                        context: targetId
                    )
                    KestrelTransitionRegistry.shared.setDestinationFrame(frame, for: targetId)
                    KestrelTransitionRegistry.shared.completePendingTransition(for: targetId, destinationFrame: frame)
                }
            }
            .onAppear {
                setupTransitionCoordination()
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
            .background(
                KestrelFrameBridge(transitionId: targetId, frameType: .target)
                    .frame(width: 0, height: 0)
            )
    }
    
    private func setupTransitionCoordination() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("KestrelTransitionImageInPosition"),
            object: nil,
            queue: .main
        ) { _ in
            kestrelLog(
                "Target view becoming visible for id '\(targetId)'",
                level: .debug,
                context: targetId
            )
            isVisible = true
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("KestrelTransitionDismissalStarted"),
            object: nil,
            queue: .main
        ) { _ in
            kestrelLog(
                "Target view hiding for dismissal (id: '\(targetId)')",
                level: .debug,
                context: targetId
            )
            isVisible = false
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Adds Kestrel transition capability to any view
    /// - Parameters:
    ///   - id: Unique identifier for this transition
    ///   - image: The image to transition
    ///   - configuration: The transition configuration (optional, uses default if not provided)
    func kestrelTransitionSource(
        id: String,
        image: UIImage,
        configuration: KestrelTransitionConfiguration = .default
    ) -> some View {
        self.modifier(
            KestrelTransitionModifier(
                id: id,
                image: image,
                configuration: configuration
            )
        )
    }
    
    /// Makes this view a Kestrel transition target
    /// The view will be hidden initially and fade in when the transition completes
    /// - Parameter id: Unique identifier for this transition target
    func kestrelTransitionTarget(id: String = "default") -> some View {
        self.modifier(KestrelTransitionTargetModifier(targetId: id))
    }
    
    /// Manually trigger a Kestrel transition for views with custom tap handling
    /// Call this from your custom tap handlers, button actions, etc.
    @MainActor
    func triggerKestrelTransition(id: String) {
        KestrelTransitionRegistry.shared.triggerTransition(for: id)
    }
}

// MARK: - UIViewController Extension

public extension UIViewController {
    /// Call this in viewDidLoad to enable Kestrel transitions
    func enableKestrelTransitions() {
        setupKestrelTransition()
    }
}

// MARK: - Global Trigger Function

/// Global function to manually trigger a Kestrel transition
/// - Parameter id: The transition ID to trigger
@MainActor
public func triggerKestrelTransition(id: String) {
    KestrelTransitionRegistry.shared.triggerTransition(for: id)
}