//
//  Haptics.swift
//  SwagManager (macOS)
//
//  Haptics stub for macOS (no haptic feedback on macOS)
//  Maintains API compatibility with iOS code
//

import Foundation

enum Haptics {
    static func light() {
        // No-op on macOS
    }

    static func medium() {
        // No-op on macOS
    }

    static func heavy() {
        // No-op on macOS
    }

    static func success() {
        // No-op on macOS
    }

    static func error() {
        // No-op on macOS
    }

    static func warning() {
        // No-op on macOS
    }
}
