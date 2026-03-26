//
//  iOSContentView.swift
//  SyncBuds
//

#if os(iOS)
import SwiftUI

struct iOSContentView: View {
    @Environment(MultipeerService.self) private var multipeerService
    @Environment(SwitchCoordinator.self) private var switchCoordinator
    @AppStorage("autoSwitchEnabled") private var autoSwitchEnabled: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: - Connection Status Card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                multipeerService.isConnectedToPeer
                                    ? "Connected to \(multipeerService.connectedPeerName ?? "peer")"
                                    : "Peer offline",
                                systemImage: multipeerService.isConnectedToPeer
                                    ? "iphone.and.arrow.forward"
                                    : "xmark.circle"
                            )
                            .font(.headline)
                            .foregroundStyle(multipeerService.isConnectedToPeer ? .primary : .secondary)

                            Text(headphoneStatusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("Connection", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                    // MARK: - Switch Action Card
                    GroupBox {
                        Button {
                            Task { switchCoordinator.requestSwitch() }
                        } label: {
                            Label(switchLabel, systemImage: switchIcon)
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(switchDisabled)
                        .padding(.vertical, 4)

                        if case .error(let msg) = switchCoordinator.switchState {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } label: {
                        Label("Switching", systemImage: "arrow.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))

                    // MARK: - Auto-switch Settings Card (per D-03)
                    GroupBox {
                        Toggle("Auto-switch on foreground", isOn: $autoSwitchEnabled)
                            .font(.subheadline)
                        Text("When enabled, SyncBuds automatically switches the headphone to iPhone when you open the app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } label: {
                        Label("Automation", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                }
                .padding()
            }
            .navigationTitle("SyncBuds")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Computed Properties

    private var headphoneStatusText: String {
        guard multipeerService.isConnectedToPeer else {
            return "Open SyncBuds on your Mac to connect"
        }
        switch multipeerService.peerBluetoothStatus {
        case "connected":
            return "Headphone is on \(multipeerService.connectedPeerName ?? "peer")"
        case "disconnected":
            return "Headphone is available"
        default:
            return "Headphone status unknown"
        }
    }

    private var switchLabel: String {
        switch switchCoordinator.switchState {
        case .idle:
            return "Switch Headphone"
        case .switching:
            return "Switching..."
        case .cooldown:
            return "Cooldown active"
        case .error:
            return "Retry Switch"
        }
    }

    private var switchIcon: String {
        switch switchCoordinator.switchState {
        case .idle:
            return "arrow.2.circlepath"
        case .switching:
            return "arrow.2.circlepath"
        case .cooldown:
            return "clock"
        case .error:
            return "exclamationmark.arrow.circlepath"
        }
    }

    private var switchDisabled: Bool {
        switch switchCoordinator.switchState {
        case .idle, .error:
            return false
        case .switching, .cooldown:
            return true
        }
    }
}

#Preview {
    iOSContentView()
        .environment(MultipeerService())
        .environment(SwitchCoordinator())
}
#endif
