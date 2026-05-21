//
//  BenchmarkResult.swift
//  CallParserDemo2
//

import Foundation
import CallParser

/// Which mask-matching path was exercised for the benchmark.
enum BenchmarkMethod: String, CaseIterable, Codable, Sendable, Hashable {
    case legacy
    case bitset

    var label: String {
        switch self {
        case .legacy: "Legacy"
        case .bitset: "Bitset"
        }
    }
}

/// Composite key so the model can persist one best result per
/// `(dataSet, method)` pair.
struct BenchmarkResultKey: Hashable, Sendable {
    let dataSet: BenchmarkDataSet
    let method: BenchmarkMethod
}

struct BenchmarkResult: Codable, Equatable, Identifiable {
    var id: String { "\(dataSetRawValue).\(methodRawValue)" }

    let dataSetRawValue: String
    let dataSetLabel: String
    let methodRawValue: String
    let resolvedCount: Int
    let totalCount: Int
    let milliseconds: Int64

    init(
        dataSet: BenchmarkDataSet,
        method: BenchmarkMethod,
        resolvedCount: Int,
        totalCount: Int,
        milliseconds: Int64
    ) {
        self.dataSetRawValue = dataSet.rawValue
        self.dataSetLabel = dataSet.label
        self.methodRawValue = method.rawValue
        self.resolvedCount = resolvedCount
        self.totalCount = totalCount
        self.milliseconds = milliseconds
    }

    // Backwards-compatible decode: records persisted before the method
    // field existed default to `.legacy`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dataSetRawValue = try c.decode(String.self, forKey: .dataSetRawValue)
        self.dataSetLabel    = try c.decode(String.self, forKey: .dataSetLabel)
        self.methodRawValue  = try c.decodeIfPresent(String.self, forKey: .methodRawValue)
            ?? BenchmarkMethod.legacy.rawValue
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

    var method: BenchmarkMethod {
        BenchmarkMethod(rawValue: methodRawValue) ?? .legacy
    }

    var key: BenchmarkResultKey? {
        guard let dataSet else { return nil }
        return BenchmarkResultKey(dataSet: dataSet, method: method)
    }

    func isFaster(than other: BenchmarkResult) -> Bool {
        milliseconds < other.milliseconds
    }
}

// MARK: - Core Benchmark

/// Apples-to-apples micro-comparison of just the unique work each path does:
/// index build (legacy shape patterns vs bitset compile + insert) and raw
/// candidate finding with input cleaning hoisted out of the timed window.
struct CoreBenchmarkResult: Codable, Equatable, Identifiable {
    var id: String { dataSetRawValue }

    let dataSetRawValue: String
    let dataSetLabel: String
    let callCount: Int
    let legacyResolved: Int
    let bitsetResolved: Int
    let legacyParseMicros: Int64
    let bitsetParseMicros: Int64
    let legacyLookupNanos: Int64
    let bitsetLookupNanos: Int64

    var dataSet: BenchmarkDataSet? {
        BenchmarkDataSet(rawValue: dataSetRawValue)
    }

    var legacyAvgPerCallNanos: Int64 {
        callCount > 0 ? legacyLookupNanos / Int64(callCount) : 0
    }

    var bitsetAvgPerCallNanos: Int64 {
        callCount > 0 ? bitsetLookupNanos / Int64(callCount) : 0
    }

    /// Speedup ratio of bitset over legacy for the index build step.
    var parseSpeedup: Double {
        guard bitsetParseMicros > 0 else { return 0 }
        return Double(legacyParseMicros) / Double(bitsetParseMicros)
    }

    /// Speedup ratio of bitset over legacy for the per-call lookup primitive.
    var lookupSpeedup: Double {
        guard bitsetLookupNanos > 0 else { return 0 }
        return Double(legacyLookupNanos) / Double(bitsetLookupNanos)
    }
}
