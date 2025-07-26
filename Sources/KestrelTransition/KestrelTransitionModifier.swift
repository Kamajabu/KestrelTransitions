//
//  KestrelTransitionModifier.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 21/07/2025.
//

import SwiftUI

// MARK: - Common Transition Coordination

/// Protocol for shared transition coordination functionality
private protocol TransitionCoordinating {
    var transitionId: String { get }
    var isVisible: Bool { get set }
    
    func setupNotificationObservers()
}

/// Shared setup for notification observers across modifiers
private extension TransitionCoordinating {
    func addObserver(for name: Notification.Name, handler: @escaping (Notification) -> Void) {
        kestrelNotificationCenter.addObserver(
            forName: name,
            object: nil,
            queue: .main,
            using: handler
        )
    }
}

// MARK: - Kestrel Transition Source Modifier

// LIST IMAGE
public struct KestrelTransitionSourceModifier: ViewModifier, TransitionCoordinating {
    let id: String
    let image: UIImage
    let configuration: KestrelTransitionConfiguration

    @State private var sourceFrame: CGRect = .zero
    @State fileprivate var isVisible: Bool = true
    
    var transitionId: String { id }
    
    public func body(content: Content) -> some View {
        let modifiedContent = content
            .opacity(isVisible ? 1 : 0)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: KestrelTransitionSourceKey.self, value: [id: geometry.frame(in: .global)])
                }
            )
            .onPreferenceChange(KestrelTransitionSourceKey.self) { frames in
                if let frame = frames[id] {
                    kestrelLog("Source frame captured: \(frame)", level: .debug, context: id)
                    sourceFrame = frame
                    
                    KestrelTransitionRegistry.shared.registerSourceModifier(for: id) {
                        prepareTransition()
                    }
                }
            }
            .onAppear {
                setupNotificationObservers()
            }
            .onDisappear {
                kestrelNotificationCenter.removeObserver(self)
            }
        
        return AnyView(modifiedContent)
    }
    
    func setupNotificationObservers() {
        // Hide source view when presentation starts
        addObserver(for: KestrelNotification.presentationStarted) { notification in
            if let transitionId = notification.object as? String, transitionId == id {
                kestrelLog("Presentation started, hiding source view", level: .debug, context: id)
                isVisible = false
            }
        }
        
        // Show source view when dismissal reaches source position
        addObserver(for: KestrelNotification.sourceReached) { notification in
            if let transitionId = notification.object as? String, transitionId == id {
                kestrelLog("Source position reached, showing source view", level: .debug, context: id)
                isVisible = true
            }
        }
    }
    
    func prepareTransition() -> KestrelTransitionContext {
        return KestrelTransitionContext(
            sourceFrame: sourceFrame,
            destinationFrame: .zero,
            image: image,
            transitionId: id,
            configuration: configuration
        )
    }
}

// MARK: - Kestrel Transition Target Modifier
// DETAILS IMAGE
public struct KestrelTransitionTargetModifier: ViewModifier, TransitionCoordinating {
    let targetId: String
    
    @State fileprivate var isVisible: Bool = true
    
    var transitionId: String { targetId }
    
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
                    kestrelLog("Target frame registered: \(frame)", level: .debug, context: targetId)
                    KestrelTransitionRegistry.shared.setDestinationFrame(frame, for: targetId)
                    KestrelTransitionRegistry.shared.completePendingTransition(for: targetId, destinationFrame: frame)
                }
            }
            .onAppear {
                setupNotificationObservers()
            }
            .onDisappear {
                kestrelNotificationCenter.removeObserver(self)
            }
            .background(
                KestrelFrameBridge(transitionId: targetId, frameType: .target)
                    .frame(width: 0, height: 0)
            )
    }
    
    func setupNotificationObservers() {
        // Hide target view when presentation starts
        addObserver(for: KestrelNotification.presentationStarted) { notification in
            if let transitionId = notification.object as? String, transitionId == targetId {
                kestrelLog("Presentation started, hiding target view", level: .debug, context: targetId)
                isVisible = false
            }
        }

        // Show target view when image reaches position
        addObserver(for: KestrelNotification.imageInPosition) { _ in
            kestrelLog("Target view becoming visible", level: .debug, context: targetId)
            isVisible = true
        }
        
        // Hide target view when dismissal starts
        addObserver(for: KestrelNotification.dismissalStarted) { notification in
            if let transitionId = notification.object as? String, transitionId == targetId {
                kestrelLog("Target view hiding for dismissal", level: .debug, context: targetId)
                isVisible = false
            }
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
    func prepareKestrelTransition(id: String) {
        KestrelTransitionRegistry.shared.prepareTransition(for: id)
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

/// Prepares a Kestrel transition context for the specified ID
/// Must be called BEFORE navigation (push/pop) occurs
/// - Parameter id: The transition ID to prepare
@MainActor
public func prepareKestrelTransition(id: String) {
    KestrelTransitionRegistry.shared.prepareTransition(for: id)
}
