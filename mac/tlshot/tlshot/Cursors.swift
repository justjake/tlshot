//
//  Cursors.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/14/24.
//

import SwiftUI
import Vision

struct ImageProps: Equatable {
    static let defaults = ImageProps(
        width: 40,
        scale: 2,
        proposedSize: .init(width: 40, height: 40)
    )
    
    var width: Double = 40
    var scale: Double = 2
    var proposedSize: ProposedViewSize = .unspecified
    
    var proposedSizeWithDefault: ProposedViewSize {
        proposedSize //  ?? .init(.init(square: width))
    }
}

protocol ViewRenderHolderP {
    associatedtype Props
    @MainActor func render(
        props: Props?,
        imageProps: ImageProps?
    ) -> CGImage?
    
    func view(size: CGSize) -> Image
}

extension ViewRenderHolderP {
    @MainActor func render(
        props: Props?
    ) -> CGImage? {
        render(props: props, imageProps: nil)
    }
    
    @MainActor func render(
        imageProps: ImageProps?
    ) -> CGImage? {
        render(props: nil, imageProps: imageProps)
    }
    
    @MainActor func render() -> CGImage? {
        render(props: nil, imageProps: nil)
    }
}

struct Empty: Equatable {}

class ViewRenderHolder<Content: View>: ViewRenderHolderWithProps<Empty, Content> {
    
    init(imageProps: ImageProps = ImageProps.defaults, @ViewBuilder render: @escaping  () -> Content) {
        super.init(props: Empty(), imageProps: imageProps, render: { _ in render() })
    }
}

    

class ViewRenderHolderWithProps<
    Props: Equatable,
    Content: View
>: ObservableObject, ViewRenderHolderP {
    @Published public var props: Props
    private let render: (Props) -> Content
    @Published private var lastRenderResult: Content?
    
    @Published private var imageProps: ImageProps
    @Published private var lastImageResult: CGImage?
    private var renderer: ImageRenderer<Content>?
    
    init(
        props: Props,
        imageProps: ImageProps = ImageProps.defaults,
        @ViewBuilder render: @escaping (Props) -> Content
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
        renderer.proposedSize = imageProps.proposedSizeWithDefault
        renderer.isOpaque = false
        return renderer.cgImage
    }
    
    @MainActor public func view(size: CGSize) -> Image {
        let cgImage = render()
        let nsImage = NSImage(cgImage: cgImage!, size: size)
        return Image(nsImage: nsImage)
    }
}

extension CGImage {
    func nsImage(size: CGSize? = nil) -> NSImage? {
        let finalSize = size ?? .init(width: width, height: height)
        return NSImage(cgImage: self, size: finalSize)
    }
}

