//
//  VideoTrimmer.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 9/23/24.
//
//  Adapted from:
//  https://github.com/AndreasVerhoeven/VideoTrimmerControl/blob/main/VideoTrimmer.swift
//  Created by Andreas Verhoeven on 02/09/2020.
//  Copyright © 2020 Andreas Verhoeven. All rights reserved.
//

import SwiftUI
import AVFoundation

// Controls that allows trimming a range and scrubbing a progress indicator
struct VideoTrimmer: View {
    
    // events for changing selectedRange ("trimming")
    enum TrimEvent {
        case didBeginTrimming
        case selectedRangeChanged
        case didEndTrimming
    }
    var onTrim: ((TrimEvent) -> Void)
    //    static let didBeginTrimming = UIControl.Event(rawValue:     0b00000001 << 24)
    //    static let selectedRangeChanged = UIControl.Event(rawValue: 0b00000010 << 24)
    //    static let didEndTrimming = UIControl.Event(rawValue:       0b00000100 << 24)
    
    // events for scrubbing the progress indicator ("scrubbing")
    enum ScrubEvent {
        case didBeginScrubbing
        case progressChanged
        case didEndScrubbing
    }
    var onScrub: ((ScrubEvent) -> Void)
    //    static let didBeginScrubbing = UIControl.Event(rawValue:    0b00001000 << 24)
    //    static let progressChanged = UIControl.Event(rawValue:      0b00010000 << 24)
    //    static let didEndScrubbing = UIControl.Event(rawValue:      0b00100000 << 24)
    
    private struct Thumbnail: Identifiable {
        typealias ID = UUID
        var id: ID {
            uuid
        }
        let uuid = UUID()
        var image: NSImage
        let time: CMTime
    }
    
    var thumbView: VideoTrimmerThumb {
        VideoTrimmerThumb(
            leadingGestureRecognizer: leadingGestureRecognizer,
            trailingGestureRecognizer: trailingGestureRecognizer
        )
    }
    
    //    let thumbView = VideoTrimmerThumb()
    //    private let wrapperView = UIView()
    //    private let shadowView = UIView()
    //    private let thumbnailClipView = UIView()
    //    private let thumbnailWrapperView = UIView()
    //    private let thumbnailTrackView = UIView()
    //    private let thumbnailLeadingCoverView = UIView()
    //    private let thumbnailTrailingCoverView = UIView()
    //    private let leadingThumbRest = UIView()
    //    private let trailingThumbRest = UIView()
    //    private let progressIndicator = UIView()
    //    private let progressIndicatorControl = UIControl()
    
    // defines how much the control is insetted from its sides:
    // this is set to 16, so that you can have the control fullscreen (and have it
    // edge-to-edge when zooming in)
    @State var horizontalInset: CGFloat = 16
    
    // the asset to use
    @State var asset: AVAsset? {
        mutating didSet {
            if let asset = asset {
                let duration = asset.duration
                range = CMTimeRange(start: .zero, duration: duration)
                selectedRange = range
                lastKnownViewSizeForThumbnailGeneration = .zero
            }
        }
    }
    
    // the video composition to use
    @State var videoComposition: AVVideoComposition? {
        mutating didSet {
            lastKnownViewSizeForThumbnailGeneration = .zero
            setNeedsLayout()
        }
    }
    
    // a clip cannot be trimmed shorter than this duration
    @State var minimumDuration: CMTime = .zero
    
    // the available range of the asset.
    // Will be set to the full duration of the asset when assigning a new asset
    @State var range: CMTimeRange = .invalid
    
    // the range that is selected, will be set to the full duration
    // when changing asset.
    @State var selectedRange: CMTimeRange = .invalid
    
    // defines what to do with the progress indicator
    enum ProgressIndicatorMode {
        case hiddenOnlyWhenTrimming // the progress indicator gets hidden when the user starts trimming
        case alwaysShown // the progress indicator is always shown, even when the user is trimming
        case alwaysHidden // the progress indicator is never shown
    }
    @State var progressIndicatorMode = ProgressIndicatorMode.hiddenOnlyWhenTrimming // {
    
    mutating func setProgressIndicatorMode(_ mode: ProgressIndicatorMode, animated: Bool) {
        guard progressIndicatorMode != mode else {return}
        
        if animated == true {
            withAnimation {
                progressIndicatorMode = mode
            }
        } else {
            progressIndicatorMode = mode
        }
    }
    
