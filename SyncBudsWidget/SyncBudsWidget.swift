//
//  SyncBudsWidget.swift
//  SyncBudsWidget
//

import WidgetKit
import SwiftUI

struct SyncBudsWidget: Widget {
    let kind: String = "SyncBudsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SyncBudsWidgetProvider()) { entry in
            SyncBudsWidgetView(entry: entry)
        }
        .configurationDisplayName("SyncBuds")
        .description("Switch headphones between your Mac and iPhone.")
        .supportedFamilies([.systemMedium])
    }
}
