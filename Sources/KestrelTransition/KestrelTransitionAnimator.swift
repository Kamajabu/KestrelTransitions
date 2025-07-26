//
//  KestrelTransitionAnimator.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 20/07/2025.
//

import UIKit
import SwiftUI

// MARK: - Kestrel Transition Animator

@MainActor
public class KestrelTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool
    private let context: KestrelTransitionContext?
    
    public init(isPresenting: Bool, context: KestrelTransitionContext?) {
        self.isPresenting = isPresenting
        self.context = context
        super.init()
        
        kestrelLog(
            "Animator initialized - presenting: \(isPresenting)",
            level: .info,
            context: context?.transitionId
        )
        
        if let context = context {
            kestrelLog(
                "Context - source: \(context.sourceFrame), destination: \(context.destinationFrame)",
                level: .debug,
                context: context.transitionId
            )
        } else {
            kestrelLog("No transition context available, will use default transition", level: .warning)
        }
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return context?.configuration.duration ?? 1.0
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        kestrelLog(
            "Starting \(isPresenting ? "presentation" : "dismissal") animation",
            level: .info,
            context: context?.transitionId
        )
        
        guard var context = context else {
            kestrelLog("No context available, cannot perform transition", level: .error)
            fatalError("KestrelTransition: No transition context available. Ensure kestrelTransitionSource is properly configured.")
        }
        
        // If destination frame is zero, we need to render the destination view first
        if context.destinationFrame == .zero {
            context = waitForDestinationFrame(context: context, transitionContext: transitionContext)
        }
        
        if isPresenting {
            animatePresentation(using: transitionContext, heroContext: context)
        } else {
            animateDismissal(using: transitionContext, heroContext: context)
        }
    }
    
    private func waitForDestinationFrame(
        context: KestrelTransitionContext,
        transitionContext: UIViewControllerContextTransitioning
    ) -> KestrelTransitionContext {
        kestrelLog(
            "Destination frame not available, allowing view to render first...",
            level: .warning,
            context: context.transitionId
        )
        
        guard let toViewController = transitionContext.viewController(forKey: .to) else {
            fatalError("KestrelTransition: No destination view controller available")
        }
        
        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        
        // Add destination view controller to trigger rendering
        toViewController.view.frame = finalFrame
        toViewController.view.alpha = 0
        containerView.addSubview(toViewController.view)
        
        // Force layout to trigger bridge frame reporting
        toViewController.view.layoutIfNeeded()
        
        // Wait for the bridge to report the frame
        var attempts = 0
        let maxAttempts = 50 // 500ms total wait time
        
        while attempts < maxAttempts {
            if let bridgeFrame = KestrelTransitionRegistry.shared.getDestinationFrame(for: context.transitionId),
               bridgeFrame != .zero {
                kestrelLog(
                    "Bridge provided destination frame after rendering: \(bridgeFrame)",
                    level: .info,
                    context: context.transitionId
                )
                
                return KestrelTransitionContext(
                    sourceFrame: context.sourceFrame,
                    destinationFrame: bridgeFrame,
                    image: context.image,
                    transitionId: context.transitionId,
                    configuration: context.configuration
                )
            }
            
            Thread.sleep(forTimeInterval: 0.01) // 10ms intervals
            attempts += 1
        }
        
        kestrelLog(
            "Bridge system failed to provide destination frame after \(attempts) attempts",
            level: .error,
            context: context.transitionId
        )
        fatalError("KestrelTransition: Bridge system could not provide destination frame for id '\(context.transitionId)'. Ensure kestrelTransitionTarget is properly configured and view is rendered.")
    }
    
    private func animatePresentation(using transitionContext: UIViewControllerContextTransitioning, heroContext: KestrelTransitionContext) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
              let fromViewController = transitionContext.viewController(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        let config = heroContext.configuration
        
        kestrelLog(
            "Setting up presentation - final frame: \(finalFrame)",
            level: .debug,
            context: heroContext.transitionId
        )
        
        // Check if destination view is already added (from frame detection)
        if !containerView.subviews.contains(toViewController.view) {
            toViewController.view.frame = finalFrame
            toViewController.view.alpha = 1
            containerView.addSubview(toViewController.view)
        } else {
            toViewController.view.alpha = 1
        }
        
        // Create transitioning image views for morphing effect
        kestrelLog("Creating transition image views", level: .debug, context: heroContext.transitionId)
        let sourceImageView = createTransitionImageView(from: heroContext)
        let destinationImageView = createDestinationImageView(from: heroContext)
        
        destinationImageView.frame = heroContext.sourceFrame
        destinationImageView.alpha = 0
        
        // Remove autoresizing masks and manually manage sizing
        destinationImageView.subviews.forEach { subview in
            subview.autoresizingMask = []
            subview.frame = CGRect(origin: .zero, size: heroContext.sourceFrame.size)
        }
        
        containerView.addSubview(sourceImageView)
        containerView.addSubview(destinationImageView)
        
        // Animate in two phases for smooth morphing
        kestrelLog(
            "Phase 1: Starting scale and move animation (\(config.duration * 0.6)s)",
            level: .debug,
            context: heroContext.transitionId
        )
        
        UIView.animate(
            withDuration: config.duration * 0.6,
            delay: 0,
            usingSpringWithDamping: config.springDamping,
            initialSpringVelocity: config.springVelocity,
            options: config.animationOptions
        ) {
            // Phase 1: Scale and move while cross-fading
            sourceImageView.frame = heroContext.destinationFrame
            destinationImageView.frame = heroContext.destinationFrame
            
            // Manually resize all internal components to destination size
            [sourceImageView, destinationImageView].forEach { containerView in
                containerView.subviews.forEach { subview in
                    subview.frame = CGRect(origin: .zero, size: heroContext.destinationFrame.size)
                }
            }
            
            // Animate corner radius morphing on clipping containers
            if let sourceClippingContainer = sourceImageView.subviews.last(where: { $0.layer.masksToBounds == true }) {
                sourceClippingContainer.layer.cornerRadius = config.cornerRadius.destination
            }
            if let destClippingContainer = destinationImageView.subviews.last(where: { $0.layer.masksToBounds == true }) {
                destClippingContainer.layer.cornerRadius = config.cornerRadius.destination
            }
            
            // Also animate shadow corner radius
            if config.shadow.isEnabled {
                if let sourceShadow = sourceImageView.subviews.first {
                    sourceShadow.layer.cornerRadius = config.cornerRadius.destination
                }
                if let destShadow = destinationImageView.subviews.first {
                    destShadow.layer.cornerRadius = config.cornerRadius.destination
                }
            }
            
            // Cross-fade between images
            sourceImageView.alpha = 0
            destinationImageView.alpha = 1
            
            // Fade out source view
            fromViewController.view.alpha = 0
        } completion: { _ in
            kestrelLog(
                "Phase 1 complete - transition image frame: \(destinationImageView.frame)",
                level: .debug,
                context: heroContext.transitionId
            )
            
            // Notify that transition image is now in final position and immediately show real view
            kestrelLog(
                "Phase 1 complete - showing target view and cleaning up",
                level: .debug,
                context: heroContext.transitionId
            )
            NotificationCenter.default.post(name: Notification.Name("KestrelTransitionImageInPosition"), object: nil)
            
            // Immediately clean up transition views and complete
            sourceImageView.removeFromSuperview()
            destinationImageView.removeFromSuperview()
            fromViewController.view.alpha = 1
            
            KestrelTransitionRegistry.shared.clearTransitionInProgress(heroContext.transitionId)
            transitionContext.completeTransition(true)
        }
    }
    
    private func animateDismissal(using transitionContext: UIViewControllerContextTransitioning, heroContext: KestrelTransitionContext) {
        guard let fromViewController = transitionContext.viewController(forKey: .from),
              let toViewController = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        let config = heroContext.configuration
        
        kestrelLog("Setting up dismissal animation", level: .debug, context: heroContext.transitionId)
        
        // Immediately notify to hide the real image in detail view
        kestrelLog("Notifying target view to hide for dismissal", level: .debug, context: heroContext.transitionId)
        NotificationCenter.default.post(name: Notification.Name("KestrelTransitionDismissalStarted"), object: nil)
        
        // Add destination view controller back with initial fade
        toViewController.view.alpha = 0.3
        containerView.insertSubview(toViewController.view, belowSubview: fromViewController.view)
        
        // Create morphing image views for dismissal
        let destinationImageView = createDestinationImageView(from: heroContext)
        let sourceImageView = createTransitionImageView(from: heroContext)
        sourceImageView.frame = heroContext.destinationFrame
        sourceImageView.alpha = 0
        
        // Remove autoresizing and manually size all components to destination initially
        [destinationImageView, sourceImageView].forEach { containerView in
            containerView.subviews.forEach { subview in
                subview.autoresizingMask = []
                subview.frame = CGRect(origin: .zero, size: heroContext.destinationFrame.size)
            }
        }
        
        containerView.addSubview(destinationImageView)
        containerView.addSubview(sourceImageView)
        
        // Single phase dismissal animation
        kestrelLog(
            "Starting dismissal animation (\(config.duration)s)",
            level: .debug,
            context: heroContext.transitionId
        )
        
        UIView.animate(
            withDuration: config.duration,
            delay: 0,
            usingSpringWithDamping: config.springDamping,
            initialSpringVelocity: config.springVelocity,
            options: config.animationOptions
        ) {
            // Fade out detail content immediately
            fromViewController.view.alpha = 0
            destinationImageView.alpha = 0
            sourceImageView.alpha = 1
            
            // Move image back to source position
            sourceImageView.frame = heroContext.sourceFrame
            
            // Manually resize all internal components to source size
            sourceImageView.subviews.forEach { subview in
                subview.frame = CGRect(origin: .zero, size: heroContext.sourceFrame.size)
            }
            
            // Animate corner radius back to source on clipping container
            if let sourceClippingContainer = sourceImageView.subviews.last(where: { $0.layer.masksToBounds == true }) {
                sourceClippingContainer.layer.cornerRadius = config.cornerRadius.source
            }
            
            // Also animate shadow corner radius back
            if config.shadow.isEnabled {
                if let sourceShadow = sourceImageView.subviews.first {
                    sourceShadow.layer.cornerRadius = config.cornerRadius.source
                }
            }
            
            // Fade in list view progressively
            toViewController.view.alpha = 1
        } completion: { finished in
            kestrelLog(
                "Dismissal complete - cleaning up transition views",
                level: .info,
                context: heroContext.transitionId
            )
            destinationImageView.removeFromSuperview()
            sourceImageView.removeFromSuperview()
            
            KestrelTransitionRegistry.shared.clearTransitionInProgress(heroContext.transitionId)
            transitionContext.completeTransition(finished)
        }
    }
    
    private func createTransitionImageView(from context: KestrelTransitionContext) -> UIView {
        kestrelLog(
            "Creating source transition image view with frame: \(context.sourceFrame)",
            level: .debug,
            context: context.transitionId
        )
        
        let config = context.configuration
        let containerView = UIView(frame: context.sourceFrame)
        containerView.backgroundColor = config.background.isEnabled ? config.background.color : .clear
        containerView.layer.cornerRadius = 0
        containerView.layer.masksToBounds = false
        
        // Create shadow view if enabled
        if config.shadow.isEnabled {
            let shadowView = UIView(frame: containerView.bounds)
            shadowView.layer.shadowColor = config.shadow.color.cgColor
            shadowView.layer.shadowOffset = config.shadow.offset
            shadowView.layer.shadowOpacity = config.shadow.opacity
            shadowView.layer.shadowRadius = config.shadow.radius
            shadowView.layer.masksToBounds = false
            shadowView.layer.cornerRadius = config.cornerRadius.source
            shadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(shadowView)
        }
        
        // Create clipping container for proper corner radius
        let clippingContainer = UIView(frame: containerView.bounds)
        clippingContainer.layer.cornerRadius = config.cornerRadius.source
        clippingContainer.layer.masksToBounds = true
        clippingContainer.backgroundColor = config.background.isEnabled ? config.background.color : .clear
        clippingContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Create image view that fills the container
        let imageView = UIImageView(image: context.image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = clippingContainer.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add blur effect if enabled
        if config.blur.isEnabled {
            let blurEffect = UIBlurEffect(style: config.blur.style)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = clippingContainer.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.alpha = config.blur.intensity
            clippingContainer.addSubview(imageView)
            clippingContainer.addSubview(blurView)
        } else {
            clippingContainer.addSubview(imageView)
        }
        
        containerView.addSubview(clippingContainer)
        
        return containerView
    }
    
    private func createDestinationImageView(from context: KestrelTransitionContext) -> UIView {
        kestrelLog(
            "Creating destination transition image view with frame: \(context.destinationFrame)",
            level: .debug,
            context: context.transitionId
        )
        
        let config = context.configuration
        let containerView = UIView(frame: context.destinationFrame)
        containerView.backgroundColor = .clear
        containerView.layer.cornerRadius = 0
        containerView.layer.masksToBounds = false
        
        // Create shadow view if enabled
        if config.shadow.isEnabled {
            let shadowView = UIView(frame: containerView.bounds)
            shadowView.layer.shadowColor = config.shadow.color.cgColor
            shadowView.layer.shadowOffset = CGSize(width: 0, height: 8) // Slightly larger for destination
            shadowView.layer.shadowOpacity = config.shadow.opacity + 0.05 // Slightly more pronounced
            shadowView.layer.shadowRadius = config.shadow.radius + 4 // Larger radius
            shadowView.layer.masksToBounds = false
            shadowView.layer.cornerRadius = config.cornerRadius.destination
            shadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(shadowView)
        }
        
        // Create clipping container for proper corner radius
        let clippingContainer = UIView(frame: containerView.bounds)
        clippingContainer.layer.cornerRadius = config.cornerRadius.destination
        clippingContainer.layer.masksToBounds = true
        clippingContainer.backgroundColor = config.background.isEnabled ? config.background.color : .clear
        clippingContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Create image view that fills the container
        let imageView = UIImageView(image: context.image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = clippingContainer.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add blur effect if enabled
        if config.blur.isEnabled {
            let blurEffect = UIBlurEffect(style: config.blur.style)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = clippingContainer.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.alpha = config.blur.intensity
            clippingContainer.addSubview(imageView)
            clippingContainer.addSubview(blurView)
        } else {
            clippingContainer.addSubview(imageView)
        }
        
        containerView.addSubview(clippingContainer)
        
        return containerView
    }
}

// MARK: - Navigation Controller Delegate

@MainActor
public class KestrelTransitionDelegate: NSObject, UINavigationControllerDelegate {
    private var kestrelContext: KestrelTransitionContext?
    
    public func setKestrelContext(_ context: KestrelTransitionContext) {
        self.kestrelContext = context
    }
    
    public func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        
        switch operation {
        case .push:
            return KestrelTransitionAnimator(isPresenting: true, context: kestrelContext)
        case .pop:
            return KestrelTransitionAnimator(isPresenting: false, context: kestrelContext)
        default:
            return nil
        }
    }
}