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
        
        kestrelLog("Animator initialized - presenting: \(isPresenting)", level: .info, context: context?.transitionId)
        
        if let context = context {
            kestrelLog("Source: \(context.sourceFrame), destination: \(context.destinationFrame)", level: .debug, context: context.transitionId)
        } else {
            kestrelLog("No transition context available", level: .warning)
        }
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return context?.configuration.duration ?? 1.0
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        kestrelLog("Starting \(isPresenting ? "presentation" : "dismissal") animation", level: .info, context: context?.transitionId)
        
        guard var context = context else {
            kestrelLog("No context available, cannot perform transition", level: .error)
            fatalError("KestrelTransition: No transition context available. Ensure kestrelTransitionSource is properly configured.")
        }
        
        // If destination frame is zero, we need to render the destination view first
        if context.destinationFrame == .zero {
            waitForDestinationFrame(context: context, transitionContext: transitionContext)
        }
        
        if isPresenting {
            // Notify that presentation is starting - hide source view
            KestrelNotificationCenter.post(
                name: KestrelNotification.presentationStarted,
                object: context.transitionId
            )
            animatePresentation(using: transitionContext, heroContext: context)
        } else {
            animateDismissal(using: transitionContext, heroContext: context)
        }
    }
    
    private func waitForDestinationFrame(
        context: KestrelTransitionContext,
        transitionContext: UIViewControllerContextTransitioning
    ) {
        kestrelLog("Destination frame not available, waiting for render", level: .warning, context: context.transitionId)
        
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

            if context.destinationFrame != .zero {
                kestrelLog("Destination frame is now available: \(context.destinationFrame)", level: .info, context: context.transitionId)
                return
            }

            Thread.sleep(forTimeInterval: 0.01) // 10ms intervals
            attempts += 1
        }
        
        kestrelLog("Bridge system failed after \(attempts) attempts", level: .error, context: context.transitionId)
        fatalError("KestrelTransition: Bridge system could not provide destination frame for id '\(context.transitionId)'. Ensure kestrelTransitionTarget is properly configured and view is rendered.")
    }
    
    /// Animates presentation transition with image morphing and view fade-in
    private func animatePresentation(using transitionContext: UIViewControllerContextTransitioning, heroContext: KestrelTransitionContext) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
              let fromViewController = transitionContext.viewController(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }
        
        setupDestinationView(toViewController, transitionContext: transitionContext)
        let (sourceImageView, destinationImageView) = setupPresentationImageViews(heroContext, transitionContext: transitionContext)
        
        performPresentationAnimation(
            sourceImageView: sourceImageView,
            destinationImageView: destinationImageView,
            fromViewController: fromViewController,
            toViewController: toViewController,
            heroContext: heroContext,
            transitionContext: transitionContext
        )
    }
    
    /// Sets up destination view controller for presentation
    private func setupDestinationView(_ toViewController: UIViewController, transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        
        if !containerView.subviews.contains(toViewController.view) {
            toViewController.view.frame = finalFrame
            toViewController.view.alpha = 0
            containerView.addSubview(toViewController.view)
        } else {
            toViewController.view.alpha = 0
        }
    }
    
    /// Creates and configures image views for presentation transition
    private func setupPresentationImageViews(
        _ heroContext: KestrelTransitionContext, transitionContext: UIViewControllerContextTransitioning
    ) -> (UIView, UIView) {
        let containerView = transitionContext.containerView
        
        let sourceImageView = createTransitionImageView(from: heroContext)
        let destinationImageView = createDestinationImageView(from: heroContext)
        
        destinationImageView.frame = heroContext.sourceFrame
        destinationImageView.alpha = 0
        
        // Configure manual sizing for destination image view
        destinationImageView.subviews.forEach { subview in
            subview.autoresizingMask = []
            subview.frame = CGRect(origin: .zero, size: heroContext.sourceFrame.size)
        }
        
        containerView.addSubview(sourceImageView)
        containerView.addSubview(destinationImageView)
        
        return (sourceImageView, destinationImageView)
    }
    
    /// Performs the main presentation animation with morphing and fade effects
    private func performPresentationAnimation(
        sourceImageView: UIView,
        destinationImageView: UIView,
        fromViewController: UIViewController,
        toViewController: UIViewController,
        heroContext: KestrelTransitionContext,
        transitionContext: UIViewControllerContextTransitioning
    ) {
        let config = heroContext.configuration

        kestrelLog("Starting presentation animation from \(heroContext.sourceFrame) to \(heroContext.destinationFrame)", level: .info, context: heroContext.transitionId)

        UIView.animate(
            withDuration: config.duration * 0.6,
            delay: 0,
            usingSpringWithDamping: config.springDamping,
            initialSpringVelocity: config.springVelocity,
            options: config.animationOptions
        ) {
            // Transform image views to destination position and size
            sourceImageView.frame = heroContext.destinationFrame
            destinationImageView.frame = heroContext.destinationFrame
            
            // Resize internal components
            [sourceImageView, destinationImageView].forEach { containerView in
                containerView.subviews.forEach { subview in
                    subview.frame = CGRect(origin: .zero, size: heroContext.destinationFrame.size)
                }
            }
            
            // Animate corner radius morphing
            self.animateCornerRadiusMorphing(sourceImageView, destinationImageView, config: config)
            
            // Cross-fade images and views
            sourceImageView.alpha = 0
            destinationImageView.alpha = 1

            fromViewController.view.alpha = 0
            toViewController.view.alpha = 1
        } completion: { _ in
            self.completePresentationTransition(
                sourceImageView: sourceImageView,
                destinationImageView: destinationImageView,
                fromViewController: fromViewController,
                heroContext: heroContext,
                transitionContext: transitionContext
            )
        }
    }
    
    /// Animates corner radius changes during image morphing
    private func animateCornerRadiusMorphing(_ sourceImageView: UIView, _ destinationImageView: UIView, config: KestrelTransitionConfiguration) {
        // Animate corner radius on clipping containers
        if let sourceClippingContainer = sourceImageView.subviews.last(where: { $0.layer.masksToBounds == true }) {
            sourceClippingContainer.layer.cornerRadius = config.cornerRadius.destination
        }
        if let destClippingContainer = destinationImageView.subviews.last(where: { $0.layer.masksToBounds == true }) {
            destClippingContainer.layer.cornerRadius = config.cornerRadius.destination
        }
        
        // Animate shadow corner radius if enabled
        if config.shadow.isEnabled {
            if let sourceShadow = sourceImageView.subviews.first {
                sourceShadow.layer.cornerRadius = config.cornerRadius.destination
            }
            if let destShadow = destinationImageView.subviews.first {
                destShadow.layer.cornerRadius = config.cornerRadius.destination
            }
        }
    }
    
    /// Completes presentation transition with cleanup
    private func completePresentationTransition(
        sourceImageView: UIView,
        destinationImageView: UIView,
        fromViewController: UIViewController,
        heroContext: KestrelTransitionContext,
        transitionContext: UIViewControllerContextTransitioning
    ) {
        kestrelLog("Completing presentation transition", level: .info, context: heroContext.transitionId)

        KestrelNotificationCenter.post(name: KestrelNotification.imageInPosition, object: heroContext.transitionId)

        sourceImageView.removeFromSuperview()
        destinationImageView.removeFromSuperview()
        fromViewController.view.alpha = 1
        
        transitionContext.completeTransition(true)
    }
    
    /// Animates dismissal transition with image reverse morphing and view fade-out
    private func animateDismissal(using transitionContext: UIViewControllerContextTransitioning, heroContext: KestrelTransitionContext) {
        guard let fromViewController = transitionContext.viewController(forKey: .from),
              let toViewController = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        
        // Notify target to hide and setup source view
        KestrelNotificationCenter.post(name: KestrelNotification.dismissalStarted, object: heroContext.transitionId)
        
        setupSourceViewForDismissal(toViewController, transitionContext: transitionContext)
        
        let (sourceImageView, destinationImageView) = setupDismissalImageViews(heroContext, transitionContext: transitionContext)
        
        performDismissalAnimation(
            sourceImageView: sourceImageView,
            destinationImageView: destinationImageView,
            fromViewController: fromViewController,
            toViewController: toViewController,
            heroContext: heroContext,
            transitionContext: transitionContext
        )
    }
    
    /// Sets up source view controller for dismissal
    private func setupSourceViewForDismissal(_ toViewController: UIViewController, transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        toViewController.view.alpha = 0.3
        containerView.insertSubview(toViewController.view, belowSubview: containerView.subviews.last!)
    }
    
    /// Creates and configures image views for dismissal transition
    private func setupDismissalImageViews(_ heroContext: KestrelTransitionContext, transitionContext: UIViewControllerContextTransitioning) -> (UIView, UIView) {
        let containerView = transitionContext.containerView
        
        let destinationImageView = createDestinationImageView(from: heroContext)
        let sourceImageView = createTransitionImageView(from: heroContext)
        sourceImageView.frame = heroContext.destinationFrame
        sourceImageView.alpha = 0
        
        // Configure manual sizing for both image views
        [destinationImageView, sourceImageView].forEach { containerView in
            containerView.subviews.forEach { subview in
                subview.autoresizingMask = []
                subview.frame = CGRect(origin: .zero, size: heroContext.destinationFrame.size)
            }
        }
        
        containerView.addSubview(destinationImageView)
        containerView.addSubview(sourceImageView)
        
        return (sourceImageView, destinationImageView)
    }
    
    /// Performs the main dismissal animation with reverse morphing
    private func performDismissalAnimation(
        sourceImageView: UIView,
        destinationImageView: UIView,
        fromViewController: UIViewController,
        toViewController: UIViewController,
        heroContext: KestrelTransitionContext,
        transitionContext: UIViewControllerContextTransitioning
    ) {
        let config = heroContext.configuration

        UIView.animate(
            withDuration: config.duration,
            delay: 0,
            usingSpringWithDamping: config.springDamping,
            initialSpringVelocity: config.springVelocity,
            options: config.animationOptions
        ) {
            // Fade out detail content and cross-fade images
            fromViewController.view.alpha = 0
            destinationImageView.alpha = 0

            sourceImageView.alpha = 1

            
            // Transform image back to source position and size
            sourceImageView.frame = heroContext.sourceFrame
            destinationImageView.frame = heroContext.sourceFrame

            // Resize internal components
            [sourceImageView, destinationImageView].forEach { containerView in
                containerView.subviews.forEach { subview in
                    subview.frame = CGRect(origin: .zero, size: heroContext.sourceFrame.size)
                }
            }

            // Reverse corner radius morphing
            self.animateReverseCornerRadiusMorphing(sourceImageView, config: config)
            
            // Fade in source view
            toViewController.view.alpha = 1
        } completion: { finished in
            self.completeDismissalTransition(
                sourceImageView: sourceImageView,
                destinationImageView: destinationImageView,
                heroContext: heroContext,
                transitionContext: transitionContext,
                finished: finished
            )
        }
    }
    
    /// Animates corner radius changes back to source during dismissal
    private func animateReverseCornerRadiusMorphing(_ sourceImageView: UIView, config: KestrelTransitionConfiguration) {
        if let sourceClippingContainer = sourceImageView.subviews.last(where: { $0.layer.masksToBounds == true }) {
            sourceClippingContainer.layer.cornerRadius = config.cornerRadius.source
        }
        
        if config.shadow.isEnabled {
            if let sourceShadow = sourceImageView.subviews.first {
                sourceShadow.layer.cornerRadius = config.cornerRadius.source
            }
        }
    }
    
    /// Completes dismissal transition with cleanup
    private func completeDismissalTransition(
        sourceImageView: UIView,
        destinationImageView: UIView,
        heroContext: KestrelTransitionContext,
        transitionContext: UIViewControllerContextTransitioning,
        finished: Bool
    ) {
        KestrelNotificationCenter.post(
            name: KestrelNotification.sourceReached,
            object: heroContext.transitionId
        )
        
        destinationImageView.removeFromSuperview()
        sourceImageView.removeFromSuperview()
        
        transitionContext.completeTransition(finished)
    }
    
    private func createTransitionImageView(from context: KestrelTransitionContext) -> UIView {
        kestrelLog("Creating source image view: \(context.sourceFrame)", level: .debug, context: context.transitionId)
        
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
        kestrelLog("Creating destination image view: \(context.destinationFrame)", level: .debug, context: context.transitionId)
        
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
