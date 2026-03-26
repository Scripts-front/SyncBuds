//
//  SyncSignalTests.swift
//  SyncBudsTests
//

import Testing
@testable import SyncBuds

struct SyncSignalTests {

    // MARK: - Codable round-trip (COM-01)

    @Test func encodesToData() throws {
        let signal = SyncSignal(
            type: .status,
            sender: .mac,
            timestamp: Date(),
            bluetoothStatus: "connected"
        )
        let data = try JSONEncoder().encode(signal)
        #expect(!data.isEmpty)
    }

    @Test func roundTripsCorrectly() throws {
        let original = SyncSignal(
            type: .switchRequest,
            sender: .ios,
            timestamp: Date(),
            bluetoothStatus: "disconnected"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SyncSignal.self, from: data)

        #expect(decoded.type == original.type)
        #expect(decoded.sender == original.sender)
        #expect(decoded.bluetoothStatus == original.bluetoothStatus)
    }

    // MARK: - Staleness check (Pitfall 6 mitigation)

    @Test func freshSignalIsAccepted() {
        let signal = SyncSignal(
            type: .status,
            sender: .mac,
            timestamp: Date(),
            bluetoothStatus: "connected"
        )
        #expect(signal.isFresh == true)
    }

    @Test func staleSignalIsRejected() {
        let signal = SyncSignal(
            type: .status,
            sender: .ios,
            timestamp: Date().addingTimeInterval(-31),
            bluetoothStatus: "connected"
        )
        #expect(signal.isFresh == false)
    }

    // MARK: - Raw values (contract stability)

    @Test func signalTypeRawValues() {
        #expect(SyncSignal.SignalType.status.rawValue == "status")
        #expect(SyncSignal.SignalType.switchRequest.rawValue == "switchRequest")
    }

    @Test func platformRawValues() {
        #expect(SyncSignal.Platform.mac.rawValue == "mac")
        #expect(SyncSignal.Platform.ios.rawValue == "ios")
    }
}