    // defines where the progress indicator is shown.
    @State var progress: CMTime = .zero
    
    mutating func setProgress(_ progress: CMTime, animated: Bool) {
        guard CMTimeCompare(self.progress, progress) != 0 else {return}
        
        if animated {
            withAnimation(.linear(duration: 0.25)) {
                self.progress = progress
            }
        } else {
            self.progress = progress
        }
    }
    
    
    // defines if the user is trimming or not, and if so, which edge
    enum TrimmingState {
        case none        // user isn't trimming
        case leading    // user is trimming the leading part of the asset
        case trailing    // user is trimming the trailing part of the asset
    }
    
    @State private(set) var trimmingState = TrimmingState.none /*{
                                                                didSet {
                                                                UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                                                                self.shadowView.layer.shadowOpacity = (self.trimmingState != .none ? 0.5 : 0.25)
                                                                self.shadowView.layer.shadowRadius = (self.trimmingState != .none ? 4 : 2)
                                                                })
                                                                }
                                                                }*/
    
    // yes if the user is zoomed in
    @State private(set) var isZoomedIn = false
    @State private(set) var zoomedInRange: CMTimeRange = .zero
    
    
    // yes if the user is scrubbing the progress indicator
    @State private(set) var isScrubbing = false
    
    // background color for the track
    @State var trackBackgroundColor = Color.black
    //        didSet {
    //            thumbnailWrapperView.backgroundColor = trackBackgroundColor
    //        }
    //    }
    
    // background color for the place where the thumbs rest on when the selectedRange == range
    @State var thumbRestColor = Color.black/* {
                                            didSet {
                                            leadingThumbRest.backgroundColor = thumbRestColor
                                            trailingThumbRest.backgroundColor = thumbRestColor
                                            }
                                            }*/
    
    // the range that's currently visible: could be less than "range" when zoomed in
    var visibleRange: CMTimeRange {
        return isZoomedIn == true ? zoomedInRange : range
    }
    
    // the time that's currently selected by the user when trimming
    var selectedTime: CMTime {
        switch trimmingState {
        case .none: return .zero
        case .leading: return selectedRange.start
        case .trailing: return selectedRange.end
        }
    }
    
    // gesture recognizers used. Can be used, for instance, to
    // require a tableview panGestureRecognizer to fail
    //    private (set) var leadingGestureRecognizer: UILongPressGestureRecognizer!
    //    private (set) var trailingGestureRecognizer: UILongPressGestureRecognizer!
    //    private (set) var progressGestureRecognizer: UILongPressGestureRecognizer!
    //    private (set) var thumbnailInteractionGestureRecognizer: UILongPressGestureRecognizer!
    
    // private stuff
    @State private var grabberOffset = CGFloat(0)
    @State private var zoomWaitTimer: Timer?
    
    @State private var lastKnownViewSizeForThumbnailGeneration: CGSize = .zero
    @State private var thumbnailSize: CGSize = .zero
    @State private var lastKnownThumbnailRange: CMTimeRange = .zero
    @State private var thumbnails = Array<Thumbnail>()
    @State private var generator: AVAssetImageGenerator?
    @State private var didClampWhilePanning = false
    
    @State private var impactFeedbackGenerator: DummyImpactFeedbackGenerator?
    
    private var thumbnailClipView: some View {
        thumbnailWrapperView
    }
    
