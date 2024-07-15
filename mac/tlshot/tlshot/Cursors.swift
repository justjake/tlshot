//
//  Cursors.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/14/24.
//

import SwiftUI
import Vision

// View -> CGImage
// https://stackoverflow.com/questions/69314578/convert-swiftui-view-to-nsimage
// Image -> path
// https://stackoverflow.com/questions/74181654/stroke-image-border-in-swiftui
class ContourPathExtractor: ObservableObject {
    let image: Image
    let width: Double
    private let visionResolution = 512.0
    private var result: CGPath?
    
    init(image: Image, width: Double) {
        self.image = image
        self.width = width
    }
    
    @MainActor func buildSync() throws -> CGPath? {
        if let existing = result {
            return existing
        }
        
        guard let contourInput = Self.renderToImage(image, width: visionResolution) else {
            print("CursorBuilder.buildContourInput: nil")
            return nil
        }
        
        guard let contourData = try Self.extractImagePath(
            contourInput,
            outputWidth: width,
            contourDetectResolution: visionResolution
        ) else {
            print("CursorBuilder.extractImagePath: nil")
            return nil
        }
        
        self.result = contourData
        return contourData
    }
    
    func buildAsync() async throws -> CGPath? {
        if let existing = result {
            return existing
        }
        
        guard let contourInput = await Self.renderToImage(image, width: visionResolution) else {
            print("CursorBuilder.buildContourInput: nil")
            return nil
        }
        
        guard let contourData = try Self.extractImagePath(
            contourInput,
            outputWidth: width,
            contourDetectResolution: visionResolution
        ) else {
            print("CursorBuilder.extractImagePath: nil")
            return nil
        }
        
        self.result = contourData
        return contourData
    }
    
    @MainActor static func renderToImage(
        _ image: Image,
        width: CGFloat
    ) -> CGImage? {
        let scaledInput = image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.black)
            .background(.white)
            .frame(width: width)
            .ignoresSafeArea()
        
        let imageRenderer = ImageRenderer(content: scaledInput)
        imageRenderer.isOpaque = true
        imageRenderer.proposedSize = .init(
            width: width,
            height: width
        )
        return imageRenderer.cgImage
    }
    
    // Extracted outline paths are 0..1 and lose their aspect ratio.
    static func extractOutlineData(
        _ cgImage: CGImage,
        contourDetectResolution: CGFloat
    ) throws -> VNContoursObservation? {
        let ciImage = CIImage(cgImage: cgImage)
        let req = VNDetectContoursRequest()
        req.contrastAdjustment = 1
        req.maximumImageDimension = Int(contourDetectResolution)
        let handler = VNImageRequestHandler(ciImage: ciImage)
        try handler.perform([req])
        return req.results?.first
    }
    
    // VNDetectContours outputs a normalized (0..1) and reflected
    // path. We need to restore it to the original orientation
    // and aspect ratio.
    static func denormalizingTransform(_ contour: VNContour) -> CGAffineTransform {
        CGAffineTransform
            .identity
        // Reflect output across the X axis.
            .translatedBy(x: 0, y: 1)
            .scaledBy(x: 1, y: -1)
        // Apply aspect ratio to match original
            .scaledBy(x: CGFloat(contour.aspectRatio), y: 1)
    }
    
    // When we have a small (still 0..1) path with the right aspect
    // ratio and orientation.
    //
    // Scale it up to fit the desired output size.
    static func scaleTransform(initialSize: Double, targetSize: Double) -> CGAffineTransform {
        let scaleFactor = targetSize / initialSize
        return CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
    }
    
    static func extractImagePath(
        _ cgImage: CGImage,
        outputWidth: CGFloat,
        contourDetectResolution: CGFloat
    ) throws -> CGPath? {
        guard let observation = try extractOutlineData(cgImage, contourDetectResolution: contourDetectResolution) else {
            return nil
        }
        
        guard let firstContour = observation.topLevelContours.first else {
            return nil
        }
        var tx1 = denormalizingTransform(firstContour)
        guard let denormalizedPath = observation.normalizedPath.copy(using: &tx1) else {
            return nil
        }
        var tx2 = scaleTransform(
            initialSize: denormalizedPath.boundingBox.width,
            targetSize: outputWidth)
        return denormalizedPath.copy(using: &tx2)
    }
}

struct ImageProps: Equatable {
    static let defaults = ImageProps(
        width: 40,
        scale: 2,
        proposedSize: .init(width: 40, height: 40)
    )
    
    let width: Double
    let scale: Double
    let proposedSize: ProposedViewSize
}

struct Empty: Equatable {}

