import XCTest
@testable import KestrelTransition

final class KestrelTransitionTests: XCTestCase {
    func testTransitionContextCreation() throws {
        let sourceFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let destinationFrame = CGRect(x: 50, y: 50, width: 200, height: 200)
        let image = UIImage()
        let imageName = "test-image"
        
        let context = KestrelTransitionContext(
            sourceFrame: sourceFrame,
            destinationFrame: destinationFrame,
            image: image,
            imageName: imageName
        )
        
        XCTAssertEqual(context.sourceFrame, sourceFrame)
        XCTAssertEqual(context.destinationFrame, destinationFrame)
        XCTAssertEqual(context.imageName, imageName)
    }
    
    func testRegistryFrameStorage() throws {
        let registry = KestrelTransitionRegistry.shared
        let testFrame = CGRect(x: 10, y: 20, width: 100, height: 150)
        let testId = "test-id"
        
        registry.setDestinationFrame(testFrame, for: testId)
        let retrievedFrame = registry.getDestinationFrame(for: testId)
        
        XCTAssertEqual(retrievedFrame, testFrame)
    }
}