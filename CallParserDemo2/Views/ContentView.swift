//
//  ContentView.swift
//  CallParserDemo2
//
//  Created by Peter Bourget on 4/18/23.
//

import SwiftUI
import CallParser

struct ContentView: View {
    @EnvironmentObject var model: Model
    @Namespace private var glassNamespace

    @State private var callSign = ""
    @AppStorage("username") private var userId: String = ""
    @AppStorage("password") private var password: String = ""

    var body: some View {
        ZStack {
            backgroundView

            HStack(alignment: .top, spacing: 28) {
                controlPanel
                    .frame(width: 330)

                resultsPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(28)
        }
        .frame(minWidth: 1080, minHeight: 760)
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.15, blue: 0.24),
                    Color(red: 0.10, green: 0.27, blue: 0.39),
                    Color(red: 0.77, green: 0.88, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.22))
                .blur(radius: 120)
                .frame(width: 420, height: 420)
                .offset(x: -360, y: -260)

            Circle()
                .fill(Color.cyan.opacity(0.20))
                .blur(radius: 120)
                .frame(width: 460, height: 460)
                .offset(x: 360, y: 260)

            Rectangle()
                .fill(.black.opacity(0.08))
        }
        .ignoresSafeArea()
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Call Parser")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Parser controls, QRZ access, and quick call-sign exercises in a single Tahoe-style workspace.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)

            GlassEffectContainer(spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    authSection
                        .glassPanel(tint: .white.opacity(0.10), cornerRadius: 30)
                        .glassEffectID("auth", in: glassNamespace)

                    lookupSection
                        .glassPanel(tint: .cyan.opacity(0.12), cornerRadius: 30)
                        .glassEffectID("lookup", in: glassNamespace)

                    actionsSection
                        .glassPanel(tint: .blue.opacity(0.12), cornerRadius: 30)
                        .glassEffectID("actions", in: glassNamespace)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "QRZ Access", subtitle: "Store credentials locally and start an authenticated session.")

            TextField("QRZ username", text: $userId)
                .textFieldStyle(.plain)
                .glassInput()
                .onChange(of: userId) {
                    userId = normalizedUppercase(userId, maxLength: 10)
                }

            SecureField("Password", text: $password)
                .textFieldStyle(.plain)
                .glassInput()

            Button("Log On") {
                performLogon()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    private var lookupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Single Lookup", subtitle: "Inspect one call sign and surface all parsed metadata.")

            TextField("Enter call sign", text: $callSign)
                .textFieldStyle(.plain)
                .glassInput()
                .onChange(of: callSign) {
                    callSign = normalizedUppercase(callSign, maxLength: 10)
                }
                .onSubmit(performSingleLookup)

            Button("Lookup Call") {
                performSingleLookup()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(callSign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Quick Actions", subtitle: "Exercise pair parsing and maintenance commands without leaving the screen.")

            Button("Lookup Pair: TX4YKP / OA5TY") {
                model.lookupCallPair(spotter: "TX4YKP", dx: "OA5TY")
            }
            .buttonStyle(.glass)

            Button("Lookup Pair: W6OP / C5C") {
                model.lookupCallPair(spotter: "W6OP", dx: "C5C")
            }
            .buttonStyle(.glass)

            Button("Batch Lookup (all samples)") {
                model.lookupBatch()
            }
            .buttonStyle(.glass)

            Picker("Data set", selection: $model.selectedDataSet) {
                ForEach(BenchmarkDataSet.allCases, id: \.self) { dataSet in
                    Text(dataSet.label).tag(dataSet)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Run Benchmark") {
                    model.runBenchmark()
                }
                .buttonStyle(.glass)
                .disabled(model.benchmarkRunning)

                if model.benchmarkRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let result = model.benchmarkResult {
                Text(result)
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(Color.mediumBlueText)
            }

            Divider()
                .overlay(.white.opacity(0.15))

            Button("Download cty.dat") {
                model.downloadBigCTY()
            }
            .buttonStyle(.glass)

            Button("Clear Results Cache") {
                model.clearCache()
            }
            .buttonStyle(.glass(.regular.tint(.red.opacity(0.22))))
        }
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            resultsHeader

            if model.publishedHitList.isEmpty {
                EmptyResultsView()
                    .glassPanel(tint: .white.opacity(0.08), cornerRadius: 36)
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 18) {
                        LazyVStack(spacing: 18) {
                            ForEach(Array(model.publishedHitList.enumerated()), id: \.element.id) { index, hit in
                                HitCard(hit: hit)
                                    .glassPanel(
                                        tint: index.isMultiple(of: 2) ? .white.opacity(0.08) : .cyan.opacity(0.10),
                                        cornerRadius: 28
                                    )
                                    .glassEffectID(hit.id, in: glassNamespace)
                            }
                        }
                        .padding(20)
                    }
                }
                .glassPanel(tint: .white.opacity(0.06), cornerRadius: 36)
            }
        }
    }

    private var resultsHeader: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lookup Results")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.mediumBlueText)

                    Text(resultSummary)
                        .foregroundStyle(Color.mediumBlueText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !model.publishedHitList.isEmpty {
                    Label("\(model.publishedHitList.count) Hits", systemImage: "waveform.path.ecg.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mediumBlueText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.tint(.cyan.opacity(0.18)).interactive(), in: .capsule)
                        .glassEffectID("count", in: glassNamespace)
                }
            }
        }
    }

    private var resultSummary: String {
        if model.publishedHitList.isEmpty {
            return "No active lookup"
        }

        if let firstHit = model.publishedHitList.first {
            return "Showing parsed metadata for \(firstHit.call.uppercased()) and related matches"
        }

        return "Showing parsed metadata"
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        let titleColor = Color(red: 0.18, green: 0.38, blue: 0.72)
        let subtitleColor = Color(red: 0.24, green: 0.45, blue: 0.78)

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(titleColor)
                .shadow(color: .white.opacity(0.35), radius: 6, x: 0, y: 1)

            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(subtitleColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func normalizedUppercase(_ value: String, maxLength: Int) -> String {
        String(value.uppercased().prefix(maxLength))
    }

    private func performLogon() {
        Task {
            await model.logonToQRZ(userId: userId, password: password)
        }
    }

    private func performSingleLookup() {
        let trimmedCall = callSign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCall.isEmpty else { return }
        callSign = trimmedCall.uppercased()
        model.lookupSingleCall(call: trimmedCall)
    }
}

private struct HitCard: View {
    let hit: Hit

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(hit.call)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mediumBlueText)

                    Text(hit.country.isEmpty ? "Unknown country" : hit.country)
                        .font(.headline)
                        .foregroundStyle(Color.mediumBlueText)
                }

                Spacer()

                Text(hit.kind.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mediumBlueText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: .capsule)
            }

            HStack(spacing: 12) {
                MetadataChip(title: "DXCC", value: hit.dxcc_entity == 0 ? "-" : String(hit.dxcc_entity))
                MetadataChip(title: "Province", value: displayValue(hit.province))
                MetadataChip(title: "Continent", value: displayValue(hit.continent))
                MetadataChip(title: "Grid", value: displayValue(hit.grid))
            }

            if !detailRows.isEmpty {
                Divider()
                    .overlay(.white.opacity(0.14))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)], alignment: .leading, spacing: 14) {
                    ForEach(detailRows, id: \.title) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.mediumBlueText)

                            Text(row.value)
                                .font(.body)
                                .foregroundStyle(Color.mediumBlueText)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .padding(22)
    }

    private var detailRows: [(title: String, value: String)] {
        let rows: [(title: String, value: String)] = [
            (title: "CQ Zone", value: zoneText(from: hit.cq_zone)),
            (title: "ITU Zone", value: zoneText(from: hit.itu_zone)),
            (title: "Latitude", value: displayValue(hit.latitude)),
            (title: "Longitude", value: displayValue(hit.longitude)),
            (title: "City", value: displayValue(hit.city)),
            (title: "County", value: displayValue(hit.county)),
            (title: "Time Zone", value: displayValue(hit.timeZone)),
            (title: "Comment", value: displayValue(hit.comment))
        ]

        return rows.filter { $0.value != "-" }
    }

    private func displayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }

    private func zoneText(from values: Set<Int>) -> String {
        values.isEmpty ? "-" : values.sorted().map(String.init).joined(separator: ", ")
    }
}

private struct EmptyResultsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Color.mediumBlueText)
                .padding(24)
                .glassEffect(.regular.tint(.cyan.opacity(0.18)).interactive(), in: .circle)

            VStack(spacing: 8) {
                Text("No Results Yet")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.mediumBlueText)

                Text("Run a lookup from the left panel to inspect parsed call sign data.")
                    .font(.headline)
                    .foregroundStyle(Color.mediumBlueText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
    }
}

private struct MetadataChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.mediumBlueText)

            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.mediumBlueText)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.white.opacity(0.06)).interactive(), in: .rect(cornerRadius: 18))
    }
}

private extension Color {
    static let mediumBlueText = Color(red: 0.18, green: 0.38, blue: 0.72)
}

private extension View {
    func glassPanel(tint: Color, cornerRadius: CGFloat) -> some View {
        self
            .padding(20)
            .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
    }

    func glassInput() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .foregroundStyle(Color(red: 0.18, green: 0.38, blue: 0.72))
            .tint(Color(red: 0.18, green: 0.38, blue: 0.72))
            .glassEffect(.regular.tint(.white.opacity(0.06)).interactive(), in: .rect(cornerRadius: 16))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(Model())
    }
}
