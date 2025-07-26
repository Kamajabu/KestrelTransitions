//
//  KestrelTransitionModifier.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 21/07/2025.
//

import SwiftUI

// MARK: - Kestrel Transition Source Modifier

// LIST IMAGE
public struct KestrelTransitionSourceModifier: ViewModifier {
    let id: String
    let image: UIImage
    let configuration: KestrelTransitionConfiguration

    @State private var sourceFrame: CGRect = .zero
    @State private var isVisible: Bool = true
    
    public func body(content: Content) -> some View {
        let modifiedContent = content
            .opacity(isVisible ? 1 : 0)
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
            .onAppear {
                setupTransitionCoordination()
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
        
        return AnyView(modifiedContent)
    }
    
    private func setupTransitionCoordination() {
        // Listen for presentation transition start - hide source view
        NotificationCenter.default.addObserver(
            forName: Notification.Name("KestrelTransitionPresentationStarted"),
            object: nil,
            queue: .main
        ) { notification in
            if let transitionId = notification.object as? String, transitionId == id {
                kestrelLog(
                    "Presentation started, hiding source view (id: '\(id)')",
                    level: .debug,
                    context: id
                )
                isVisible = false
            }
        }
        
        // Listen for dismissal animation reaching source position - show source view
        NotificationCenter.default.addObserver(
            forName: Notification.Name("KestrelTransitionSourceReached"),
            object: nil,
            queue: .main
        ) { notification in
            if let transitionId = notification.object as? String, transitionId == id {
                kestrelLog(
                    "Transition reached source position, showing source view (id: '\(id)')",
                    level: .debug,
                    context: id
                )
                isVisible = true
            }
        }
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
// DETAILS IMAGE
public struct KestrelTransitionTargetModifier: ViewModifier {
    let targetId: String
    
    @State private var isVisible: Bool = true
    
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
            forName: Notification.Name("KestrelTransitionPresentationStarted"),
            object: nil,
            queue: .main
        ) { notification in
            if let transitionId = notification.object as? String, transitionId == targetId {
                kestrelLog(
                    "Presentation started, hiding target view (id: '\(targetId)')",
                    level: .debug,
                    context: targetId
                )
                isVisible = false
            }
        }

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
        ) { notification in
            if let transitionId = notification.object as? String, transitionId == targetId {
                kestrelLog(
                    "Target view hiding for dismissal (id: '\(targetId)')",
                    level: .debug,
                    context: targetId
                )
                isVisible = false
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("KestrelTransitionDismissalCompleted"),
            object: nil,
            queue: .main
        ) { _ in
            kestrelLog(
                "Dismissal completed, keeping target view hidden (id: '\(targetId)')",
                level: .debug,
                context: targetId
            )
            // Keep target view hidden after dismissal completes
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
            KestrelTransitionSourceModifier(
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
