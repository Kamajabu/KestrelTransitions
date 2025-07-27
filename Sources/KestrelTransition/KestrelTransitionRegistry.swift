//
//  KestrelTransitionRegistry.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 26/07/2025.
//

import UIKit
import SwiftUI

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
    private var transitionContexts: [String: KestrelTransitionContext] = [:]
    
    private init() {}

    /// Sets up the transition delegate for a given navigation controller which is responsible for handling transitions.
    public func setupTransitionDelegate(for navigationController: UINavigationController) {
        kestrelLog("Setting up transition for navigation controller", level: .info)
        if transitionDelegate == nil {
            transitionDelegate = KestrelTransitionDelegate()
            kestrelLog("Created new transition delegate", level: .info)
        }
        navigationController.delegate = transitionDelegate
    }

    /// Registers all information and configuration needed for a transition context, this happens as part of setting source modifier, which I'm not really fan of, but it's optimal way to not overcomplicate configuration.
    public func registerTransitionContext(_ context: KestrelTransitionContext, allowOverwrite: Bool = false) {
        kestrelLog("Registering transition context", level: .debug, context: context.transitionId)

        let existingContext = transitionContexts[context.transitionId]

        guard existingContext == nil || allowOverwrite else {
            return
        }

        transitionContexts[context.transitionId] = context
        kestrelLog("Transition context registered: \(context.transitionId)", level: .info, context: context.transitionId)
    }

    /// Sets the source frame for a given transition ID when it changes position.
    public func setSourceFrame(_ frame: CGRect, for id: String) {
        kestrelLog("Storing source frame: \(frame), transitionContext is \(String(describing: transitionContexts[id]))", level: .debug, context: id)
        transitionContexts[id]?.updateSourceFrame(frame)
    }

    /// Sets the destination frame for a transition context when already has information about it.
    public func setDestinationFrame(_ frame: CGRect, for id: String) {
        kestrelLog("Storing destination frame: \(frame), transitionContext is \(String(describing: transitionContexts[id]))", level: .debug, context: id)
        transitionContexts[id]?.updateDestinationFrame(frame)
    }

    /// Lets delegate know which exactly transition context to use for next transition, so it know which frame is source and what config to use.
    public func prepareTransition(for id: String) {
        kestrelLog("Preparing transition context", level: .info, context: id)
        if let contextForGivenTransition = transitionContexts[id] {
            transitionDelegate?.setKestrelContext(contextForGivenTransition)
        } else {
            kestrelLog("No source modifier registered", level: .warning, context: id)
        }
    }
}
