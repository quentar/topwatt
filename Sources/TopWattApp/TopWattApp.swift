import Foundation
import SwiftUI

@main
struct TopWattApp: App {
    @StateObject private var powerMonitor = PowerMonitor()

    var body: some Scene {
        MenuBarExtra {
            ContentView(powerMonitor: powerMonitor)
        } label: {
            Text(powerMonitor.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class PowerMonitor: ObservableObject {
    @Published private(set) var wattage: Int = 0
    @Published private(set) var chargerDetails = "Loading charger information..."
    @Published private(set) var lastUpdated: Date?

    private var refreshTask: Task<Void, Never>?
    private let refreshIntervalNanoseconds: UInt64 = 15_000_000_000

    init() {
        refreshTask = Task {
            await refreshLoop()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var menuBarTitle: String {
        "\(wattage)W"
    }

    func refreshNow() {
        Task {
            await loadPowerInfo()
        }
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            await loadPowerInfo()

            do {
                try await Task.sleep(nanoseconds: refreshIntervalNanoseconds)
            } catch {
                break
            }
        }
    }

    private func loadPowerInfo() async {
        let result = await Task.detached(priority: .utility) {
            PowerInfoLoader.fetch()
        }.value

        wattage = result.wattage
        chargerDetails = result.details
        lastUpdated = Date()
    }
}

enum PowerInfoLoader {
    static func fetch() -> (wattage: Int, details: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (0, fallbackDetails(message: error.localizedDescription))
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorText = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (0, fallbackDetails(message: errorText.isEmpty ? "system_profiler failed." : errorText))
        }

        let output = String(decoding: outputData, as: UTF8.self)
        let details = chargerSection(in: output) ?? disconnectedDetails()
        let wattage = parseWattage(from: details) ?? 0
        return (wattage, details)
    }

    static func chargerSection(in output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        guard let startIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "AC Charger Information:" }) else {
            return nil
        }

        var collected: [String] = []
        for line in lines[startIndex...] {
            if !collected.isEmpty {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let isTopLevelSection = !line.hasPrefix(" ") && !trimmed.isEmpty
                if isTopLevelSection {
                    break
                }
            }
            collected.append(line)
        }

        let section = collected.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return section.isEmpty ? nil : section
    }

    static func parseWattage(from chargerSection: String) -> Int? {
        for line in chargerSection.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("Wattage (W):") else { continue }
            let value = trimmed.replacingOccurrences(of: "Wattage (W):", with: "")
                .trimmingCharacters(in: .whitespaces)
            return Int(value)
        }
        return nil
    }

    static func disconnectedDetails() -> String {
        """
        AC Charger Information:

          Connected: No
          Wattage (W): 0
          Charging: No
        """
    }

    static func fallbackDetails(message: String) -> String {
        """
        AC Charger Information:

          Connected: Unknown
          Wattage (W): 0
          Error: \(message)
        """
    }
}

struct ContentView: View {
    @ObservedObject var powerMonitor: PowerMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(powerMonitor.menuBarTitle)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Divider()

            ScrollView {
                Text(powerMonitor.chargerDetails)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 420, minHeight: 120, maxHeight: 240)

            HStack {
                if let lastUpdated = powerMonitor.lastUpdated {
                    Text(lastUpdated.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Refresh") {
                    powerMonitor.refreshNow()
                }

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(14)
    }
}
