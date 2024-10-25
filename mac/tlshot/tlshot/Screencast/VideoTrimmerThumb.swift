//
//  VideoTrimmerThumb.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 9/23/24.
//
// Adapted from:
//  VideoTrimmerThumb.swift
//  https://github.com/AndreasVerhoeven/VideoTrimmerControl/blob/main/VideoTrimmerThumb.swift
//  Created by Andreas Verhoeven on 02/09/2020.
//  Copyright © 2020 Andreas Verhoeven. All rights reserved.
//

import SwiftUI

struct VideoTrimmerThumb: View {
    @State var isActive = false
    @State var color = Color.yellow
    
    var leadingGestureRecognizer: any Gesture
    var trailingGestureRecognizer: any Gesture
    
    var leadingChevronImageView: some View {
        Image(systemName: "chevron.compact.left")
            .foregroundStyle(.white)
            .scaledToFill()
        // Tint adjust mode?
    }
    var trailingChevronImageView: some View {
        Image(systemName: "chevron.compact.right")
            .foregroundStyle(.white)
            .scaledToFill()
        // Tint adjust mode?
    }
    
    let chevronWidth = CGFloat(16)
    let edgeHeight = CGFloat(4)
    let chevronHorizontalInset = CGFloat(2)
    let chevronVerticalInset = CGFloat(8)

    private var leadingView: some View {
        leadingChevronImageView
            .padding(.vertical, 6)
            .frame(minWidth: chevronWidth, maxHeight: .infinity)
            .background {
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 6, bottomLeading: 6, bottomTrailing: 0, topTrailing: 0),
                    style: .continuous
                ).fill(color)
            }
//            .gesture(leadingGestureRecognizer)
    }
    
    private var trailingView: some View {
        trailingChevronImageView
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .frame(minWidth: chevronWidth, maxHeight: .infinity)
            .background {
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 0, bottomTrailing: 6, topTrailing: 6),
                    style: .continuous
                ).fill(color)
            }
//        .gesture(trailingGestureRecognizer)

    }
    
    var body: some View {
        HStack(spacing: 0) {
            leadingView
            
            Rectangle()
                .fill(.clear)
                .border(width: edgeHeight, edges: [.top, .bottom], color: .yellow)
            
            trailingView
        }
        .compositingGroup()
        .shadow(radius: 2)
//        .grou
    }
}

#Preview {
    VideoTrimmerThumb(leadingGestureRecognizer: LongPressGesture(), trailingGestureRecognizer: LongPressGesture())
        .frame(height: 50)
        .padding()
}
