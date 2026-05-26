//
//  ConsoleResizeHandle.swift
//  Brew
//

import AppKit
import SwiftUI

/// Drag handle at the top of the expanded console — drags resize the body, clamped by ``BrewLayout`` bounds.
/// Cursor swaps to `resizeUpDown` while hovering; `push`/`pop` is paired in `onHover` so it doesn't leak.
struct ConsoleResizeHandle: View {
    @Binding var height: Double
    @State private var startHeight: Double?

    var body: some View {
        Rectangle()
            .fill(Color.brewBorderSeparator.opacity(0.5))
            .frame(height: BrewLayout.consoleResizeHandleHeight)
            .overlay {
                Capsule()
                    .fill(Color.brewBorderStrong)
                    .frame(width: 28, height: 2)
            }
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if startHeight == nil {
                            startHeight = height
                        }
                        let proposed = (startHeight ?? height) - value.translation.height
                        height = min(
                            max(proposed, BrewLayout.consoleMinExpandedHeight),
                            BrewLayout.consoleMaxExpandedHeight,
                        )
                    }
                    .onEnded { _ in
                        startHeight = nil
                    },
            )
    }
}
