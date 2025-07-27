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

    @State private var isVisible: Bool = true
    @State private var observers: [NSObjectProtocol] = []

    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: KestrelTransitionSourceKey.self, value: [id: geometry.frame(in: .global)])
                }
            )
            .onPreferenceChange(KestrelTransitionSourceKey.self) { frames in
                let context = KestrelTransitionContext(
                    image: image,
                    transitionId: id,
                    configuration: configuration
                )
                KestrelTransitionRegistry.shared.registerTransitionContext(context)

                if let frame = frames[id] {
                    kestrelLog("Source frame captured: \(frame)", level: .debug, context: id)
                    KestrelTransitionRegistry.shared.setSourceFrame(frame, for: id)
                }
            }
            .onAppear {
                setupNotificationObservers()
            }
            .onDisappear {
                removeAllObservers()
            }
    }

    private func setupNotificationObservers() {
        // Hide source view when presentation starts
        let presentationObserver = KestrelObserver.addFilteredObserver(
            for: .presentationStarted,
            transitionId: id
        ) { [self] in
            kestrelLog("Presentation started, hiding source view", level: .debug, context: id)
            isVisible = false
        }
        observers.append(presentationObserver)

        // Show source view when dismissal reaches source position
        let sourceReachedObserver = KestrelObserver.addFilteredObserver(
            for: .sourceReached,
            transitionId: id
        ) { [self] in
            kestrelLog("Source position reached, showing source view", level: .debug, context: id)
            isVisible = true
        }
        observers.append(sourceReachedObserver)
    }

    private func removeAllObservers() {
        observers.forEach { KestrelObserver.removeObserver($0) }
        observers.removeAll()
    }
}

// MARK: - Kestrel Transition Target Modifier
// DETAILS IMAGE
public struct KestrelTransitionTargetModifier: ViewModifier {
    let targetId: String

    @State private var isVisible: Bool = false
    @State private var observers: [NSObjectProtocol] = []

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
                }
            }
            .onAppear {
                setupNotificationObservers()
            }
            .onDisappear {
                removeAllObservers()
            }
    }

    private func setupNotificationObservers() {
        // Show target view when image reaches position
        let imageInPositionObserver = KestrelObserver.addFilteredObserver(
            for: .imageInPosition,
            transitionId: targetId
        ) { [self] in
            kestrelLog("Target view becoming visible", level: .debug, context: targetId)
            isVisible = true
        }
        observers.append(imageInPositionObserver)

        // Hide target view when dismissal starts
        let dismissalObserver = KestrelObserver.addFilteredObserver(
            for: .dismissalStarted,
            transitionId: targetId
        ) { [self] in
            kestrelLog("Target view hiding for dismissal", level: .debug, context: targetId)
            isVisible = false
        }
        observers.append(dismissalObserver)
    }

    private func removeAllObservers() {
        observers.forEach { KestrelObserver.removeObserver($0) }
        observers.removeAll()
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

// MARK: - Global Trigger Function

/// Prepares a Kestrel transition context for the specified ID
/// Must be called BEFORE navigation (push/pop) occurs
/// - Parameter id: The transition ID to prepare
@MainActor
public func prepareKestrelTransition(id: String) {
    KestrelTransitionRegistry.shared.prepareTransition(for: id)
}