class ViewRenderHolder<Content: View>: ViewRenderHolderWithProps<Empty, Content> {
    
    init(imageProps: ImageProps = ImageProps.defaults, render: @escaping () -> Content) {
        super.init(props: Empty(), imageProps: imageProps, render: { _ in render() })
    }
}
    

class ViewRenderHolderWithProps<
    Props: Equatable,
    Content: View
>: ObservableObject {
    @Published public var props: Props
    private let render: (Props) -> Content
    @Published private var lastRenderResult: Content?
    
    @Published private var imageProps: ImageProps
    @Published private var lastImageResult: CGImage?
    private var renderer: ImageRenderer<Content>?
    
    init(
        props: Props,
        imageProps: ImageProps = ImageProps.defaults,
        render: @escaping (Props) -> Content
    ) {
        self.props = props
        self.render = render
        self.imageProps = imageProps
    }
    
    @MainActor func render(
        props changeProps: Props? = nil,
        imageProps changeImageProps: ImageProps? = nil
    ) -> CGImage? {
        if let newProps = changeProps, newProps != props {
            lastRenderResult = nil
            lastImageResult = nil
            props = newProps
        }
        
        let renderResult = lastRenderResult ?? render(self.props)
        lastRenderResult = renderResult
        
        if let newImageProps = changeImageProps, newImageProps != imageProps {
            lastImageResult = nil
        }
        lastImageResult = lastImageResult ?? renderImage(renderResult)
        
        return lastImageResult
    }
    
    @MainActor private func renderImage(_ view: Content) -> CGImage? {
        let renderer = self.renderer ?? ImageRenderer(content: view)
        self.renderer = renderer
        renderer.scale = imageProps.scale // hi
        renderer.proposedSize = imageProps.proposedSize
        renderer.isOpaque = false
        print("imageProps \(imageProps)")
        return renderer.cgImage
    }
}

struct CameraWithStroke: View {
    let cgPath: CGPath
    
    let width: Double
    let lineWidth = 3.0
    
    var body: some View {
        let path = Path(cgPath)
        return path.background(in: path.stroke(lineWidth: lineWidth))
            .frame(width: width, height: width)
            .foregroundStyle(.black)
            .backgroundStyle(.white)
            .compositingGroup()
    }
}

struct Cursors: View {
    static var cameraPath = ContourPathExtractor(image: Image(systemName: "camera.fill"), width: 40)
    
    @MainActor static var cameraView = CameraWithStroke(cgPath: try! cameraPath.buildSync()!, width: 40)
   
    @MainActor static var cameraRenderer = ViewRenderHolder(
    ) { cameraView }
    
    var body: some View {
        HStack {
            VStack(spacing: 20) {
                Text("Camera").font(.headline)
                
                mouseView()
                
                let mouseImage = Self.cameraRenderer.render()!
//                let _ = print("mosueImage: \(mouseImage)")
                Image(nsImage:
                        NSImage(cgImage: mouseImage, size: NSSize(width: mouseImage.width, height: mouseImage.height)))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)

            }.frame(width: 100)
            
            VStack(spacing: 20) {
                Text("Badging").font(.headline)
                
                cameraWithBadge("plus.circle.fill")
                cameraWithBadge("minus.circle.fill")

                ZStack {
                    cursorImage(NSCursor.arrow)
                    CursorSymbolBadge(systemName: "plus.circle.fill")
                        .mouseShadow()
                        .offset(x: 14, y: 12)
                }
                
                ZStack {
                    cursorImage(NSCursor.pointingHand)
                    CursorSymbolBadge(systemName: "plus.circle.fill")
                        .mouseShadow()
                        .offset(x: 14, y: 12)
                }
                
                ZStack {
                    cursorImage(NSCursor.pointingHand)
                    CursorSymbolBadge(systemName: "minus.circle.fill")
                        .mouseShadow()
                        .offset(x: 14, y: 12)
                }
            }
        }
    }
    
    func cursorImage(_ cursor: NSCursor) -> some View {
        Image(nsImage: cursor.image)
    }
    
    @MainActor func mouseView() -> some View {
        Self.cameraView
    }
    
    
    @MainActor func cameraWithBadge(_ badge: String) -> some View {
        ZStack {
            mouseView()
            CursorSymbolBadge(systemName: badge)
                .offset(x: 12, y: 6)
        }
        .compositingGroup()
        .shadow(radius: 1, x:0, y:1)
    }
}

extension View {
    func mouseShadow() -> some View {
        self.shadow(radius: 1, y: 1)
    }
}

#Preview {
    Cursors()
        .expand()
}
