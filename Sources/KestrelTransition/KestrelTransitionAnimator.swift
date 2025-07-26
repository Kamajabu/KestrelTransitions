//
//  KestrelTransitionAnimator.swift
//  Kestrel
//
//  Created by Kamil Buczel on 20/07/2025.
//

import UIKit
import SwiftUI

// MARK: - Kestrel Transition Context
public struct KestrelTransitionContext {
    public let sourceFrame: CGRect
    public let destinationFrame: CGRect
    public let image: UIImage
    public let sourceCornerRadius: CGFloat
    public let destinationCornerRadius: CGFloat
    public let transitionId: String
    
    public init(sourceFrame: CGRect, destinationFrame: CGRect, image: UIImage, sourceCornerRadius: CGFloat = 0, destinationCornerRadius: CGFloat = 20, transitionId: String = "") {
        self.sourceFrame = sourceFrame
        self.destinationFrame = destinationFrame
        self.image = image
        self.sourceCornerRadius = sourceCornerRadius
        self.destinationCornerRadius = destinationCornerRadius
        self.transitionId = transitionId
    }
}

// MARK: - Kestrel Transition Animator
@MainActor
public class KestrelTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval
    private let isPresenting: Bool
    private let context: KestrelTransitionContext?
    
    public init(duration: TimeInterval = 1, isPresenting: Bool, context: KestrelTransitionContext?) {
        self.duration = duration
        self.isPresenting = isPresenting
        self.context = context
        super.init()
        print("[KestrelTransition] 🎬 Animator initialized - presenting: \(isPresenting), duration: \(duration)s")
        if let context = context {
            print("[KestrelTransition] 📋 Context - source: \(context.sourceFrame), destination: \(context.destinationFrame)")
        } else {
            print("[KestrelTransition] ⚠️ No transition context available, will use default transition")
        }
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        print("[KestrelTransition] 🚀 Starting \(isPresenting ? "presentation" : "dismissal") animation")
        
        guard var context = context else {
            print("[KestrelTransition] 🚨 No context available, cannot perform transition")
            fatalError("KestrelTransition: No transition context available. Ensure kestrelTransitionSource is properly configured.")
        }
        
        // If destination frame is zero, we need to render the destination view first
        if context.destinationFrame == .zero {
            print("[KestrelTransition] ⏳ Destination frame not available, allowing view to render first...")
            
            // First, let the destination view render by showing it briefly
            guard let toViewController = transitionContext.viewController(forKey: .to) else {
                fatalError("KestrelTransition: No destination view controller available")
            }
            
            let containerView = transitionContext.containerView
            let finalFrame = transitionContext.finalFrame(for: toViewController)
            
            // Add destination view controller to trigger rendering
            toViewController.view.frame = finalFrame
            toViewController.view.alpha = 0 // Keep it invisible for now
            containerView.addSubview(toViewController.view)
            
            // Force layout to trigger bridge frame reporting
            toViewController.view.layoutIfNeeded()
            
            // Now wait for the bridge to report the frame
            var attempts = 0
            let maxAttempts = 50 // 500ms total wait time
            
            while attempts < maxAttempts {
                // Check if bridge has reported frame
                if let bridgeFrame = KestrelTransitionRegistry.shared.getDestinationFrame(for: context.transitionId),
                   bridgeFrame != .zero {
                    print("[KestrelTransition] ✅ Bridge provided destination frame after rendering: \(bridgeFrame)")
                    // Update context with bridge frame
                    context = KestrelTransitionContext(
                        sourceFrame: context.sourceFrame,
                        destinationFrame: bridgeFrame,
                        image: context.image,
                        sourceCornerRadius: context.sourceCornerRadius,
                        destinationCornerRadius: context.destinationCornerRadius,
                        transitionId: context.transitionId
                    )
                    break
                }
                
                // Small delay to allow bridge to report
                Thread.sleep(forTimeInterval: 0.01) // 10ms intervals
                attempts += 1
            }
            
            // If still no frame after waiting
            if context.destinationFrame == .zero {
                print("[KestrelTransition] 🚨 Bridge system failed to provide destination frame after \(attempts) attempts")
                fatalError("KestrelTransition: Bridge system could not provide destination frame for id '\(context.transitionId)'. Ensure kestrelTransitionTarget is properly configured and view is rendered.")
            }
        }
        
        if isPresenting {
            animatePresentation(using: transitionContext, heroContext: context)
        } else {
            animateDismissal(using: transitionContext, heroContext: context)
        }
    }
    
    private func animatePresentation(using transitionContext: UIViewControllerContextTransitioning, heroContext: KestrelTransitionContext) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
              let fromViewController = transitionContext.viewController(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        
        print("[KestrelTransition] 📱 Setting up presentation - final frame: \(finalFrame)")
        
        // Check if destination view is already added (from frame detection)
        if !containerView.subviews.contains(toViewController.view) {
            // Add destination view controller with content visible 
            toViewController.view.frame = finalFrame
            toViewController.view.alpha = 1
            containerView.addSubview(toViewController.view)
        } else {
            // View already added for frame detection, make it visible
            toViewController.view.alpha = 1
        }
        
        // Create transitioning image views for morphing effect
        print("[KestrelTransition] 🖼️ Creating transition image views")
        let sourceImageView = createTransitionImageView(from: heroContext)
        let destinationImageView = createDestinationImageView(from: heroContext)
        // Start destination image at source position but with destination internal structure
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
        print("[KestrelTransition] 🎭 Phase 1: Starting scale and move animation (\(duration * 0.6)s)")
        UIView.animate(
            withDuration: duration * 0.6,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.curveEaseInOut]
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
                sourceClippingContainer.layer.cornerRadius = heroContext.destinationCornerRadius
            }
            if let destClippingContainer = destinationImageView.subviews.last(where: { $0.layer.masksToBounds == true }) {
                destClippingContainer.layer.cornerRadius = heroContext.destinationCornerRadius
            }
            
            // Also animate shadow corner radius
            if let sourceShadow = sourceImageView.subviews.first {
                sourceShadow.layer.cornerRadius = heroContext.destinationCornerRadius
            }
            if let destShadow = destinationImageView.subviews.first {
                destShadow.layer.cornerRadius = heroContext.destinationCornerRadius
            }
            
            // Cross-fade between images
            sourceImageView.alpha = 0
            destinationImageView.alpha = 1
            
            // Fade out source view
            fromViewController.view.alpha = 0
        } completion: { _ in
            // Debug: Check if transition image size matches what we expect
            print("[KestrelTransition] 🔍 Phase 1 complete - transition image frame: \(destinationImageView.frame)")
            print("[KestrelTransition] 🔍 Expected destination frame: \(heroContext.destinationFrame)")
            
            // Notify that transition image is now in final position - time to morph!
            print("[KestrelTransition] 📢 Phase 1 complete - notifying target view to appear")
            NotificationCenter.default.post(name: Notification.Name("KestrelTransitionImageInPosition"), object: nil)
            
            // Phase 2: Fade out transition image as real image fades in
            print("[KestrelTransition] 🎭 Phase 2: Starting fade out transition image (\(self.duration * 0.4)s)")
            UIView.animate(
                withDuration: self.duration * 0.4,
                delay: 0,
                options: [.curveEaseOut]
            ) {
                // Fade out transition image
                destinationImageView.alpha = 0
            } completion: { finished in
                print("[KestrelTransition] ✅ Presentation complete - cleaning up transition views")
                sourceImageView.removeFromSuperview()
                destinationImageView.removeFromSuperview()
                fromViewController.view.alpha = 1
                
                // Clear transition in progress
                if let transitionId = self.context?.transitionId {
                    KestrelTransitionRegistry.shared.clearTransitionInProgress(transitionId)
                }

                transitionContext.completeTransition(finished)
            }
        }
    }
    
    private func animateDismissal(using transitionContext: UIViewControllerContextTransitioning, heroContext: KestrelTransitionContext) {
        guard let fromViewController = transitionContext.viewController(forKey: .from),
              let toViewController = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        
        print("[KestrelTransition] 📱 Setting up dismissal animation")
        
        // Immediately notify to hide the real image in detail view
        print("[KestrelTransition] 📢 Notifying target view to hide for dismissal")
        NotificationCenter.default.post(name: Notification.Name("KestrelTransitionDismissalStarted"), object: nil)
        
        // Add destination view controller back with initial fade
        toViewController.view.alpha = 0.3
        containerView.insertSubview(toViewController.view, belowSubview: fromViewController.view)
        
        // Create morphing image views for dismissal - start with destination image visible
        print("[KestrelTransition] 🔍 Dismissal setup - source frame: \(heroContext.sourceFrame)")
        print("[KestrelTransition] 🔍 Dismissal setup - destination frame: \(heroContext.destinationFrame)")
        
        // For dismissal, we want the destination image to start at destination size
        let destinationImageView = createDestinationImageView(from: heroContext)
        print("[KestrelTransition] 🔍 Created destination image with frame: \(destinationImageView.frame)")
        
        let sourceImageView = createTransitionImageView(from: heroContext)
        sourceImageView.frame = heroContext.destinationFrame
        sourceImageView.alpha = 0
        print("[KestrelTransition] 🔍 Created source image with frame: \(sourceImageView.frame)")
        
        // Remove autoresizing and manually size all components to destination initially
        [destinationImageView, sourceImageView].forEach { containerView in
            containerView.subviews.forEach { subview in
                subview.autoresizingMask = []
                subview.frame = CGRect(origin: .zero, size: heroContext.destinationFrame.size)
            }
        }
        
        containerView.addSubview(destinationImageView)
        containerView.addSubview(sourceImageView)
        
        // Animate dismissal in two phases
        print("[KestrelTransition] 🎭 Dismissal Phase 1: Fade out detail content (\(duration * 0.4)s)")
        UIView.animate(
            withDuration: duration * 0.4,
            delay: 0,
            options: [.curveEaseIn]
        ) {
            // Phase 1: Fade out detail content and start morphing
            fromViewController.view.alpha = 0
            destinationImageView.alpha = 0
            sourceImageView.alpha = 1
        } completion: { _ in
            // Phase 2: Move back to source while fading in list
            print("[KestrelTransition] 🎭 Dismissal Phase 2: Move back to source position (\(self.duration * 0.6)s)")
            UIView.animate(
                withDuration: self.duration * 0.6,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: [.curveEaseInOut]
            ) {
                // Move image back to source position
                sourceImageView.frame = heroContext.sourceFrame
                
                // Manually resize all internal components to source size
                sourceImageView.subviews.forEach { subview in
                    subview.frame = CGRect(origin: .zero, size: heroContext.sourceFrame.size)
                }
                
                // Animate corner radius back to source on clipping container
                if let sourceClippingContainer = sourceImageView.subviews.last(where: { $0.layer.masksToBounds == true }) {
                    sourceClippingContainer.layer.cornerRadius = heroContext.sourceCornerRadius
                }
                
                // Also animate shadow corner radius back
                if let sourceShadow = sourceImageView.subviews.first {
                    sourceShadow.layer.cornerRadius = heroContext.sourceCornerRadius
                }
                
                // Fade in list view
                toViewController.view.alpha = 1
            } completion: { finished in
                print("[KestrelTransition] ✅ Dismissal complete - cleaning up transition views")
                destinationImageView.removeFromSuperview()
                sourceImageView.removeFromSuperview()
                
                // Clear transition in progress
                KestrelTransitionRegistry.shared.clearTransitionInProgress(heroContext.transitionId)
                
                transitionContext.completeTransition(finished)
            }
        }
    }
    
    private func createTransitionImageView(from context: KestrelTransitionContext) -> UIView {
        print("[KestrelTransition] 🏗️ Creating source transition image view with frame: \(context.sourceFrame)")
        
        // Create container view for background
        let containerView = UIView(frame: context.sourceFrame)
        containerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        containerView.layer.masksToBounds = true // Ensure proper clipping during animation
        
        // Create image view that fills the container using frame-based layout for smooth animation
        let imageView = UIImageView(image: context.image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = containerView.bounds // Fill container bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight] // Resize with container
        
        containerView.addSubview(imageView)
        
        // Add subtle shadow for depth (shadow requires masksToBounds = false)
        // We'll handle clipping through a separate clipping view
        let shadowView = UIView(frame: containerView.bounds)
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadowView.layer.shadowOpacity = 0.15
        shadowView.layer.shadowRadius = 8
        shadowView.layer.masksToBounds = false
        shadowView.layer.cornerRadius = context.sourceCornerRadius
        
        // Create clipping container for proper corner radius
        let clippingContainer = UIView(frame: containerView.bounds)
        clippingContainer.layer.cornerRadius = context.sourceCornerRadius
        clippingContainer.layer.masksToBounds = true
        clippingContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        clippingContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        containerView.addSubview(shadowView)
        containerView.addSubview(clippingContainer)
        
        // Move the image to the clipping container instead
        clippingContainer.addSubview(imageView)
        
        // Reset container properties since we're using separate views for shadow and clipping
        containerView.backgroundColor = UIColor.clear
        containerView.layer.cornerRadius = 0
        containerView.layer.masksToBounds = false
        
        return containerView
    }
    
    private func createDestinationImageView(from context: KestrelTransitionContext) -> UIView {
        print("[KestrelTransition] 🏗️ Creating destination transition image view with frame: \(context.destinationFrame)")
        
        // Create container view for destination background - start with destination size
        let containerView = UIView(frame: context.destinationFrame)
        containerView.backgroundColor = UIColor.clear
        containerView.layer.cornerRadius = 0
        containerView.layer.masksToBounds = false
        
        // Create shadow view
        let shadowView = UIView(frame: containerView.bounds)
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 8)
        shadowView.layer.shadowOpacity = 0.2
        shadowView.layer.shadowRadius = 12
        shadowView.layer.masksToBounds = false
        shadowView.layer.cornerRadius = context.destinationCornerRadius
        shadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Create clipping container for proper corner radius
        let clippingContainer = UIView(frame: containerView.bounds)
        clippingContainer.layer.cornerRadius = context.destinationCornerRadius
        clippingContainer.layer.masksToBounds = true
        clippingContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        clippingContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Create image view that fills the container
        let imageView = UIImageView(image: context.image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = clippingContainer.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        containerView.addSubview(shadowView)
        containerView.addSubview(clippingContainer)
        clippingContainer.addSubview(imageView)
        
        return containerView
    }
    
    
    private func performDefaultTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
              let fromViewController = transitionContext.viewController(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        
        if isPresenting {
            toViewController.view.frame = finalFrame.offsetBy(dx: finalFrame.width, dy: 0)
            containerView.addSubview(toViewController.view)
            
            UIView.animate(withDuration: duration) {
                toViewController.view.frame = finalFrame
                fromViewController.view.frame = finalFrame.offsetBy(dx: -finalFrame.width, dy: 0)
            } completion: { finished in
                transitionContext.completeTransition(finished)
            }
        } else {
            containerView.insertSubview(toViewController.view, belowSubview: fromViewController.view)
            
            UIView.animate(withDuration: duration) {
                fromViewController.view.frame = finalFrame.offsetBy(dx: finalFrame.width, dy: 0)
            } completion: { finished in
                transitionContext.completeTransition(finished)
            }
        }
    }
}

// MARK: - Navigation Controller Delegate
@MainActor
public class KestrelTransitionDelegate: NSObject, UINavigationControllerDelegate {
    private var kestrelContext: KestrelTransitionContext?
    
    public func setKestrelContext(_ context: KestrelTransitionContext) {
        self.kestrelContext = context
    }
    
    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
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
