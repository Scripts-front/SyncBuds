//
//  SyncBudsWidgetView.swift
//  SyncBudsWidget
//

import SwiftUI
import WidgetKit

struct SyncBudsWidgetView: View {
    var entry: SyncBudsWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(entry.statusTitle, systemImage: entry.statusIcon)
                .font(.headline)
                .lineLimit(1)

            Text(entry.statusSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(intent: SwitchHeadphoneIntent()) {
                Label("Switch", systemImage: "arrow.2.circlepath")
                    .frame(maxWidth: .infinity)
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