    private var leadingThumbRest: some View {
        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 6, bottomLeading: 6), style: .continuous)
            .background(thumbRestColor)
    }
    
    private var trailingThumbRest: some View {
        UnevenRoundedRectangle(cornerRadii: .init(bottomTrailing: 6, topTrailing: 6), style: .continuous)
            .background(thumbRestColor)
    }
    
    private var thumbnailLeadingCoverView: some View {
        Rectangle().backgroundStyle(.black.opacity(0.75))
    }
    
    private var thumbnailTrailingCoverView: some View {
        Rectangle().backgroundStyle(.black.opacity(0.75))
    }
    
    //    private let wrapperView = UIView()
    //    private let shadowView = UIView()
    //    private let thumbnailClipView = UIView()
    //    private let thumbnailWrapperView = UIView()
    //    private let thumbnailTrackView = UIView()
    //    private let thumbnailLeadingCoverView = UIView()
    //    private let thumbnailTrailingCoverView = UIView()
    //    private let leadingThumbRest = UIView()
    //    private let trailingThumbRest = UIView()
    //    private let progressIndicator = UIView()
    //    private let progressIndicatorControl = UIControl()
    
    @ViewBuilder
    private var thumbnailWrapperView: some View {
        let pos = layoutSubviews()
        
        HStack(spacing: 0) {
            leadingThumbRest.abs(pos.leadingThumbRestFrame)
            thumbnailLeadingCoverView.abs(pos.thumbnailLeadingCoverViewFrame)
            thumbnailTrackView.abs(pos.thumbnailTrackViewFrame)
            thumbnailTrailingCoverView.abs(pos.thumbnailTrailingCoverViewFrame)
            trailingThumbRest.abs(pos.trailingThumbRestFrame)
        }
        .background(trackBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private var thumbnailTrackView: some View {
        List(thumbnails) { item in
            Image(nsImage: item.image)
        }.contentTransition(.opacity)
    }
    
    //    private func updateProgressIndicator() {
    //        switch progressIndicatorMode {
    //        case .alwaysHidden:
    //            progressIndicator.alpha = 0
    //            progressIndicatorControl.isUserInteractionEnabled = false
    //
    //        case .alwaysShown:
    //            progressIndicator.alpha = 1
    //            progressIndicatorControl.isUserInteractionEnabled = true
    //            setNeedsLayout()
    //
    //        case .hiddenOnlyWhenTrimming:
    //            progressIndicator.alpha = (trimmingState == .none ? 1 : 0)
    //            progressIndicatorControl.isUserInteractionEnabled = (trimmingState == .none)
    //            if trimmingState == .none {
    //                setNeedsLayout()
    //                if UIView.inheritedAnimationDuration > 0 {
    //                    UIView.performWithoutAnimation {
    //                        layoutIfNeeded()
    //                    }
    //                }
    //            }
    //        }
    //        progressIndicatorControl.alpha = progressIndicator.alpha
    //    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        let opacity: Double = switch progressIndicatorMode {
        case .hiddenOnlyWhenTrimming: trimmingState == .none ? 1 : 0
        case .alwaysShown: 1
        case .alwaysHidden: 0
        }
        
        let enabled = switch progressIndicatorMode {
            // TODO: Is this backwards?
        case .hiddenOnlyWhenTrimming: trimmingState == .none
        case .alwaysShown: true
        case .alwaysHidden: true
        }
        
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .background(.white)
            .shadow(color: .black.opacity(0.25), radius: 2)
            .opacity(opacity)
            .gesture(progressGestureRecognizer)
            .disabled(!enabled)
    }
    
    var body: some View {
        let pos = layoutSubviews()
        ZStack {
            thumbnailClipView.abs(pos.thumbnailClipViewFrame)
            thumbnailWrapperView.abs(pos.thumbnailWrapperViewFrame)
            progressIndicator.abs(pos.progressIndicatorFrame)
        }
        .shadow(color: .black.opacity(0.25), radius: 2)
        .onAppear {
            Task { @MainActor in
                regenerateThumbnailsIfNeeded()
            }
        }
    }
    
    //    leadingGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(leadingGrabberPanned(_:)))
    //    leadingGestureRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
    //    leadingGestureRecognizer.minimumPressDuration = 0
    //    thumbView.leadingGrabber.addGestureRecognizer(leadingGestureRecognizer)
    var leadingGestureRecognizer = LongPressGesture(minimumDuration: 0, maximumDistance: .init())
    var trailingGestureRecognizer = LongPressGesture(minimumDuration: 0, maximumDistance: .init())
    
    //    progressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(progressGrabberPanned(_:)))
    //    progressGestureRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
    //    progressGestureRecognizer.minimumPressDuration = 0
    //    progressGestureRecognizer.require(toFail: leadingGestureRecognizer)
    //    progressGestureRecognizer.require(toFail: trailingGestureRecognizer)
    //    progressIndicatorControl.addGestureRecognizer(progressGestureRecognizer)
    var progressGestureRecognizer: some Gesture {
        // TODO: call progressGrabberPanned
        LongPressGesture()
    }
    
    
    //    thumbnailInteractionGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(thumbnailPanned(_:)))
    //    thumbnailInteractionGestureRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
    //    thumbnailInteractionGestureRecognizer.minimumPressDuration = 0
    //    thumbnailInteractionGestureRecognizer.require(toFail: leadingGestureRecognizer)
    //    thumbnailInteractionGestureRecognizer.require(toFail: trailingGestureRecognizer)
    //    thumbView.addGestureRecognizer(thumbnailInteractionGestureRecognizer)
    // TODO: call thumbnailPanned
    var thumbnailInteractionGestureRecognizer: some Gesture {
        LongPressGesture()
    }
    
    
    // MARK: - Private
    @Environment(\.displayScale) private var displayScale
    
    // TODO: how to get this?
    var bounds: CGRect
    
    private func setNeedsLayout() {
        // TODO: debounce? Real side-effect? useEffect?
//        regenerateThumbnailsIfNeeded()
    }
    
    private func regenerateThumbnailsIfNeeded() {
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else {return}
        guard lastKnownViewSizeForThumbnailGeneration != size || CMTimeRangeEqual(lastKnownThumbnailRange, visibleRange) == false else {return}
        guard let asset = asset else {return}
        guard let track = asset.tracks(withMediaType: .video).first else {return}
        
        lastKnownViewSizeForThumbnailGeneration = size
        lastKnownThumbnailRange = visibleRange
        
        let naturalSize = track.naturalSize
        let transform = track.preferredTransform
        let fixedSize = naturalSize.applyingVideoTransform(transform)
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.apertureMode = .cleanAperture
        generator.videoComposition = videoComposition
        self.generator = generator
        
        let height = size.height - /* thumbView.edgeHeight */ 2 * 2
        thumbnailSize = CGSize(width: height / fixedSize.height * fixedSize.width, height: height)
        let numberOfThumbnails = Int(ceil(size.width / thumbnailSize.width))
        
        var newThumbnails = Array<Thumbnail>()
        let thumbnailDuration = visibleRange.duration.seconds / Double(numberOfThumbnails)
        var times = Array<NSValue>()
        // we add some extra thumbnails as padding
        for index in -3..<numberOfThumbnails + 6 {
            let time = CMTimeAdd(visibleRange.start, CMTime(seconds: thumbnailDuration * Double(index), preferredTimescale: asset.duration.timescale * 2))
            guard CMTimeCompare(time, .zero) != -1 else {continue}
            times.append(NSValue(time: time))
            
            //            let newThumbnail = Thumbnail(imageView: UIImageView(), time: time)
            //            self.thumbnailTrackView.addSubview(newThumbnail.imageView)
            let newThumbnail = Thumbnail(image: NSImage.init(size: .zero), time: time)
            newThumbnails.append(newThumbnail)
        }
        
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: thumbnailSize.width * displayScale, height: thumbnailSize.height * displayScale)
        
        let oldThumbnails = thumbnails
        thumbnails.append(contentsOf: newThumbnails)
        
        //        UIView.animate(withDuration: 0.25, delay: 0.25, options: [.beginFromCurrentState], animations: {
        //            oldThumbnails.forEach {$0.imageView.alpha = 0}
        //        }, completion: { _ in
        //            oldThumbnails.forEach {$0.imageView.removeFromSuperview()}
        withAnimation {
            let uuidsToRemove = Set(oldThumbnails.map({$0.uuid}))
            self.thumbnails.removeAll(where: {uuidsToRemove.contains($0.uuid)})
        }
        //        })
        
        var seenIndex = 0
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in
            DispatchQueue.main.async {
                seenIndex += 1
                
                guard let cgImage = cgImage else {return}
                let image = NSImage(cgImage: cgImage, size: cgImage.size)
                //                let imageView = newThumbnails[seenIndex - 1].imageView
                //                UIView.transition(with: imageView, duration: 0.25, options: [.transitionCrossDissolve], animations: {
                //                    imageView.image = image
                //                })
                let uuid = newThumbnails[seenIndex - 1].uuid
                if let index = self.thumbnails.firstIndex(where: { $0.uuid == uuid }) {
                    withAnimation {
                        self.thumbnails[index].image = image
                    }
                }
            }
        }
    }
    
    private func timeForLocation(_ x: CGFloat) -> CMTime {
        let size = bounds.size
        let inset = thumbView.chevronWidth + horizontalInset
        let offset = x - inset
        
        let availableWidth = size.width - inset * 2
        let visibleDurationInSeconds = CGFloat(visibleRange.duration.seconds)
        let ratio = visibleDurationInSeconds != 0 ? availableWidth / visibleDurationInSeconds : 0
        
        let timeDifference = CMTime(seconds: Double(offset / ratio), preferredTimescale: 600)
        return CMTimeAdd(visibleRange.start, timeDifference)
    }
    
    private func locationForTime(_ time: CMTime) -> CGFloat {
        let size = bounds.size
        let inset = thumbView.chevronWidth + horizontalInset
        let availableWidth = size.width - inset * 2
        
        let offset = CMTimeSubtract(time, visibleRange.start)
        
        let visibleDurationInSeconds = CGFloat(visibleRange.duration.seconds)
        let ratio = visibleDurationInSeconds != 0 ? availableWidth / visibleDurationInSeconds : 0
        
        let location = CGFloat(offset.seconds) * ratio
        return SnapToDevicePixels(location) + inset
    }
    
    private func startZoomWaitTimer() {
        stopZoomWaitTimer()
        guard isZoomedIn == false else {return}
        zoomWaitTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [self] _ in
            self.stopZoomWaitTimer()
            self.zoomIfNeeded()
        })
    }
    
    private func stopZoomWaitTimer() {
        zoomWaitTimer?.invalidate()
        zoomWaitTimer = nil
    }
    
    private func stopZoomIfNeeded() {
        stopZoomWaitTimer()
        isZoomedIn = false
        //        animateChanges()
    }
    
    private func zoomIfNeeded() {
        guard isZoomedIn == false else {return}
        
        let size = bounds.size
        let inset = thumbView.chevronWidth + horizontalInset
        let availableWidth = size.width - inset * 2
        let newDuration = CGFloat(range.duration.seconds > 4 ?  2.0 : range.duration.seconds * 0.5)
        
        let durationTime = CMTime(seconds: Double(newDuration), preferredTimescale: 600)
        
        if trimmingState == .leading {
            let position = locationForTime(selectedRange.start) - inset
            let start = position / availableWidth * newDuration
            zoomedInRange = CMTimeRange(start: CMTimeSubtract(selectedRange.start, CMTime(seconds: Double(start), preferredTimescale: 600)), duration: durationTime)
        } else {
            let position = locationForTime(selectedRange.end) - inset
            
            let durationToStart = position / availableWidth * newDuration
            let newStart = CMTimeSubtract(selectedRange.end, CMTime(seconds: Double(durationToStart), preferredTimescale: 600))
            zoomedInRange = CMTimeRange(start: newStart, duration: durationTime)
        }
        
        isZoomedIn = true
        //        animateChanges()
        
        //        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    //    private func animateChanges() {
    //        setNeedsLayout()
    //        thumbView.setNeedsLayout()
    //        UIView.animate(withDuration: 0.5, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
    //            self.layoutIfNeeded()
    //            self.thumbView.layoutIfNeeded()
    //        })
    //    }
    
    private func startPanning() {
        onTrim(.didBeginTrimming)
        //        sendActions(for: Self.didBeginTrimming)
        //        UISelectionFeedbackGenerator().selectionChanged()
        
        withAnimation {
            didClampWhilePanning = false
        }
        
        //        impactFeedbackGenerator = DummyImpactFeedbackGenerator(style: .heavy)
        //        impactFeedbackGenerator?.prepare()
        //
        //        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
        //            self.updateProgressIndicator()
        //        }
        //        })
    }
    
    private func stopPanning() {
        withAnimation {
            trimmingState = .none
            stopZoomIfNeeded()
        }
        impactFeedbackGenerator = nil
        //        sendActions(for: Self.didEndTrimming)
        onTrim(.didEndTrimming)
        //
        //        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
        //            self.updateProgressIndicator()
        //        })
    }
    
    
    
    // MARK: - Input
    /*
    private func thumbnailPanned(_ sender: UILongPressGestureRecognizer) {
        progressGrabberPanned(sender)
    }
    
    
    private func progressGrabberPanned(_ sender: UILongPressGestureRecognizer) {
        
        func handleChanged() {
            let location = sender.location(in: self)
            var time = timeForLocation(location.x + grabberOffset)
            
            var didClamp = false
            if CMTimeCompare(time, selectedRange.start) == -1 {
                time = selectedRange.start
                didClamp = true
            }
            if CMTimeCompare(time, selectedRange.end) == 1 {
                time = selectedRange.end
                didClamp = true
            }
            
            if didClamp == true && didClamp != didClampWhilePanning {
                impactFeedbackGenerator?.impactOccurred()
            }
            didClampWhilePanning = didClamp
            
            progress = time
            setNeedsLayout()
            //            sendActions(for: Self.progressChanged)
            
        }
        switch sender.state {
        case .began:
            
            DummySelectionFeedbackGenerator().selectionChanged()
            impactFeedbackGenerator = DummyImpactFeedbackGenerator(style: .heavy)
            impactFeedbackGenerator?.prepare()
            didClampWhilePanning = false
            
            isScrubbing = true
            onScrub(.didBeginScrubbing)
            //            sendActions(for: Self.didBeginScrubbing)
            handleChanged()
            
        case .changed:
            handleChanged()
            
        case .ended, .cancelled:
            impactFeedbackGenerator = nil
            
            isScrubbing = false
            //            sendActions(for: Self.didEndScrubbing)
            onScrub(.didEndScrubbing)
            
        case .possible, .failed:
            break
            
        @unknown default:
            break
        }
    }
    
    
    private func leadingGrabberPanned(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            trimmingState = .leading
            grabberOffset = 0 // thumbView.chevronWidth - sender.location(in: thumbView.leadingGrabber).x
            
            startPanning()
            
        case .changed:
            let location = sender.location(in: self)
            var time = timeForLocation(location.x + grabberOffset)
            let newDuration = CMTimeSubtract(selectedRange.end, time)
            
            var didClamp = false
            if CMTimeCompare(newDuration, minimumDuration) == -1 {
                time = CMTimeSubtract(selectedRange.end, minimumDuration)
                didClamp = true
            }
            if CMTimeCompare(time, range.start) == -1 {
                time = range.start
                didClamp = true
            }
            if CMTimeCompare(time, range.end) == 1 {
                time = range.end
                didClamp = true
            }
            
            
            if didClamp == true && didClamp != didClampWhilePanning {
                impactFeedbackGenerator?.impactOccurred()
            } else {
                //                    if didClamp == false && CMTimeCompare(progress, time) == 0 && CMTimeCompare(progress, range.start) != 0 && CMTimeCompare(progress, range.end) != 0 {
                //                        impactFeedbackGenerator?.impactOccurred(intensity: 0.5)
                //                        didClamp = true
                //                    }
            }
            didClampWhilePanning = didClamp
            
            selectedRange = CMTimeRange(start: time, end: selectedRange.end)
            onTrim(.selectedRangeChanged)
            //            sendActions(for: Self.selectedRangeChanged)
            setNeedsLayout()
            
            startZoomWaitTimer()
            
        case .ended:
            stopPanning()
            
        case .cancelled:
            stopPanning()
            
        case .possible, .failed:
            break
            
        @unknown default:
            break
        }
    }
    
    private func trailingGrabberPanned(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            trimmingState = .trailing
            grabberOffset = 0 // sender.location(in: thumbView.trailingGrabber).x
            
            startPanning()
            
        case .changed:
            let location = sender.location(in: self)
            var time = timeForLocation(location.x - grabberOffset)
            
            let newDuration = CMTimeSubtract(time, selectedRange.start)
            
            var didClamp = false
            if CMTimeCompare(newDuration, minimumDuration) == -1 {
                time = CMTimeAdd(selectedRange.start, minimumDuration)
                didClamp = true
            }
            if CMTimeCompare(time, range.start) == -1 {
                time = range.start
                didClamp = true
            }
            if CMTimeCompare(time, range.end) == 1 {
                time = range.end
                didClamp = true
            }
            
            if didClamp == true && didClamp != didClampWhilePanning {
                impactFeedbackGenerator?.impactOccurred()
            } else {
                //                    if didClamp == false && CMTimeCompare(progress, time) == 0 && CMTimeCompare(progress, range.start) != 0 && CMTimeCompare(progress, range.end) != 0 {
                //                        impactFeedbackGenerator?.impactOccurred(intensity: 0.5)
                //                        didClamp = true
                //                    }
            }
            didClampWhilePanning = didClamp
            
            selectedRange = CMTimeRange(start: selectedRange.start, end: time)
            onTrim(.selectedRangeChanged)
            //            sendActions(for: Self.selectedRangeChanged)
            setNeedsLayout()
            
            startZoomWaitTimer()
            
        case .ended:
            stopPanning()
            
        case .cancelled:
            stopPanning()
            
        case .possible, .failed:
            break
            
        @unknown default:
            break
        }
    }
     */
    
    // MARK: - UIView
    
    //    override var intrinsicContentSize: CGSize {
    //        return CGSize(width: UIView.noIntrinsicMetric, height: 50)
    //    }
    struct LayoutProps {
        var shadowViewFrame: CGRect = .zero
        var wrapperViewFrame: CGRect = .zero
        var thumbViewFrame: CGRect = .zero
        
        var thumbnailClipViewFrame: CGRect = .zero
        var thumbnailWrapperViewFrame: CGRect = .zero
        var thumbnailTrackViewFrame: CGRect = .zero
        
        var thumbnailLeadingCoverViewFrame: CGRect = .zero
        var thumbnailTrailingCoverViewFrame: CGRect = .zero
        var leadingThumbRestFrame: CGRect = .zero
        var trailingThumbRestFrame: CGRect = .zero
        var progressIndicatorFrame: CGRect = .zero
        var progressIndicatorControlFrame: CGRect = .zero
        //        var thumbnailLeadingCoverViewFrame: CGRect = .zero
        //        var thumbnailLeadingCoverViewFrame: CGRect = .zero
        //        var thumbnailLeadingCoverViewFrame: CGRect = .zero
        //        var thumbnailLeadingCoverViewFrame: CGRect = .zero
        //        var thumbnailLeadingCoverViewFrame: CGRect = .zero
        //        var thumbnailLeadingCoverViewFrame: CGRect = .zero
        
    }
    
    func layoutSubviews() -> LayoutProps {
        //        super.layoutSubviews()
        
        let size = bounds.size
        let inset = thumbView.chevronWidth
        var left = locationForTime(selectedRange.start) - inset
        var right = locationForTime(selectedRange.end) + inset
        
        if right > bounds.width {
            right = bounds.width + inset * 2
        }
        
        if left < 0 {
            left = -inset
        }
        
        var result = LayoutProps()
        
        let rect = CGRect(origin: .zero, size: size)
        result.shadowViewFrame = rect
        result.wrapperViewFrame = rect
        result.thumbViewFrame = CGRect(x: left, y: 0, width: max(right - left, inset * 2), height: size.height)
        
        let isZoomedToEnd = (trimmingState == .leading && isZoomedIn == true)
        
        let thumbnailOffset = (isZoomedIn == true ? horizontalInset + inset + 6 : 0)
        let coverOffset = thumbnailOffset - horizontalInset
        let coverStartOffset = (isZoomedIn == false ? inset : 0)
        
        let thumbnailRect = rect.insetBy(dx: horizontalInset - thumbnailOffset, dy: thumbView.edgeHeight)
        result.thumbnailClipViewFrame = rect
        result.thumbnailWrapperViewFrame = thumbnailRect
        result.thumbnailTrackViewFrame = CGRect(origin: .zero, size: CGSize(width: thumbnailRect.width - (isZoomedToEnd == false ? inset : 0), height: thumbnailRect.height))
        result.thumbnailLeadingCoverViewFrame = CGRect(x: coverStartOffset, y: 0, width: left + inset * 0.5 + coverOffset - coverStartOffset, height: thumbnailRect.height)
        result.thumbnailTrailingCoverViewFrame = CGRect(x: right - inset * 0.5 + coverOffset, y: 0, width: thumbnailRect.width - coverStartOffset - (right - inset * 0.5 + coverOffset), height: thumbnailRect.height)
        
        result.leadingThumbRestFrame = CGRect(x: 0, y: 0, width: inset, height: thumbnailRect.height)
        result.trailingThumbRestFrame = CGRect(x: thumbnailRect.width - inset, y: 0, width: inset, height: thumbnailRect.height)
        
        let thumbViewFrame = result.thumbViewFrame
        //        if progressIndicator.alpha > 0 {
        let progressWidth = CGFloat(4)
        let progressIndicatorOffset = locationForTime(progress)
        let progressLeft = min(max(thumbViewFrame.minX + inset, progressIndicatorOffset - progressWidth * 0.5), thumbViewFrame.maxX - inset - progressWidth)
        result.progressIndicatorFrame = CGRect(x: progressLeft, y: thumbnailRect.minY, width: progressWidth, height: thumbnailRect.height)
        
        let progressControlWidth = CGFloat(24)
        
        var progressControlLeft = max(thumbViewFrame.minX + inset, progressLeft)
        var progressControlRight = progressLeft + progressControlWidth
        if progressControlRight > thumbViewFrame.maxX - inset {
            progressControlRight = thumbViewFrame.maxX - inset
            progressControlLeft = max(thumbViewFrame.minX + inset, progressControlRight - progressControlWidth)
        }
        result.progressIndicatorControlFrame = CGRect(x: progressControlLeft, y: thumbnailRect.minY, width: progressControlRight - progressControlLeft, height: thumbnailRect.height)
        //        }
        
        // TODO:
//        regenerateThumbnailsIfNeeded()
            
            //        for thumbnail in thumbnails {
            //            let position = locationForTime(thumbnail.time) - horizontalInset + thumbnailOffset
            //            let frame = CGRect(x: position, y: 0, width: thumbnailSize.width, height: thumbnailSize.height)
            //            if thumbnail.imageView.bounds.width == 0 {
            //                UIView.performWithoutAnimation {
            //                    thumbnail.imageView.frame = frame
            //                }
            //            } else {
            //                thumbnail.imageView.frame = frame
            //            }
            //        }
        return result
    }
    //
    //    override init(frame: CGRect) {
    //        super.init(frame: frame)
    //        setup()
    //    }
    //
    //    required init?(coder: NSCoder) {
    //        super.init(coder: coder)
    //        setup()
    //    }

}

