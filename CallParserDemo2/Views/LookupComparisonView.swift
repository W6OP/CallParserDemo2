//
//  LookupComparisonView.swift
//  CallParserDemo2
//
//  Renders rows where the legacy and bitset lookup paths disagree.
//

import SwiftUI
import CallParser

struct LookupComparisonView: View {
    let comparisons: [LookupComparison]
    let summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Legacy vs Bitset")
                .font(.caption.bold())
                .foregroundStyle(Color.mediumBlueText)

            if let summary {
                Text(summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(comparisons.isEmpty ? .green : Color.mediumBlueText)
            }

            ForEach(comparisons) { comparison in
                LookupComparisonRow(comparison: comparison)
            }
        }
    }
}

private struct LookupComparisonRow: View {
    let comparison: LookupComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(comparison.call)
                .font(.caption.monospaced().bold())
                .foregroundStyle(Color.mediumBlueText)

            HStack(alignment: .top, spacing: 12) {
                column(title: "Legacy", entries: comparison.legacyEntries)
                column(title: "Bitset", entries: comparison.bitsetEntries)
            }
        }
        .padding(.vertical, 4)
    }

    private func column(title: String, entries: [LookupComparison.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.mediumBlueText.opacity(0.75))

            if entries.isEmpty {
                Text("(no hits)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.red)
            } else {
                ForEach(entries, id: \.self) { entry in
                    Text("\(entry.dxcc): \(displayCountry(entry.country))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.mediumBlueText)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func displayCountry(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}
