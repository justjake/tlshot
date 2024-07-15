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
final class CursorBuilder {
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
    
    let width: Double
    let shadowWidth = 3.0
    let lineWidth = 3.0
    let visionResolution = 512.0
    let scale = 2.0
    
    private let input: Image
    private var contourInput: CGImage?
    private var pathResult: CGPath?
    private var imageResult: CGImage?
    private var result: NSCursor?
    
    init(_ image: Image, width: Double = 20.0) {
        self.input = image
        self.width = width
    }
    
    @MainActor func buildContourInput() -> CGImage? {
        contourInput = contourInput ?? Self.renderToImage(input, width: visionResolution)
        return contourInput
    }
    
    func buildPath(contourInput: CGImage) throws -> CGPath? {
        try pathResult = pathResult ?? Self.extractImagePath(contourInput, outputWidth: width, contourDetectResolution: visionResolution)
        return pathResult
    }
    
    func buildView(cgPath: CGPath) -> some View {
        let path = Path(cgPath)
        return path.background(in: path.stroke(lineWidth: lineWidth))
            .frame(width: width, height: width)
            .foregroundStyle(.black)
            .backgroundStyle(.white)
            .compositingGroup()
    }
    
    @MainActor func buildResultImage(cgPath: CGPath) -> CGImage? {
        let view = buildView(cgPath: cgPath)
            .frame(width: width * scale, height: width * scale)
        let imageRenderer = ImageRenderer(content: view)
        imageRenderer.scale = scale
        imageRenderer.isOpaque = false
        imageRenderer.proposedSize = .init(
            width: width * scale,
            height: width * scale
        )
        print("w/h", imageRenderer.proposedSize)
        imageResult = imageResult ?? imageRenderer.cgImage
        return imageResult
    }
    
    func buildCursor(resultImage: CGImage) -> NSCursor {
        let nsImage = NSImage(cgImage: resultImage, size: .init(width: width * scale, height: width * scale))
        let finalResult = result ?? NSCursor(image: nsImage, hotSpot: nsImage.size.center)
        result = finalResult
        return finalResult
    }
    
    @MainActor func buildSync() throws -> NSCursor? {
        guard let contourInput = buildContourInput() else {
            print("CursorBuilder.buildContourInput: nil")
            return nil
        }
        guard let cgPath = try buildPath(contourInput: contourInput) else {
            print("CursorBuilder.buildPath: nil")
            return nil
        }
        guard let resultImage = buildResultImage(cgPath: cgPath) else {
            print("CursorBuilder.buildResultImage: nil")
            return nil
        }
        return buildCursor(resultImage: resultImage)
    }
    
    func buildAsync() async throws -> NSCursor? {
        guard let contourInput = await buildContourInput() else {
            print("CursorBuilder.buildContourInput: nil")
            return nil
        }
        guard let cgPath = try buildPath(contourInput: contourInput) else {
            print("CursorBuilder.buildPath: nil")
            return nil
        }
        guard let resultImage = await buildResultImage(cgPath: cgPath) else {
            print("CursorBuilder.buildResultImage: nil")
            return nil
        }
        return buildCursor(resultImage: resultImage)
    }
}

struct Cursors: View {
    static var cameraFill = Image(systemName: "camera.fill")
    
    var body: some View {
        HStack {
            // Composing camera from bits
            if false {
                VStack {
                    Self.cameraFill
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                    
                    let contourInput = cameraContourInput()
                    Image(nsImage: NSImage(cgImage: contourInput, size: NSSize(width: contourInput.width, height: contourInput.height)))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100)
                    
                    let cameraPath = Path(cameraCGPath())
                    
                    let black = cameraPath
                        .foregroundStyle(.black)
                    
                    black.frame(width: 100, height: 100)
                    
                    let whiteStroke = cameraPath
                        .stroke(lineWidth: 10)
                        .foregroundStyle(.white)
                    
                    whiteStroke.frame(width: 100, height: 100)
                    
                    let mouse = black.background { whiteStroke }
                    let shadowed = mouse
                        .compositingGroup()
                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                    shadowed.frame(width: 100, height: 100)
                    
                }
            }
            
            VStack(spacing: 20) {
                Text("Camera").font(.headline)
                
                mouseView()
                
                let mouseImage = resultImage()
                let _ = print("mosueImage: \(mouseImage)")
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
//            .aspectRatio(contentMode: .fit)
//            .frame(width: cursor.image.size.width, height: cursor.image.size.height)
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
    
    @MainActor func cameraContourInput() -> CGImage {
        let cursorBuilder = CursorBuilder(Self.cameraFill, width: 100)
        return cursorBuilder.buildContourInput()!
    }
    
    @MainActor func cameraCGPath() -> CGPath {
        let cursorBuilder = CursorBuilder(Self.cameraFill, width: 100)
        let cgImage = cursorBuilder.buildContourInput()!
        return try! cursorBuilder.buildPath(contourInput: cgImage)!
    }
    
    @MainActor func mouseView() -> some View {
        let cursorBuilder = CursorBuilder(Self.cameraFill, width: 20)
        let cgImage = cursorBuilder.buildContourInput()!
        let path = try! cursorBuilder.buildPath(contourInput: cgImage)!
        return cursorBuilder.buildView(cgPath: path)
    }
    
    @MainActor func resultImage() -> CGImage {
        let cursorBuilder = CursorBuilder(Self.cameraFill, width: 20)
        let cgImage = cursorBuilder.buildContourInput()!
        let path = try! cursorBuilder.buildPath(contourInput: cgImage)!
        return cursorBuilder.buildResultImage(cgPath: path)!
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
        .background(.white)
}
