//
//  SwitchHeadphoneIntent.swift
//  SyncBudsWidget + SyncBuds (both targets)
//
//  NOTE: This file must be added to BOTH the SyncBuds and SyncBudsWidget targets
//  via Xcode File Inspector → Target Membership.
//

import AppIntents

struct SwitchHeadphoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Headphone"
    static var description = IntentDescription("Send headphone to Mac or iPhone")

    func perform() async throws -> some IntentResult {
        SwitchIntentBridge.requestSwitch()
        return .result()
    }
}

// ForegroundContinuableIntent extension — app target ONLY.
// Marked unavailable in extension context so the widget target ignores it.
// This forces the intent to execute in the main app process (Pitfall 1 mitigation).
@available(iOSApplicationExtension, unavailable)
extension SwitchHeadphoneIntent: ForegroundContinuableIntent {}
