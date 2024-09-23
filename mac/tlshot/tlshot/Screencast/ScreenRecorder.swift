//
//  ScreenCaptureKit-Recording-example
//
//  Created by Tom Lokhorst on 2023-01-18.
//  Imported by Jake Teton-Landis on 2024-09-21.
//

import AVFoundation
import CoreGraphics
import ScreenCaptureKit
import VideoToolbox

enum RecordMode {
    case h264_sRGB
    case hevc_displayP3

    // I haven't gotten HDR recording working yet.
    // The commented out code is my best attempt, but still results in "blown out whites".
    //
    // Any tips are welcome!
    // - Tom
//    case hevc_displayP3_HDR
}

class ScreenRecorder {
    private let videoSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.VideoSampleBufferQueue")
    private let audioSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.AudioSampleBufferQueue")

    private let streamOutput: StreamOutput
    private var assetWriter: AVAssetWriter?
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput?
    private let micInput: AVAssetWriterInput?
    
    static func streamConfiguration(for source: SCContentFilter, cropRect: CGRect?, recordAudio: Bool, videoFormat: RecordMode) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        
        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
        // the memory footprint of WindowServer.
        configuration.queueDepth = 6 // 4 minimum, or it becomes very stuttery
        
        // Make sure to take displayScaleFactor into account
        // otherwise, image is scaled up and gets blurry
        let displayScalingFactor = Int(source.pointPixelScale)
        if let cropRect = cropRect {
            // ScreenCaptureKit uses top-left of screen as origin
            configuration.sourceRect = cropRect
            configuration.width = Int(cropRect.width) * displayScalingFactor
            configuration.height = Int(cropRect.height) * displayScalingFactor
        } else {
            let sourceSize = source.contentRect.size
            configuration.width = Int(sourceSize.width) * displayScalingFactor
            configuration.height = Int(sourceSize.height) * displayScalingFactor
        }
        
        // Set pixel format an color space, see CVPixelBuffer.h
        switch videoFormat {
        case .h264_sRGB:
            configuration.pixelFormat = kCVPixelFormatType_32BGRA // 'BGRA'
            configuration.colorSpaceName = CGColorSpace.sRGB
        case .hevc_displayP3:
            configuration.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked // 'l10r'
            configuration.colorSpaceName = CGColorSpace.displayP3
            //        case .hevc_displayP3_HDR:
            //            configuration.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked // 'l10r'
            //            configuration.colorSpaceName = CGColorSpace.displayP3
        }
        
