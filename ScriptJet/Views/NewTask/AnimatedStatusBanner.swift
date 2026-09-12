//
//  AnimatedStatusBanner.swift
//  ScriptJet
//
//  Created by Yuki Suzuki on 9/11/26.
//

import SwiftUI

//struct AnimatedStatusBanner: View {
//    let title: String
//    let themeColor: Color
//    
//    @State private var isAnimating = false
//    
//    var body: some View {
//        HStack(spacing: 8) {
//            ProgressView()
//                .controlSize(.small)
//                .tint(themeColor)
//            
//            Text(title)
//                .font(.system(size: 12.5, weight: .medium))
//                .foregroundStyle(.primary)
//            
//            Spacer()
//        }
//        .padding(12)
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(
//            // Animated moving gradient background
//            LinearGradient(
//                colors: [
//                    themeColor.opacity(0.12),
//                    themeColor.opacity(0.28),
//                    themeColor.opacity(0.12)
//                ],
//                startPoint: isAnimating ? .leading : .trailing,
//                endPoint: isAnimating ? .trailing : .leading
//            )
//        )
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(themeColor.opacity(0.3), lineWidth: 1)
//        )
//        .clipShape(RoundedRectangle(cornerRadius: 8))
//        .onAppear {
//            withAnimation(
//                .easeInOut(duration: 1.5)
//                .repeatForever(autoreverses: true)
//            ) {
//                isAnimating = true
//            }
//        }
//    }
//}


import SwiftUI

struct AnimatedStatusBanner: View {
    let title: String
    let themeColor: Color
    
    @State private var offsetMultiplier: CGFloat = -1.0
    
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(themeColor)
            
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Background base container
        .background(themeColor.opacity(0.1))
        // Moving highlight overlay
        .background(
            GeometryReader { geometry in
                let barWidth = geometry.size.width * 0.4
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeColor.opacity(0.0),
                                themeColor.opacity(0.35),
                                themeColor.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: barWidth)
                    // Offset sweeps from past left boundary to past right boundary
                    .offset(x: offsetMultiplier * geometry.size.width)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                        ) {
                            offsetMultiplier = 1.0
                        }
                    }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
