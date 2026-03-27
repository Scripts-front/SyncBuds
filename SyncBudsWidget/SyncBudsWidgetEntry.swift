//
//  SyncBudsWidgetEntry.swift
//  SyncBudsWidget
//

import WidgetKit
import Foundation

struct SyncBudsWidgetEntry: TimelineEntry {
    let date: Date
    let isConnected: Bool
    let peerBTStatus: String   // "connected" | "disconnected" | "unknown"
    let peerName: String?

    var statusTitle: String {
        isConnected ? "Connected to \(peerName ?? "Mac")" : "Mac offline"
    }

    var statusSubtitle: String {
        switch peerBTStatus {
        case "connected": return "Headphone is on Mac"
        case "disconnected": return "Headphone is available"
        default: return "Status unknown"
        }
    }

    var statusIcon: String {
        isConnected ? "headphones.circle.fill" : "headphones.circle"
    }
}