        configuration.capturesAudio = recordAudio
        return configuration
    }

    init(config: SCStreamConfiguration, mode: RecordMode) async throws {
        
        // AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
        // Downsize to fit a larger display back into in 4K
        // Note `config` width/height is already scaled from screen points to pixels
        let videoSize = downsizedVideoSize(source: CGSize(width: config.width, height: config.height) , scaleFactor: 1, mode: mode)

        // Use the preset as large as possible, size will be reduced to screen size by computed videoSize
        guard let assistant = AVOutputSettingsAssistant(preset: mode.preset) else {
            throw RecordingError("Can't create AVOutputSettingsAssistant")
        }
        assistant.sourceVideoFormat = try CMVideoFormatDescription(videoCodecType: mode.videoCodecType, width: videoSize.width, height: videoSize.height)
        assistant.sourceAudioFormat = try CMAudioFormatDescription(videoCodecType: mode.videoCodecType, width: videoSize.width, height: videoSize.height)

        guard var videoSettings = assistant.videoSettings else {
            throw RecordingError("AVOutputSettingsAssistant has no videoSettings")
        }
        videoSettings[AVVideoWidthKey] = videoSize.width
        videoSettings[AVVideoHeightKey] = videoSize.height

        // Configure video color properties and compression properties based on RecordMode
        // See AVVideoSettings.h and VTCompressionProperties.h
        videoSettings[AVVideoColorPropertiesKey] = mode.videoColorProperties
        if let videoProfileLevel = mode.videoProfileLevel {
            var compressionProperties: [String: Any] = videoSettings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
            compressionProperties[AVVideoProfileLevelKey] = videoProfileLevel
            videoSettings[AVVideoCompressionPropertiesKey] = compressionProperties as NSDictionary
        }

        // Create AVAssetWriter input for video, based on the output settings from the Assistant
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        
        audioInput = if config.capturesAudio  {
            AVAssetWriterInput(mediaType: .audio, outputSettings: assistant.audioSettings)
        } else {
            nil
        }
        micInput = if #available(macOS 15.0, *) {
            if config.captureMicrophone  {
                AVAssetWriterInput(mediaType: .audio, outputSettings: assistant.audioSettings)
            } else {
                nil
            }
        } else {
            nil
        }

        streamOutput = StreamOutput(videoInput: videoInput, audioInput: audioInput, micInput: micInput)
    }
    
    private func buildAssetWriter(url: URL) throws -> AVAssetWriter {
        let assetWriter = try AVAssetWriter(url: url, fileType: .mp4)
        // Adding videoInput to assetWriter
        guard assetWriter.canAdd(videoInput) else {
            throw RecordingError("Can't add video input to asset writer")
        }
        assetWriter.add(videoInput)
        
        if let audioInput = audioInput {
            guard assetWriter.canAdd(audioInput) else {
                throw RecordingError("Can't add audio input to asset writer")
            }
            assetWriter.add(audioInput)
        }
        
        if let micInput = micInput {
            guard assetWriter.canAdd(micInput) else {
                throw RecordingError("Can't add mic input to asset writer")
            }
            assetWriter.add(micInput)
        }
        
        return assetWriter
    }
    
    var stream: SCStream?
    func setInput(stream: SCStream) throws {
        if self.stream == stream {
            return
        }
        
        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
        if audioInput != nil {
            try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
        }
        if #available(macOS 15.0, *) {
            if micInput != nil {
                try stream.addStreamOutput(streamOutput, type: .microphone, sampleHandlerQueue: audioSampleBufferQueue)
            }
        }
        self.stream = stream
    }
    
    func removeFromInput() throws {
        try stream?.removeStreamOutput(streamOutput, type: .screen)
        if audioInput != nil {
            try stream?.removeStreamOutput(streamOutput, type: .audio)
        }
        if #available(macOS 15.0, *) {
            if micInput != nil {
                try stream?.removeStreamOutput(streamOutput, type: .microphone)
            }
        }
        self.stream = nil
    }

    func startRecording(url: URL) async throws {
        let assetWriter = try self.assetWriter ?? self.buildAssetWriter(url: url)
        self.assetWriter = assetWriter
        guard assetWriter.startWriting() else {
            if let error = assetWriter.error {
                throw error
            }
            throw RecordingError("Couldn't start writing to AVAssetWriter")
        }

        // Start the AVAssetWriter session at source time .zero, sample buffers will need to be re-timed
        assetWriter.startSession(atSourceTime: .zero)
        streamOutput.sessionStarted = true
        print("\(self).startRecording")
    }

    func stopRecording() async throws {
        print("\(self).stopRecording")
        streamOutput.sessionStarted = false
        
        guard let assetWriter = self.assetWriter else {
            throw RecordingError("Not currently recording")
        }

        // Repeat the last frame and add it at the current time
        // In case no changes happend on screen, and the last frame is from long ago
        // This ensures the recording is of the expected length
        try streamOutput.videoInput.appendLastSample()

        // Stop the AVAssetWriter session at time of the repeated frame
        assetWriter.endSession(atSourceTime: streamOutput.lastSampleTime)

        // Finish writing
        videoInput.markAsFinished()
        audioInput?.markAsFinished()
        micInput?.markAsFinished()
        await assetWriter.finishWriting()
        print("assetWriter.didFinishWriting")
        
        try self.removeFromInput()
    }

    private class StreamOutput: NSObject, SCStreamOutput {
        var videoInput: InputSession
        var audioInput: InputSession?
        var micInput: InputSession?
        var sessionStarted = false
        
        struct InputSession {
            var input: AVAssetWriterInput
            var firstSampleTime: CMTime = .zero
            var lastSampleBuffer: CMSampleBuffer?
            
            mutating func append(_ sampleBuffer: CMSampleBuffer) {
                if input.isReadyForMoreMediaData {
                    // Save the timestamp of the current sample, all future samples will be offset by this
                    if firstSampleTime == .zero {
                        firstSampleTime = sampleBuffer.presentationTimeStamp
                    }
                    
                    // Offset the time of the sample buffer, relative to the first sample
                    let lastSampleTime = sampleBuffer.presentationTimeStamp - firstSampleTime
                    
                    // Always save the last sample buffer.
                    // This is used to "fill up" empty space at the end of the recording.
                    //
                    // Note that this permanently captures one of the sample buffers
                    // from the ScreenCaptureKit queue.
                    // Make sure reserve enough in SCStreamConfiguration.queueDepth
                    lastSampleBuffer = sampleBuffer
                    
                    // Create a new CMSampleBuffer by copying the original, and applying the new presentationTimeStamp
                    let timing = CMSampleTimingInfo(duration: sampleBuffer.duration, presentationTimeStamp: lastSampleTime, decodeTimeStamp: sampleBuffer.decodeTimeStamp)
                    if let retimedSampleBuffer = try? CMSampleBuffer(copying: sampleBuffer, withNewTiming: [timing]) {
                        input.append(retimedSampleBuffer)
                    } else {
                        print("Couldn't copy CMSampleBuffer, dropping frame")
                    }
                } else {
                    print("AVAssetWriterInput isn't ready, dropping frame")
                }
            }
            
            mutating func appendLastSample() throws {
                if let originalBuffer = lastSampleBuffer {
                    let additionalTime = CMTime(seconds: ProcessInfo.processInfo.systemUptime, preferredTimescale: 100) - firstSampleTime
                    let timing = CMSampleTimingInfo(duration: originalBuffer.duration, presentationTimeStamp: additionalTime, decodeTimeStamp: originalBuffer.decodeTimeStamp)
                    let additionalSampleBuffer = try CMSampleBuffer(copying: originalBuffer, withNewTiming: [timing])
                    input.append(additionalSampleBuffer)
                    self.lastSampleBuffer = additionalSampleBuffer
                }
            }
        }

        init(videoInput: AVAssetWriterInput, audioInput: AVAssetWriterInput?, micInput: AVAssetWriterInput?) {
            self.videoInput = InputSession(input: videoInput)
            self.audioInput = audioInput.map { InputSession(input: $0) }
            self.micInput = micInput.map { InputSession(input: $0) }
        }
        
        var lastSampleTime: CMTime {
            let videoTime = videoInput.lastSampleBuffer?.presentationTimeStamp
            let audioTime = audioInput?.lastSampleBuffer?.presentationTimeStamp
            return [videoTime, audioTime].compactMap { $0 }.max() ?? .zero
        }

        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            // Return early if session hasn't started yet
            guard sessionStarted else { return }

            // Return early if the sample buffer is invalid
            guard sampleBuffer.isValid else { return }

            // Retrieve the array of metadata attachments from the sample buffer
            guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let attachments = attachmentsArray.first
            else { return }

            // Validate the status of the frame. If it isn't `.complete`, return
            guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
                  let status = SCFrameStatus(rawValue: statusRawValue),
                  status == .complete
            else { return }


            switch type {
            case .screen:
                videoInput.append(sampleBuffer)

            case .audio:
                audioInput?.append(sampleBuffer)
                
            case .microphone:
                micInput?.append(sampleBuffer)

            @unknown default:
                break
            }
        }
    }
}


// AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
private func downsizedVideoSize(source: CGSize, scaleFactor: Int, mode: RecordMode) -> (width: Int, height: Int) {
    let maxSize = mode.maxSize

    let w = source.width * Double(scaleFactor)
    let h = source.height * Double(scaleFactor)
    let r = max(w / maxSize.width, h / maxSize.height)

    return r > 1
        ? (width: Int(w / r), height: Int(h / r))
        : (width: Int(w), height: Int(h))
}

struct RecordingError: Error, CustomDebugStringConvertible {
    var debugDescription: String
    init(_ debugDescription: String) { self.debugDescription = debugDescription }
}

// Extension properties for values that differ per record mode
extension RecordMode {
    var preset: AVOutputSettingsPreset {
        switch self {
        case .h264_sRGB: return .preset3840x2160
        case .hevc_displayP3: return .hevc7680x4320
//        case .hevc_displayP3_HDR: return .hevc7680x4320
        }
    }

    var maxSize: CGSize {
        switch self {
        case .h264_sRGB: return CGSize(width: 4096, height: 2304)
        case .hevc_displayP3: return CGSize(width: 7680, height: 4320)
//        case .hevc_displayP3_HDR: return CGSize(width: 7680, height: 4320)
        }
    }

    var videoCodecType: CMFormatDescription.MediaSubType {
        switch self {
        case .h264_sRGB: return .h264
        case .hevc_displayP3: return .hevc
//        case .hevc_displayP3_HDR: return .hevc
        }
    }

    var videoColorProperties: NSDictionary {
        switch self {
        case .h264_sRGB:
            return [
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ]
        case .hevc_displayP3:
            return [
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ]
//        case .hevc_displayP3_HDR:
//            return [
//                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
//                AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
//                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
//            ]
        }
    }

    var videoProfileLevel: CFString? {
        switch self {
        case .h264_sRGB:
            return nil
        case .hevc_displayP3:
            return nil
//        case .hevc_displayP3_HDR:
//            return kVTProfileLevel_HEVC_Main10_AutoLevel
        }
    }
}
