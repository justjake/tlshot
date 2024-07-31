//
//  CrosshairView.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/30/24.
//

import SwiftUI
import SpriteKit

struct CrosshairView: View {
    static var fine: some View {
        CrosshairView(shape: CrosshairShape(
            centerSize: CGSize(square: 1),
            hairWidth: 1,
            strokeWidth: 1
        ))
        .foregroundStyle(.black)
        .backgroundStyle(.gray.opacity(0.5))
    }
    

    static func sizeToCoverAnyScreen() -> CGSize {
        var maxDimensions: CGSize = .zero
        for screen in NSScreen.screens {
            maxDimensions.width = max(screen.frame.size.width, maxDimensions.width)
            maxDimensions.height = max(screen.frame.size.height, maxDimensions.height)
        }
        return CGSize(
            width: maxDimensions.width * 2,
            height: maxDimensions.height * 2
        )
    }
    
    @MainActor
    static func renderForScreens() -> CGImage? {
        let renderer = ImageRenderer(content: fine)
        renderer.scale = NSScreen.screens.map { $0.backingScaleFactor }.max() ?? 2
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(sizeToCoverAnyScreen())
        return renderer.cgImage
    }
    
    var shape: CrosshairShape
    
    var body: some View {
        ZStack {
            shape.strokeShape().foregroundStyle(.background)
            shape
        }
    }
}

class CrosshairScene: SKScene {
    var invert = false
    var crosshairNode: SKSpriteNode
    var imageName: String
    var getPosition: () -> CGPoint?
    
    @discardableResult
    static func renderIntoImage(nsImageName: String) -> NSImage {
        let image = CrosshairView.renderForScreens()!
        let nsImage = image.nsImage(size: CrosshairView.sizeToCoverAnyScreen())!
        nsImage.setName(nsImageName)
        return nsImage
    }
    
    init(getPosition: @escaping () -> CGPoint?) {
        imageName = "Crosshair\(UUID().uuidString)"
        Self.renderIntoImage(nsImageName: imageName)
        crosshairNode = SKSpriteNode(imageNamed: imageName)
        self.getPosition = getPosition
        super.init(size: .zero)
        scaleMode = .resizeFill
        backgroundColor = .clear
        addChild(crosshairNode)
    }
    
    func setImageName(_ imageName: String) {
        if imageName == self.imageName {
            return
        }
        self.imageName = imageName
        crosshairNode.removeFromParent()
        crosshairNode = SKSpriteNode(imageNamed: imageName)
        addChild(crosshairNode)
    }
    
    override func update(_ currentTime: TimeInterval) {
        setPosition(getPosition())
    }
    
    
    func setPosition(_ point: CGPoint?) {
        guard let globalPosition = point else {
            crosshairNode.isHidden = true
            return
        }
        
        let position = if invert {
            CoordPoint.flip(globalPosition, height: 0, frame: view?.frame)
        } else {
            globalPosition
        }
        crosshairNode.position = convertPoint(fromView: position)
        crosshairNode.isHidden = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

struct CrosshairSceneView: View {
    let invert = false
    let getPosition: () -> CGPoint?
    var debugOptions: SpriteView.DebugOptions?
    var imageName: String?
    
    var scene: CrosshairScene {
        let scene = CrosshairScene(getPosition: getPosition)
        scene.invert = invert
        if let imageName = self.imageName {
            scene.setImageName(imageName)
        }
        return scene
    }
    
    var body: some View {
        SpriteView(
            scene: scene,
            options: [.allowsTransparency],
            debugOptions: debugOptions ?? []
        )
    }
}

#Preview("SwiftUI") {
    CrosshairView.fine
        .frame(width: 500, height: 300)
}


#Preview("SceneKit") {
    // https://www.hackingwithswift.com/quick-start/swiftui/how-to-integrate-spritekit-using-spriteview
    let size = CGSize(width: 500, height: 300)
    var position = CGPoint.zero
    let scene = CrosshairScene { position }
    scene.invert = true
    
    return SpriteView(scene: scene, options: [.shouldCullNonVisibleNodes, .allowsTransparency], debugOptions: [.showsFPS, .showsNodeCount])
        .frame(width: size.width, height: size.height)
        .onContinuousHover { hover in
            switch hover {
            case .active(let point): position = point
            case .ended: break
            }
        }
    
}
