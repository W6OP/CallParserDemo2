//
//  BenchmarkResultsView.swift
//  CallParserDemo2
//

import SwiftUI
import CallParser

struct BenchmarkResultsView: View {
    let latestResults: [BenchmarkResultKey: BenchmarkResult]
    let previousResults: [BenchmarkResultKey: BenchmarkResult]
    let bestResults: [BenchmarkResultKey: BenchmarkResult]
    let status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(BenchmarkDataSet.allCases, id: \.self) { dataSet in
                ForEach(BenchmarkMethod.allCases, id: \.self) { method in
                    let key = BenchmarkResultKey(dataSet: dataSet, method: method)
                    BenchmarkResultRow(
                        dataSet: dataSet,
                        method: method,
                        latestResult: latestResults[key],
                        previousResult: previousResults[key] ?? bestResults[key]
                    )
                }
            }

            if let status {
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct BenchmarkResultRow: View {
    let dataSet: BenchmarkDataSet
    let method: BenchmarkMethod
    let latestResult: BenchmarkResult?
    let previousResult: BenchmarkResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(dataSet.label) — \(method.label)")
                .font(.caption.bold())
                .foregroundStyle(Color.mediumBlueText)

            HStack(alignment: .top, spacing: 12) {
                resultColumn(title: previousTitle, result: previousResult)
                resultColumn(title: "New run", result: latestResult)
            }

            if let comparisonText {
                Text(comparisonText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(comparisonColor)
            }
        }
        .padding(.vertical, 6)
    }

    private var previousTitle: String {
        latestResult == nil ? "Stored best" : "Previous best"
    }

    private var comparisonText: String? {
        guard let latestResult else { return nil }
        guard let previousResult else { return "First saved result" }

        if latestResult.milliseconds < previousResult.milliseconds {
            return "Improved by \((previousResult.milliseconds - latestResult.milliseconds).formatted(.number)) ms"
        }
        if latestResult.milliseconds > previousResult.milliseconds {
            return "Kept existing best by \((latestResult.milliseconds - previousResult.milliseconds).formatted(.number)) ms"
        }
        return "Matched existing best"
    }

    private var comparisonColor: Color {
        guard let latestResult, let previousResult else { return Color.mediumBlueText }
        return latestResult.milliseconds <= previousResult.milliseconds ? .green : Color.mediumBlueText
    }

    private func resultColumn(title: String, result: BenchmarkResult?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.mediumBlueText.opacity(0.75))

            Text(result?.summary ?? "No result yet")
                .font(.caption.monospaced())
                .foregroundStyle(Color.mediumBlueText)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