// MARK: -

fileprivate func SnapToDevicePixels(_ value: CGFloat, scale: CGFloat? = nil) -> CGFloat {
    let actualScale = scale ?? NSScreen.main?.backingScaleFactor ?? 2
    return round(value * actualScale) / actualScale
}

fileprivate func SnapToDevicePixels(_ rect: CGRect, scale: CGFloat? = nil) -> CGRect {
    return CGRect(x: SnapToDevicePixels(rect.origin.x, scale: scale),
                  y: SnapToDevicePixels(rect.origin.y, scale: scale),
                  width: SnapToDevicePixels(rect.maxX - rect.minX, scale: scale),
                  height: SnapToDevicePixels(rect.maxY - rect.minY, scale: scale))
}

fileprivate extension CGRect {
    func snappedToDevicePixels(scale: CGFloat? = nil) -> CGRect {
        return SnapToDevicePixels(self, scale: scale)
    }
}

fileprivate extension View {
    func abs(_ rect: CGRect) -> some View {
        self
            .position(rect.origin)
            .frame(width: rect.width, height: rect.height)
    }
}

fileprivate extension CGSize {
    func ceiled() -> CGSize {
        return CGSize(width: ceil(width), height: ceil((height)))
    }
    
    func snappedToDevicePixels(scale: CGFloat? = nil) -> CGSize {
        return CGSize(width: SnapToDevicePixels(width, scale: scale), height: SnapToDevicePixels(height, scale: scale))
    }
    
    func applyingVideoTransform(_ transform: CGAffineTransform) -> CGSize {
        return CGRect(origin: .zero, size: self).applying(transform).size
    }
}

