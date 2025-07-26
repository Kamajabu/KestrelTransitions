//
//  KestrelTransitionNotifications.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 26/07/2025.
//

import Foundation

// MARK: - Kestrel Transition Notifications

/// Package-specific notification center for KestrelTransitions
internal let kestrelNotificationCenter = NotificationCenter()

/// Notification names used internally by KestrelTransitions
internal enum KestrelNotification {
    /// Posted when presentation transition starts - hides source view
    static let presentationStarted = Notification.Name("KestrelTransition.PresentationStarted")
    
    /// Posted when dismissal transition starts - hides target view
    static let dismissalStarted = Notification.Name("KestrelTransition.DismissalStarted")
    
    /// Posted when transition image reaches final position - shows target view
    static let imageInPosition = Notification.Name("KestrelTransition.ImageInPosition")
    
    /// Posted when dismissal animation reaches source position - shows source view
    static let sourceReached = Notification.Name("KestrelTransition.SourceReached")
}