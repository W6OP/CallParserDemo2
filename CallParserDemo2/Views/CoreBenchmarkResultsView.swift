//
//  CoreBenchmarkResultsView.swift
//  CallParserDemo2
//
//  Apples-to-apples comparison of legacy vs bitset for the two pieces of
//  work that differ between the paths: index build, and raw candidate
//  finding (with input cleaning hoisted out of the timed window).
//

import SwiftUI
import CallParser

struct CoreBenchmarkResultsView: View {
    let results: [BenchmarkDataSet: CoreBenchmarkResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Core Benchmark (last run)")
                .font(.caption.bold())
                .foregroundStyle(Color.mediumBlueText)

            if results.isEmpty {
                Text("Run the core benchmark to see numbers.")
                    .font(.caption2)
                    .foregroundStyle(Color.mediumBlueText.opacity(0.75))
            } else {
                ForEach(BenchmarkDataSet.allCases, id: \.self) { dataSet in
                    if let result = results[dataSet] {
                        CoreBenchmarkRow(result: result)
                    }
                }
            }
        }
    }
}

private struct CoreBenchmarkRow: View {
    let result: CoreBenchmarkResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(result.dataSetLabel) — \(result.callCount.formatted(.number)) calls")
                .font(.caption.bold())
                .foregroundStyle(Color.mediumBlueText)

            metricBlock(
                title: "Index build",
                legacy: "\(result.legacyParseMicros.formatted(.number)) µs",
                bitset: "\(result.bitsetParseMicros.formatted(.number)) µs",
                speedup: result.parseSpeedup
            )

            metricBlock(
                title: "Lookup (total)",
                legacy: "\(formatLookupTotal(result.legacyLookupNanos)) — avg \(result.legacyAvgPerCallNanos.formatted(.number)) ns/call",
                bitset: "\(formatLookupTotal(result.bitsetLookupNanos)) — avg \(result.bitsetAvgPerCallNanos.formatted(.number)) ns/call",
                speedup: result.lookupSpeedup
            )

            coverageBlock(result: result)
        }
        .padding(.vertical, 4)
    }

    private func metricBlock(title: String, legacy: String, bitset: String, speedup: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.mediumBlueText.opacity(0.75))

            HStack(alignment: .top, spacing: 12) {
                resultColumn(title: "Legacy", value: legacy)
                resultColumn(title: "Bitset", value: bitset)
            }

            if speedup > 0 {
                Text("Bitset \(speedup, format: .number.precision(.fractionLength(2)))× faster")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(speedup >= 1 ? .green : Color.mediumBlueText)
            }
        }
    }

    private func coverageBlock(result: CoreBenchmarkResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Coverage (matched ≥1 PrefixData)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.mediumBlueText.opacity(0.75))

            HStack(alignment: .top, spacing: 12) {
                resultColumn(title: "Legacy", value: "\(result.legacyResolved) / \(result.callCount)")
                resultColumn(title: "Bitset", value: "\(result.bitsetResolved) / \(result.callCount)")
            }
        }
    }

    private func resultColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.mediumBlueText.opacity(0.75))
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(Color.mediumBlueText)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatLookupTotal(_ nanos: Int64) -> String {
        if nanos >= 10_000_000 {
            let ms = Double(nanos) / 1_000_000.0
            return "\(ms.formatted(.number.precision(.fractionLength(2)))) ms"
        }
        if nanos >= 10_000 {
            let micros = Double(nanos) / 1_000.0
            return "\(micros.formatted(.number.precision(.fractionLength(1)))) µs"
        }
        return "\(nanos.formatted(.number)) ns"
    }
}
