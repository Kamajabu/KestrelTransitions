//
//  KestrelTransitionConfiguration.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 26/07/2025.
//

import UIKit

// MARK: - Transition Configuration

/// Comprehensive configuration for KestrelTransition animations
public struct KestrelTransitionConfiguration {
    
    // MARK: - Animation Properties
    
    /// Duration of the transition animation
    public let duration: TimeInterval
    
    /// Spring damping for the animation (0.0 - 1.0)
    public let springDamping: CGFloat
    
    /// Initial spring velocity
    public let springVelocity: CGFloat
    
    /// Animation curve options
    public let animationOptions: UIView.AnimationOptions
    
    // MARK: - Visual Properties
    
    /// Corner radius configuration
    public let cornerRadius: CornerRadiusConfig
    
    /// Shadow configuration
    public let shadow: ShadowConfig
    
    /// Blur effect configuration
    public let blur: BlurConfig
    
    /// Background configuration
    public let background: BackgroundConfig
    
    // MARK: - Initialization
    
    public init(
        duration: TimeInterval = 1.0,
        springDamping: CGFloat = 0.8,
        springVelocity: CGFloat = 0.0,
        animationOptions: UIView.AnimationOptions = [.curveEaseInOut],
        cornerRadius: CornerRadiusConfig = .default,
        shadow: ShadowConfig = .default,
        blur: BlurConfig = .none,
        background: BackgroundConfig = .clear
    ) {
        self.duration = duration
        self.springDamping = springDamping
        self.springVelocity = springVelocity
        self.animationOptions = animationOptions
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.blur = blur
        self.background = background
    }
    
    // MARK: - Presets
    
    /// Default configuration with subtle animations
    public static let `default` = KestrelTransitionConfiguration()
    
    /// Fast configuration for snappy transitions
    public static let fast = KestrelTransitionConfiguration(
        duration: 0.6,
        springDamping: 0.9,
        springVelocity: 0.1
    )
    
    /// Slow configuration for dramatic transitions
    public static let slow = KestrelTransitionConfiguration(
        duration: 1.5,
        springDamping: 0.7,
        springVelocity: 0.0
    )
    
    /// Configuration with blur effect
    public static let blurred = KestrelTransitionConfiguration(
        blur: .light
    )
    
    /// Configuration with pronounced shadow
    public static let shadowed = KestrelTransitionConfiguration(
        shadow: .pronounced
    )
}

// MARK: - Corner Radius Configuration

public struct CornerRadiusConfig {
    public let source: CGFloat
    public let destination: CGFloat
    
    public init(source: CGFloat, destination: CGFloat) {
        self.source = source
        self.destination = destination
    }
    
    public static let `default` = CornerRadiusConfig(source: 12, destination: 20)
    public static let sharp = CornerRadiusConfig(source: 0, destination: 0)
    public static let rounded = CornerRadiusConfig(source: 16, destination: 24)
}

// MARK: - Shadow Configuration

public struct ShadowConfig {
    public let isEnabled: Bool
    public let color: UIColor
    public let offset: CGSize
    public let opacity: Float
    public let radius: CGFloat
    
    public init(
        isEnabled: Bool = true,
        color: UIColor = .black,
        offset: CGSize = CGSize(width: 0, height: 4),
        opacity: Float = 0.15,
        radius: CGFloat = 8
    ) {
        self.isEnabled = isEnabled
        self.color = color
        self.offset = offset
        self.opacity = opacity
        self.radius = radius
    }
    
    public static let `default` = ShadowConfig()
    public static let none = ShadowConfig(isEnabled: false)
    public static let subtle = ShadowConfig(opacity: 0.1, radius: 4)
    public static let pronounced = ShadowConfig(
        offset: CGSize(width: 0, height: 8),
        opacity: 0.25,
        radius: 16
    )
}

// MARK: - Blur Configuration

public struct BlurConfig {
    public let isEnabled: Bool
    public let style: UIBlurEffect.Style
    public let intensity: CGFloat
    
    public init(
        isEnabled: Bool = false,
        style: UIBlurEffect.Style = .systemMaterial,
        intensity: CGFloat = 1.0
    ) {
        self.isEnabled = isEnabled
        self.style = style
        self.intensity = intensity
    }
    
    public static let none = BlurConfig(isEnabled: false)
    public static let light = BlurConfig(isEnabled: true, style: .systemThinMaterial, intensity: 0.8)
    public static let medium = BlurConfig(isEnabled: true, style: .systemMaterial)
    public static let heavy = BlurConfig(isEnabled: true, style: .systemThickMaterial, intensity: 1.2)
}

// MARK: - Background Configuration

public struct BackgroundConfig {
    public let isEnabled: Bool
    public let color: UIColor
    
    public init(isEnabled: Bool = false, color: UIColor = .clear) {
        self.isEnabled = isEnabled
        self.color = color
    }
    
    public static let clear = BackgroundConfig(isEnabled: false)
    public static let subtle = BackgroundConfig(isEnabled: true, color: UIColor.systemGray6.withAlphaComponent(0.3))
    public static let tinted = BackgroundConfig(isEnabled: true, color: UIColor.systemBlue.withAlphaComponent(0.1))
}

// MARK: - Transition Context with Configuration

/// Enhanced transition context that includes configuration
public struct KestrelTransitionContext {
    public let sourceFrame: CGRect
    public let destinationFrame: CGRect
    public let image: UIImage
    public let transitionId: String
    public let configuration: KestrelTransitionConfiguration
    
    public init(
        sourceFrame: CGRect,
        destinationFrame: CGRect,
        image: UIImage,
        transitionId: String = "",
        configuration: KestrelTransitionConfiguration = .default
    ) {
        self.sourceFrame = sourceFrame
        self.destinationFrame = destinationFrame
        self.image = image
        self.transitionId = transitionId
        self.configuration = configuration
    }
}