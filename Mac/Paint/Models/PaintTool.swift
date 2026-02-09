//
//  PaintTool.swift
//  Paint
//
//  Tool set: Line, Pencil, Circle, Rectangle, Spray, Fill, Text, Eraser.
//

import SwiftUI
import AppKit

enum PaintTool: String, CaseIterable, Identifiable {
    case line = "Line"
    case brush = "Pencil"
    case ellipse = "Circle"
    case rectangle = "Rectangle"
    case airbrush = "Spray"
    case fill = "Fill"
    case text = "Text"
    case eraser = "Eraser"

    var id: String { rawValue }

    /// SF Symbols: paintbrush.fill, humidity.fill, etc. (use names that exist in the SF Symbols app).
    var systemImage: String {
        switch self {
        case .line: return "line.diagonal"
        case .brush: return "paintbrush.fill"
        case .ellipse: return "circle"
        case .rectangle: return "rectangle"
        case .airbrush: return "humidity.fill"
        case .fill: return "drop.fill"
        case .text: return "textformat"
        case .eraser: return "eraser"
        }
    }

    var hasShapePreview: Bool {
        switch self {
        case .line, .rectangle, .ellipse: return true
        default: return false
        }
    }
}
