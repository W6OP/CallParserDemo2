//
//  LookupComparison.swift
//  CallParserDemo2
//
//  Per-call diff between the legacy and bitset lookup paths. Used to
//  surface regressions in the bitset path against the legacy ground truth.
//

import Foundation
import CallParser

struct LookupComparison: Identifiable, Equatable {
    var id: String { call }

    let call: String
    let legacyEntries: [Entry]
    let bitsetEntries: [Entry]

    /// `true` if the two paths returned different DXCC entity sets.
    /// Order and count differences don't count as "differing" — only the
    /// underlying entity set matters.
    var differs: Bool {
        Set(legacyEntries.map(\.dxcc)) != Set(bitsetEntries.map(\.dxcc))
    }

    struct Entry: Hashable, Sendable {
        let dxcc: Int
        let country: String
    }

    static func from(call: String, legacyHits: [Hit], bitsetHits: [Hit]) -> LookupComparison {
        LookupComparison(
            call: call,
            legacyEntries: legacyHits.map { Entry(dxcc: $0.dxcc_entity, country: $0.country) },
            bitsetEntries: bitsetHits.map { Entry(dxcc: $0.dxcc_entity, country: $0.country) }
        )
    }
}
