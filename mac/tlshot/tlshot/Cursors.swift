//
//  Cursors.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/14/24.
//

import SwiftUI
import Vision

struct Cursors: View {
    var cameraFill: Image {
        Image(systemName: "camera.fill")
    }
    
    var body: some View {
            VStack {
                cameraFill
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                
                let cameraPath = cameraPath()
                
                let black = cameraPath
                    .foregroundStyle(.black)
                
                black.frame(width: 100, height: 100)
                
                let whiteStroke = cameraPath
                    .stroke(lineWidth: 10)
                    .foregroundStyle(.white)
                
                whiteStroke.frame(width: 100, height: 100)
                
                let mouse = black.background { whiteStroke }
                mouse.frame(width: 100, height: 100)
                
                let shadowed = mouse
                    .compositingGroup()
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                shadowed.frame(width: 100, height: 100)
                
            }
    }
    
    struct OutlineData {
        
    }
    
    // Extracted outline paths are 0..1 and lose their aspect ratio.
    @MainActor func extractOutlineData(
        _ image: Image,
        contourDetectResolution: CGFloat = 512
    ) -> VNContoursObservation {
        let scaledInput = image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.black)
            .background(.white)
            .frame(width: contourDetectResolution)
            .ignoresSafeArea()
        
        let imageRenderer = ImageRenderer(content: scaledInput)
        imageRenderer.isOpaque = true
        imageRenderer.proposedSize = .init(
            width: contourDetectResolution,
            height: contourDetectResolution
        )
        
        let ciImage = CIImage(cgImage: imageRenderer.cgImage!)
        
        let req = VNDetectContoursRequest()
        req.contrastAdjustment = 1
        req.maximumImageDimension = Int(contourDetectResolution)
        let handler = VNImageRequestHandler(ciImage: ciImage)
        try! handler.perform([req])
        return (req.results?.first)!
    }
    
    // VNDetectContours outputs a normalized (0..1) and reflected
    // path. We need to restore it to the original orientation
    // and aspect ratio.
    func denormalizingTransform(_ contour: VNContour) -> CGAffineTransform {
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
    func scaleTransform(initialSize: Double, targetSize: Double) -> CGAffineTransform {
        let scaleFactor = targetSize / initialSize
        return CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
    }
    
    // View -> CGImage
    // https://stackoverflow.com/questions/69314578/convert-swiftui-view-to-nsimage
    // Image -> path
    // https://stackoverflow.com/questions/74181654/stroke-image-border-in-swiftui
    @MainActor func extractImagePath(
        _ image: Image,
        outputWidth: CGFloat,
        contourDetectResolution: CGFloat = 512
    ) -> CGPath {
        let scaledInput = image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.black)
            .background(.white)
            .frame(width: contourDetectResolution)
            .ignoresSafeArea()

        let imageRenderer = ImageRenderer(content: scaledInput)
        imageRenderer.isOpaque = true
        print("initial proposed size", imageRenderer.proposedSize = .init(width: contourDetectResolution, height: contourDetectResolution))
        
        let cgImage = imageRenderer.cgImage!
        let ciImage = CIImage(cgImage: imageRenderer.cgImage!)
        
        let req = VNDetectContoursRequest()
        req.contrastAdjustment = 1
        req.maximumImageDimension = Int(contourDetectResolution)
        let handler = VNImageRequestHandler(ciImage: ciImage)
        try! handler.perform([req])
        let observation = (req.results?.first)!
        let aspectRatio = (observation.topLevelContours.first?.aspectRatio)!
        let cgPath = observation.normalizedPath
        
        let aspectTx = CGFloat(aspectRatio)
        print("boundingBox", cgPath.boundingBox.size)
        print("pathBoundingBox", cgPath.boundingBoxOfPath)
        
        // VNDetectContours outputs a normalized (0..1) and reflected
        // path. We need to restore it to the original orientation
        // and aspect ratio.
        var transformToUnit = CGAffineTransform
            .identity
            // Reflect output across the X axis.
            .translatedBy(x: 0, y: 1)
            .scaledBy(x: 1, y: -1)
            // Apply aspect ratio to match original
            .scaledBy(x: CGFloat(observation.topLevelContours.first!.aspectRatio), y: 1)
        let unitPath = cgPath.copy(using: &transformToUnit)!
        
        // Now we have a small (still 0..1) path with the right aspect
        // ratio and orientation.
        //
        // Scale it up to fit the desired output size.
        let scaleFactor = outputWidth / unitPath.boundingBox.size.width
        var scaleTransform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        return unitPath.copy(using: &scaleTransform)!.normalized()
    }
    
    @MainActor func cameraPath() -> Path {
        let cgPath = extractImagePath(cameraFill, outputWidth: 100)
        return Path(cgPath)
    }
}

#Preview {
    Cursors()
        .expand()
}
