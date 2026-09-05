import SwiftUI
import AppKit

struct UpdateSettingsView: View {
    @ObservedObject var checker: UpdateChecker
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Button(checker.isChecking ? "Checking…" : "Check for Updates") { checker.check() }
                    .disabled(checker.isChecking)
                Spacer()
                if let url = checker.releaseURL {
                    Button("View Release") { NSWorkspace.shared.open(url) }
                }
            }
            Text(checker.message).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Check daily", isOn: Binding(get: { checker.automatic }, set: { checker.setAutomatic($0) }))
                .toggleStyle(.switch)
            Text("Off by default. Contacts GitHub only; downloads and installation stay manual.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }
}