struct DummyImpactFeedbackGenerator {
    enum Style {
        case heavy
    }
    
    let style: Style
    func prepare() {}
    func impactOccurred() {}
}

struct DummySelectionFeedbackGenerator {
    func selectionChanged() {}
}


#Preview {
    let asset = NSDataAsset(name: "previewVideo.mp4")!
    let avAsset = AVURLAsset(asset)
//    asset.typeIdentifier = "public.mpeg-4"
    
    GeometryReader { proxy in
        VideoTrimmer(
            onTrim: { print("onTrim", $0) },
            onScrub: { print("onScrub", $0) },
            asset: avAsset,
            bounds: CGRect(x: 0, y: 0, width: proxy.size.width, height: proxy.size.height)
       )
            
    }
    
}


extension NSDataAsset: AVAssetResourceLoaderDelegate{
    @objc public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        if let infoRequest = loadingRequest.contentInformationRequest{
            infoRequest.contentType = typeIdentifier
            infoRequest.contentLength = Int64(data.count)
            infoRequest.isByteRangeAccessSupported = true
        }
        
        if let dataRequest = loadingRequest.dataRequest{
            dataRequest.respond(with: data.subdata(in:Int(dataRequest.requestedOffset) ..< Int(dataRequest.requestedOffset) + dataRequest.requestedLength))
            loadingRequest.finishLoading()
            
            return true
        }
        return false
    }
}
extension AVURLAsset{
    public convenience init?(_ dataAsset:NSDataAsset){
        guard let name = dataAsset.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string:"NSDataAsset://\(name))")
        else {return nil}
        
        self.init(url:url) // not really used!
        self.resourceLoader.setDelegate(dataAsset, queue: .main)
        // Retain the weak delegate for the lifetime of AVURLAsset
        objc_setAssociatedObject(self, "AVURLAsset+NSDataAsset", dataAsset, .OBJC_ASSOCIATION_RETAIN)
    }
}
