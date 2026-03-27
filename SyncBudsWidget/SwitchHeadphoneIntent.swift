//
//  SwitchHeadphoneIntent.swift
//  SyncBudsWidget + SyncBuds (both targets)
//

import AppIntents
import Foundation

struct SwitchHeadphoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Headphone"
    static var description = IntentDescription("Send headphone to Mac or iPhone")

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: Notification.Name("widgetSwitchRequested"),
            object: nil
        )
        return .result()
    }
}

#if os(iOS)
@available(iOSApplicationExtension, unavailable)
extension SwitchHeadphoneIntent: ForegroundContinuableIntent {}
#endif