extension NSImage {
    func cgImage(size: CGSize? = nil) -> CGImage? {
        var rect = CGRect(origin: .zero, size: size ?? self.size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
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

final class CameraViewBuilder {
    static var cameraPathBuilder = ContourPathExtractor(
        image: Image(systemName: "camera.fill"),
        extractedPathWidth: 20
    )
    
    init (_ cameraPath: CGPath) {
        self.cameraPath = cameraPath
    }
    
    var cameraPath: CGPath
    lazy var cameraView = CameraWithStroke(cgPath: cameraPath, width: 20)
    
    func cameraWithBadge(_ badgeName: String) -> some View {
        ZStack {
            cameraView
            CursorSymbolBadge(systemName: badgeName)
                .offset(x: 12, y: 6)
        }
        .compositingGroup()
        .mouseShadow()
    }
    
    lazy var cameraRenderer: some ViewRenderHolderP = ViewRenderHolder(imageProps: .init(width: 40)) {
        self.cameraView
            .mouseShadow()
            .padding(3)
            .drawingGroup()
    }
    
    let badgePadding = 10.0
    lazy var cameraPlusRenderer: some ViewRenderHolderP = ViewRenderHolder(imageProps: .init(width: 40)) { [self] in
        cameraWithBadge("plus.circle.fill")
            .padding(.init(top: 3, leading: 3, bottom: badgePadding, trailing: badgePadding))
    }
    
    lazy var cameraMinusRenderer: some ViewRenderHolderP = ViewRenderHolder(imageProps: .init(width: 40)) { [self] in
        cameraWithBadge("minus.circle.fill")
            .padding(.init(top: 3, leading: 3, bottom: badgePadding, trailing: badgePadding))
    }
}

struct Cursors: View {
    static var cameraPath = ContourPathExtractor(
        image: Image(systemName: "camera.fill"),
        extractedPathWidth: 20
    )
    
    @MainActor
    static var cameraViewBuilder = CameraViewBuilder(try! cameraPath.buildSync()!)
    
    @MainActor
    var cameraViews = Self.cameraViewBuilder
    
    @MainActor static var cameraView = cameraViewBuilder.cameraView
    
    @ViewBuilder
    @MainActor
    static func cameraWithBadge(_ badgeName: String) -> some View {
        ZStack {
            cameraView
            CursorSymbolBadge(systemName: badgeName)
                .offset(x: 12, y: 6)
        }
        .compositingGroup()
        .mouseShadow()

    }
    
    
    @ViewBuilder
    var tldrawExtraIcons: some View {
        VStack(spacing: tldrawToolSpacing) {
            HStack(spacing: tldrawToolSpacing) {
                systemImage("rectangle")
                systemImage("circle")
                systemImage("triangle")
                systemImage("rhombus") // todo - looks like daimond, but is rhombus
            }
            
            HStack(spacing: tldrawToolSpacing) {
                systemImage("hexagon")
                systemImage("oval.portrait")
                systemImage("rhombus") // todo - looks like daimond, but is rhombus
                systemImage("star")
            }
            
            HStack(spacing: tldrawToolSpacing) {
                systemImage("cloud")
                systemImage("heart")
                systemImage("x.square")
                systemImage("checkmark.square")
            }
            
            HStack(spacing: tldrawToolSpacing) {
                systemImage("arrowshape.left")
                systemImage("arrowshape.up")
                systemImage("arrowshape.down")
                systemImage("arrowshape.right")
            }
            
            HStack(spacing: tldrawToolSpacing) {
                systemImage("line.diagonal")
                systemImage("highlighter")
                systemImage("flashlight.on.fill") // lazer pointer
                systemImage("viewfinder")
            }
        }
    }
    
    let tldrawToolSpacing: CGFloat = 2
    @ViewBuilder
    var tldrawIcons: some View {
        VStack {
            Image("SwiftUIPreviewTldrawTools")
            HStack(alignment: .top, spacing: tldrawToolSpacing) {
                systemImage("cursorarrow")
                systemImage("hand.raised.fingers.spread")
                VStack(spacing: tldrawToolSpacing) {
                    systemImage("pencil")
                    systemImage("scribble")
                    systemImage("scribble.variable")
                }
                systemImage("eraser")
                VStack(spacing: tldrawToolSpacing) {
                    systemImage("arrow.up.forward", size: 14)
    //                systemImage("line.diagonal.arrow")
                }
                VStack(spacing: tldrawToolSpacing) {
                    systemImage("character.cursor.ibeam")
    //                systemImage("character.textbox")
    //                systemImage("character")
                }
                
                VStack(spacing: tldrawToolSpacing) {
                    systemImage("note.text")
                    systemImage("note")
                    systemImage("newspaper")
                }
                systemImage("photo")
                
                // This should be native, as there's many more tools
                // Or we need to replace all.
                systemImage("square")
                
                
                systemImage("macwindow.badge.plus", size: 28, offset: -2)
                systemImage("rectangle.badge.plus", size: 28, offset: -2)
                
                Rectangle().foregroundStyle(.clear).frame(width: 25)
            }
            
            HStack {
                Spacer()
                tldrawExtraIcons
            }
            
        }
    }
    
    func systemImage(_ name: String, size: CGFloat = 18, offset: CGFloat = 0, bg: Bool = true) -> some View {
        let defaultPadding: CGFloat = 12
        let scaleDelta = (18 - size) / 2
        let padding = defaultPadding + scaleDelta
        
        return Image(systemName: name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .padding(EdgeInsets(top: padding, leading: padding + offset, bottom: padding, trailing: padding - offset))
            .background {
                if bg {
                    RoundedRectangle(cornerRadius: 5).foregroundStyle(.selection)
                }
            }
    }
    
    
    var body: some View {
        VStack {
            tldrawIcons
            
            HStack {
                VStack(spacing: 20) {
                    Text("Camera").font(.headline)
                    
                    mouseView()
                    
                    let mouseImage = cameraViews.cameraRenderer.render()!
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
                
                VStack(spacing: 20) {
                    Text("Rendered").font(.headline)
                    cameraViews.cameraRenderer.view(size: CGSize(square: 28))
                    cameraViews.cameraPlusRenderer.view(size: CGSize(square: 38))
                    cameraViews.cameraMinusRenderer.view(size: CGSize(square: 38))
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
