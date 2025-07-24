# KestrelTransitions

<p align="center">
  <img src="kestrelTransitionsLogo.png" alt="KestrelTransitions Logo" width="200"/>
</p>

A smooth, customizable transition animation library for iOS that creates beautiful hero-style transitions between views.

## Installation

### Swift Package Manager

Add KestrelTransition to your project using Xcode:

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the repository URL: `https://github.com/Kamajabu/KestrelTransitions.git`
3. Select the version you want to use
4. Add the package to your target

Alternatively, add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Kamajabu/KestrelTransitions.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "KestrelTransitions", package: "KestrelTransitions")
        ]
    )
]
```

Then import it in your Swift files:

```swift
import KestrelTransitions
```

## Features

- 🎯 **Hero Transitions**: Smooth morphing transitions between source and destination views
- 📱 **SwiftUI Integration**: Easy-to-use SwiftUI modifiers
- 🎨 **Container-based Design**: Images properly fill their background containers
- ↗️ **Dynamic Frame Calculation**: Automatic source and destination frame detection
- 🌟 **Corner Radius Morphing**: Smooth corner radius animation during transitions
- 🎪 **Spring Animations**: Natural spring-based easing for smooth motion

## Usage

### Basic Setup

1. Apply the transition modifier to your source view:

```swift
Image("your-image")
    .kestrelTransition(
        id: "unique-transition-id",
        image: UIImage(named: "your-image") ?? UIImage(),
        imageName: "your-image"
    ) { sourceFrame in
        // Handle tap and navigate
        navigateToDetail()
    }
```

2. Apply the target modifier to your destination view:

```swift
Image("your-image")
    .kestrelTransitionTarget(id: "unique-transition-id")
```

### Advanced Features

- **Dynamic Frame Registration**: The system automatically captures and matches source/destination frames
- **Fallback Frame Calculation**: Provides sensible defaults when destination frames aren't available
- **Image Repository Support**: Works with custom image loading systems
- **Size Variants**: Supports different image sizes for source vs destination (e.g., thumbnail → full size)

### Container Layout

The library uses a container-based approach where images fill their background containers:

```swift
ZStack {
    Color.blue.opacity(0.1) // Background container
    Image("image-name")
        .resizable()
        .aspectRatio(contentMode: .fill)
        .clipped()
}
.frame(width: 60, height: 60)
.cornerRadius(12)
```

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 16.0+

## Architecture

- `KestrelTransitionAnimator`: Core UIKit transition animator
- `KestrelTransitionModifier`: SwiftUI view modifier for source views  
- `KestrelTransitionTargetModifier`: SwiftUI view modifier for destination views
- `KestrelTransitionRegistry`: Central registry for managing transitions and frames
- `KestrelTransitionHelper`: Utility functions and preference keys