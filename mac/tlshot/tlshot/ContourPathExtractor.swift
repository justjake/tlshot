//
//  ContourPathExtractor.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/15/24.
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
    
    init(image: Image, extractedPathWidth: Double) {
        self.image = image
        self.width = extractedPathWidth
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
