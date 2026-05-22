//
//  BenchmarkResult.swift
//  CallParserDemo2
//

import Foundation
import CallParser

struct BenchmarkResult: Codable, Equatable, Identifiable {
    var id: String { dataSetRawValue }

    let dataSetRawValue: String
    let dataSetLabel: String
    let resolvedCount: Int
    let totalCount: Int
    let milliseconds: Int64

    init(
        dataSet: BenchmarkDataSet,
        resolvedCount: Int,
        totalCount: Int,
        milliseconds: Int64
    ) {
        self.dataSetRawValue = dataSet.rawValue
        self.dataSetLabel = dataSet.label
        self.resolvedCount = resolvedCount
        self.totalCount = totalCount
        self.milliseconds = milliseconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dataSetRawValue = try c.decode(String.self, forKey: .dataSetRawValue)
        self.dataSetLabel    = try c.decode(String.self, forKey: .dataSetLabel)
        self.resolvedCount   = try c.decode(Int.self, forKey: .resolvedCount)
        self.totalCount      = try c.decode(Int.self, forKey: .totalCount)
        self.milliseconds    = try c.decode(Int64.self, forKey: .milliseconds)
    }

    var summary: String {
        "\(resolvedCount) of \(totalCount) resolved in \(milliseconds.formatted(.number)) ms"
    }

    var dataSet: BenchmarkDataSet? {
        BenchmarkDataSet(rawValue: dataSetRawValue)
    }

    func isFaster(than other: BenchmarkResult) -> Bool {
        milliseconds < other.milliseconds
    }
}
