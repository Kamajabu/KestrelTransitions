//
//  KestrelTransitionNotifications.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 26/07/2025.
//

import Foundation

// MARK: - Kestrel Transition Notifications

/// Package-specific notification center for KestrelTransitions
internal var KestrelNotificationCenter = NotificationCenter.default

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

struct KestrelObserver {
    enum ObserverType {
        case presentationStarted
        case dismissalStarted
        case imageInPosition
        case sourceReached

        var name: Notification.Name {
            switch self {
            case .presentationStarted:
                return KestrelNotification.presentationStarted
            case .dismissalStarted:
                return KestrelNotification.dismissalStarted
            case .imageInPosition:
                return KestrelNotification.imageInPosition
            case .sourceReached:
                return KestrelNotification.sourceReached
            }
        }
    }

    /// Adds an observer that automatically filters notifications by transition ID
    static func addFilteredObserver(
        for type: ObserverType,
        transitionId: String,
        handler: @escaping () -> Void
    ) -> NSObjectProtocol {
        KestrelNotificationCenter.addObserver(
            forName: type.name,
            object: nil,
            queue: .main
        ) { notification in
            guard let notificationId = notification.object as? String,
                  notificationId == transitionId else {
                return
            }
            handler()
        }
    }

    /// Removes a specific observer
    static func removeObserver(_ observer: NSObjectProtocol) {
        KestrelNotificationCenter.removeObserver(observer)
    }
}
