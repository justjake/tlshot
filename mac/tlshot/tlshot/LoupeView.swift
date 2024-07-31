//
//  LoupeView.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/11/24.
//

import SwiftUI

class LoupeViewPanel: ObservableObject  {
    @Published var viewOrigin: NSPoint = .zero
    @Published var viewSize: NSSize = NSSize(square: 128)
    @Published var sampleSize: NSSize = NSSize(square: 16)
    @Published var sampleCenter: NSPoint = .zero
    @Published var crosshairCenterSize: NSSize = NSSize(square: 8)
    
    var sampleRect: NSRect {
        NSRect(center: sampleCenter, size: sampleSize)
    }
    
    var frameRect: NSRect {
        NSRect(origin: viewOrigin, size: viewSize)
    }
    
    lazy var panel: some NSPanel = OverlayPanel(frameRect) {
        LoupeView(props: self)
    }
    
    func moveTo(_ point: NSPoint) {
        viewOrigin = point
        panel.setFrame(frameRect, display: true)
    }
    
    func sampleImage() -> CGImage? {
        ScreenshotService.shared.screenshot(sampleRect.isNS)
    }
    
    private var lastImage: CGImage?
    func image() -> CGImage? {
        lastImage = lastImage ?? sampleImage()
        return lastImage
    }
    
    func refresh() {
        lastImage = nil
    }
}

extension NSColor {
    var hexString: String {
        let red = Int(round(self.redComponent * 0xFF))
        let green = Int(round(self.greenComponent * 0xFF))
        let blue = Int(round(self.blueComponent * 0xFF))
        let hexString = NSString(format: "#%02X%02X%02X", red, green, blue)
        return hexString as String
    }
    
    // https://github.com/onmyway133/blog/issues/627
    var isLight: Bool {
        guard
            let components = cgColor.components,
            components.count >= 3
        else { return false }
        
        let brightness = ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000
        return brightness > 0.5
    }
}


struct LoupeView: View {
    static var numberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.paddingPosition = .beforePrefix
        formatter.paddingCharacter = " "
        formatter.maximumFractionDigits = 0
        formatter.hasThousandSeparators = false
        return formatter
    }()
    
    @ObservedObject var props: LoupeViewPanel
    
    var nsImage: NSImage? {
        props.image()?.nsImage()
    }
    
    var nsColor: NSColor {
        guard let image = props.image() else {
            return .black
        }
        let bitmap = NSBitmapImageRep(cgImage: image)
        return bitmap.colorAt(x: image.width / 2, y: image.height / 2) ?? .black
    }
    
    var color: Color {
        Color(nsColor: nsColor)
    }
    
    var textColor: Color {
        nsColor.isLight ? .black : .white
    }
    
    @ViewBuilder
    var image: some View {
        switch nsImage {
        case .some(let nsImage):
            Image(nsImage: nsImage)
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .none:
            Rectangle()
        }
    }
    
    var x: String {
        return String(format: "%4i", Int(props.sampleCenter.x))
    }
    
    var y: String {
        return String(format: "%4i", Int(props.sampleCenter.y))
    }
    
    var center: CGRect {
        CGRect(center: props.viewSize.center, size: props.crosshairCenterSize)
    }
    
    var cross: Path {
        Path { path in
            path.addRect(CGRect(center: props.viewSize.center, size: CGSize(width: props.viewSize.width, height: props.crosshairCenterSize.height)))
            path.addRect(CGRect(center: props.viewSize.center, size: CGSize(width: props.crosshairCenterSize.width, height: props.viewSize.height)))
        }
    }
    
    var crosshairPath: Path {
        return cross.subtracting(Path(center))
    }
    
    @ViewBuilder
    var crosshairs: some View {
        crosshairPath.foregroundStyle(.gray.blendMode(.multiply))
        crosshairPath.stroke(lineWidth: 3)
            .subtracting(Path(center))
            .subtracting(cross)
            .clipped().foregroundStyle(.gray.blendMode(.screen))
    }
    
    var body: some View {
        ZStack {
            image
            
            crosshairs
            
            VStack {
                Spacer()
                HStack {
                    Text("\(x) x \(y)")
                    
                    Spacer()
                    
                    Text(nsColor.hexString)
                }
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(textColor.opacity(0.8))
                .background(color.opacity(0.9)).frame(maxWidth: .infinity)
                
                
            }
        }
        .frame(width: props.viewSize.width, height: props.viewSize.height)
        .overlay(Rectangle().strokeBorder(Color(NSColor.separatorColor), lineWidth: 1))
        .padding(1)
        .overlay(Rectangle().strokeBorder(Color.black.opacity(0.8), lineWidth: 1))
    }
}

struct PreviewView: View {
    @StateObject var props = LoupeViewPanel()
    @State var trackMouse = true
    
    
    var body: some View {
        return VStack {
            LoupeView(props: props)
                .padding()
                .onFrame { _ in
                    if trackMouse && props.sampleCenter != NSEvent.mouseLocation {
                        props.sampleCenter = NSEvent.mouseLocation
                        props.refresh()
                    }
                }
            
            Toggle(isOn: $trackMouse) { Text("Track mouse?") }
        }
    }
    
    
}

#Preview {
    PreviewView()
}

