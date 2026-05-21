//
//  Model.swift
//  CallParserDemo2
//
//  Created by Peter Bourget on 4/18/23.
//

import Foundation
import CallParser

/// User-visible status for a QRZ.com logon attempt.
enum QRZLogonStatus: Equatable, Sendable {
  case idle
  case inProgress
  case success(String)
  case failure(String)
}

@MainActor class Model: ObservableObject {

  @Published var publishedHitList = [Hit]()
  @Published var latestBenchmarkResults = [BenchmarkResultKey: BenchmarkResult]()
  @Published var previousBenchmarkResults = [BenchmarkResultKey: BenchmarkResult]()
  @Published var bestBenchmarkResults = [BenchmarkResultKey: BenchmarkResult]()
  @Published var benchmarkStatus: String?
  @Published var benchmarkRunning = false
  @Published var qrzLogonStatus: QRZLogonStatus = .idle
  @Published var latestCoreBenchmark: [BenchmarkDataSet: CoreBenchmarkResult] = [:]
  /// Routes the production lookup pipeline through the bitset index when
  /// `true`. Mirrors the toggle on ``CallLookup`` so the UI can observe it.
  @Published var useBitsetLookup: Bool = false {
    didSet { callLookup.useBitsetLookup = useBitsetLookup }
  }
  /// Differing rows from the most recent legacy-vs-bitset comparison.
  @Published var lookupComparisons: [LookupComparison] = []
  @Published var comparisonSummary: String?
  @Published var comparisonRunning = false

  /// CSV-formatted exception report (call, legacy DXCC, bitset DXCC) listing
  /// every call where the two paths disagree on the resolved entity set.
  /// Populated by ``runExceptionReport(dataSet:)``.
  @Published var exceptionReport: String?
  @Published var exceptionReportRunning = false
  @Published var exceptionReportStatus: String?

  // Call Parser
  let callLookup: CallLookup

  private static let benchmarkResultsStorageKey = "benchmarkResults.best"
  private static let coreBenchmarkStorageKey = "coreBenchmarkResults.latest"

  init(loggingLevel: Bool) {
    callLookup = CallLookup(
      parsedData: PrefixFileParser.parse(),
      verboseLogging: loggingLevel
    )
    bestBenchmarkResults = Self.loadBestBenchmarkResults()
    latestCoreBenchmark = Self.loadCoreBenchmarkResults()
  }

  // MARK: NEW STUFF --------------------------------------------------------------------------


  /// Lookup a single call using a continuation.
  /// - Parameter call: String:
  func lookupSingleCall(call: String)  {
    Task {
      [callLookup] in
      publishedHitList = await callLookup.lookupCall(callSign: call)
    }
  }

  /// Look up a pair of call signs using a continuation.
  /// - Parameters:
  ///   - spotter: String:
  ///   - dx: String:
  func lookupCallPair(spotter: String, dx: String) {
      Task {
        [callLookup] in
        let hitPair = await callLookup.lookupCallPairGrouped(
          spotter: spotter,
          dx: dx)

        // call a func since can't capture async let result
         updatePublishedHitList(hits: hitPair.spotter + hitPair.dx)
        }
  }


  /// By calling this function we can update using the result of an async let.
  /// - Parameter hits: [Hit]
  @MainActor func updatePublishedHitList(hits: [Hit]) {
     publishedHitList = hits
  }

  func downloadBigCTY() {
    Task {
      [callLookup] in
      do {
        let data = try await callLookup.downloadAndParseBigCTY()
        callLookup.bigCTYData = data
        print("BigCTY downloaded: \(data.entities.count) entities, \(data.exactMatches.count) exact matches")
      } catch {
        print("BigCTY download failed: \(error)")
      }
    }
  }

  /// Look up all call signs in the sample list concurrently via TaskGroup.
  func lookupBatch() {
    Task {
      [callLookup] in
      let results = await callLookup.lookupBatch(callSigns: callSigns)
      // Flatten all results into a single list for display
      updatePublishedHitList(hits: results.values.flatMap { $0 })
    }
  }

  /// Benchmarks a data set with the chosen mask-matching method and persists
  /// the result when it beats the stored best for that `(dataSet, method)` pair.
  func runBenchmark(dataSet: BenchmarkDataSet, method: BenchmarkMethod) {
    let key = BenchmarkResultKey(dataSet: dataSet, method: method)
    previousBenchmarkResults[key] = bestBenchmarkResults[key]
    latestBenchmarkResults.removeValue(forKey: key)
    benchmarkStatus = nil
    benchmarkRunning = true
    let lookup = callLookup

    Task {
      let callSigns = CallLookup.loadCallSigns(from: dataSet, in: .main)
      guard !callSigns.isEmpty else {
        await MainActor.run {
          self.benchmarkStatus = "\(dataSet.label) not found"
          self.benchmarkRunning = false
        }
        return
      }

      // Both arms use the candidates-only primitive (no Hit construction)
      // so the timings are apples-to-apples: just the cost of finding
      // matching PrefixData entries for each call.
      let start = ContinuousClock.now
      let processed: Int
      switch method {
      case .legacy:
        let results = await lookup.legacyParseBatch(callSigns: callSigns)
        processed = results.values.filter { $0 > 0 }.count
      case .bitset:
        let results = await lookup.bitsetParseBatch(callSigns: callSigns)
        processed = results.values.filter { $0 > 0 }.count
      }
      let elapsed = ContinuousClock.now - start

      let milliseconds = elapsed.components.seconds * 1000
        + Int64(elapsed.components.attoseconds / 1_000_000_000_000_000)
      let benchmarkResult = BenchmarkResult(
        dataSet: dataSet,
        method: method,
        resolvedCount: processed,
        totalCount: callSigns.count,
        milliseconds: milliseconds
      )

      await MainActor.run {
        self.latestBenchmarkResults[key] = benchmarkResult
        self.storeBestBenchmarkResult(benchmarkResult)
        self.benchmarkRunning = false
      }
    }
  }

  func clearCache() {
    Task {
      [callLookup] in
      await callLookup.clearLookupCache()
    }
    publishedHitList.removeAll()
  }

  /// Apples-to-apples micro-benchmark of just the unique work each path does.
  ///
  /// - **Parse phase**: builds the legacy shape-pattern dictionary and the
  ///   bitset index in two separate parser runs. Both still parse the XML
  ///   (shared cost), so the delta approximates the unique build cost.
  /// - **Lookup phase**: pre-cleans every callsign **outside** the timed
  ///   window, then times raw candidate finding for both paths over the
  ///   same input list. No `Hit` construction, no `cleanCallSign`.
  func runCoreBenchmark(dataSet: BenchmarkDataSet) {
    benchmarkStatus = nil
    benchmarkRunning = true
    let lookup = callLookup

    Task.detached {
      let callSigns = CallLookup.loadCallSigns(from: dataSet, in: .main)
      guard !callSigns.isEmpty else {
        await MainActor.run {
          self.benchmarkStatus = "\(dataSet.label) not found"
          self.benchmarkRunning = false
        }
        return
      }

      // Hoist cleaning out of the timed window.
      let cleaned: [String] = callSigns.compactMap(lookup.preCleanCallSign)

      // Index build timings — separate parser runs per mode.
      let legacyParseStart = ContinuousClock.now
      _ = PrefixFileParser.parse(mode: .legacyOnly)
      let legacyParseElapsed = ContinuousClock.now - legacyParseStart

      let bitsetParseStart = ContinuousClock.now
      _ = PrefixFileParser.parse(mode: .bitsetOnly)
      let bitsetParseElapsed = ContinuousClock.now - bitsetParseStart

      // Lookup timings — same input, serial loop, sink to defeat dead-store.
      var legacyResolved = 0
      let legacyLookupStart = ContinuousClock.now
      for call in cleaned {
        if !lookup.legacyCandidatesRaw(forCleaned: call).isEmpty {
          legacyResolved &+= 1
        }
      }
      let legacyLookupElapsed = ContinuousClock.now - legacyLookupStart

      var bitsetResolved = 0
      let bitsetLookupStart = ContinuousClock.now
      for call in cleaned {
        if !lookup.bitsetCandidatesRaw(forCleaned: call).isEmpty {
          bitsetResolved &+= 1
        }
      }
      let bitsetLookupElapsed = ContinuousClock.now - bitsetLookupStart

      let result = CoreBenchmarkResult(
        dataSetRawValue: dataSet.rawValue,
        dataSetLabel: dataSet.label,
        callCount: cleaned.count,
        legacyResolved: legacyResolved,
        bitsetResolved: bitsetResolved,
        legacyParseMicros: legacyParseElapsed.microseconds,
        bitsetParseMicros: bitsetParseElapsed.microseconds,
        legacyLookupNanos: legacyLookupElapsed.nanoseconds,
        bitsetLookupNanos: bitsetLookupElapsed.nanoseconds
      )

      await MainActor.run {
        self.latestCoreBenchmark[dataSet] = result
        self.persistCoreBenchmarkResults()
        self.benchmarkRunning = false
      }
    }
  }

  /// Runs the built-in sample callsign list through both the legacy and
  /// bitset lookup paths (parser-only, no cache, no QRZ) and stores the
  /// rows whose DXCC entity sets disagree.
  ///
  /// Saves and restores the current ``useBitsetLookup`` flag so the UI
  /// toggle ends up where it started.
  func runComparison() {
    guard !comparisonRunning else { return }
    comparisonRunning = true
    comparisonSummary = nil
    lookupComparisons = []
    let savedToggle = useBitsetLookup
    let calls = callSigns
    let lookup = callLookup

    Task.detached {
      // Legacy pass — toggle directly on the CallLookup (its OSAllocatedUnfairLock
      // makes this safe from any thread). Use parseBatch so the hit cache is bypassed.
      lookup.useBitsetLookup = false
      let legacy = await lookup.parseBatch(callSigns: calls)

      // Bitset pass over the same calls.
      lookup.useBitsetLookup = true
      let bitset = await lookup.parseBatch(callSigns: calls)

      // Restore the user-visible mode.
      lookup.useBitsetLookup = savedToggle

      // Diff. We dedupe by callsign because the sample list contains some
      // duplicates (e.g. AM70URE/8, TX4YKP/R appear twice).
      var seen = Set<String>()
      var allCount = 0
      var differing: [LookupComparison] = []
      for call in calls where seen.insert(call).inserted {
        allCount += 1
        let comparison = LookupComparison.from(
          call: call,
          legacyHits: legacy[call] ?? [],
          bitsetHits: bitset[call] ?? []
        )
        if comparison.differs {
          differing.append(comparison)
        }
      }

      let summary = differing.isEmpty
        ? "All \(allCount) calls match"
        : "\(differing.count) of \(allCount) calls differ"

      await MainActor.run {
        self.lookupComparisons = differing
        self.comparisonSummary = summary
        // Keep the published toggle in sync with the restored lookup state.
        if self.useBitsetLookup != savedToggle {
          self.useBitsetLookup = savedToggle
        }
        self.comparisonRunning = false
      }
    }
  }

  private func persistCoreBenchmarkResults() {
    do {
      let data = try JSONEncoder().encode(Array(latestCoreBenchmark.values))
      UserDefaults.standard.set(data, forKey: Self.coreBenchmarkStorageKey)
    } catch {
      benchmarkStatus = "Could not save core benchmark results"
    }
  }

  private static func loadCoreBenchmarkResults() -> [BenchmarkDataSet: CoreBenchmarkResult] {
    guard let data = UserDefaults.standard.data(forKey: coreBenchmarkStorageKey) else {
      return [:]
    }
    do {
      let results = try JSONDecoder().decode([CoreBenchmarkResult].self, from: data)
      return results.reduce(into: [:]) { partial, result in
        guard let dataSet = result.dataSet else { return }
        partial[dataSet] = result
      }
    } catch {
      return [:]
    }
  }

  private func storeBestBenchmarkResult(_ result: BenchmarkResult) {
    guard let key = result.key else { return }
    if let existingResult = bestBenchmarkResults[key], !result.isFaster(than: existingResult) {
      return
    }

    bestBenchmarkResults[key] = result
    persistBestBenchmarkResults()
  }

  private func persistBestBenchmarkResults() {
    do {
      let data = try JSONEncoder().encode(Array(bestBenchmarkResults.values))
      UserDefaults.standard.set(data, forKey: Self.benchmarkResultsStorageKey)
    } catch {
      benchmarkStatus = "Could not save benchmark results"
    }
  }

  /// Runs both legacy and bitset paths against the selected dataset and
  /// produces a CSV exception report of every call where the two disagree
  /// on the resolved DXCC entity set. Uses the synchronous parse pipeline
  /// (no cache, no QRZ) so the comparison is over local parser output only.
  func runExceptionReport(dataSet: BenchmarkDataSet) {
    guard !exceptionReportRunning else { return }
    exceptionReportRunning = true
    exceptionReport = nil
    exceptionReportStatus = nil
    let savedToggle = useBitsetLookup
    let lookup = callLookup

    Task.detached {
      let callSigns = CallLookup.loadCallSigns(from: dataSet, in: .main)
      guard !callSigns.isEmpty else {
        await MainActor.run {
          self.exceptionReportStatus = "\(dataSet.label) not found"
          self.exceptionReportRunning = false
        }
        return
      }

      lookup.useBitsetLookup = false
      let legacy = await lookup.parseBatch(callSigns: callSigns)
      lookup.useBitsetLookup = true
      let bitset = await lookup.parseBatch(callSigns: callSigns)
      lookup.useBitsetLookup = savedToggle

      // Walk the original input so duplicates are reported once, in order.
      var seen = Set<String>()
      var lines: [String] = ["Call,Legacy,Bitset"]
      var diffCount = 0
      for call in callSigns where seen.insert(call).inserted {
        let legacyHits = legacy[call] ?? []
        let bitsetHits = bitset[call] ?? []
        let legacySet = Set(legacyHits.map { $0.dxcc_entity })
        let bitsetSet = Set(bitsetHits.map { $0.dxcc_entity })
        if legacySet == bitsetSet { continue }
        diffCount += 1
        lines.append("\(call),\(Self.formatHits(legacyHits)),\(Self.formatHits(bitsetHits))")
      }

      let report = lines.joined(separator: "\n")
      let summary = diffCount == 0
        ? "All \(seen.count) calls match"
        : "\(diffCount) of \(seen.count) calls differ"

      await MainActor.run {
        self.exceptionReport = report
        self.exceptionReportStatus = summary
        if self.useBitsetLookup != savedToggle {
          self.useBitsetLookup = savedToggle
        }
        self.exceptionReportRunning = false
      }
    }
  }

  /// Format hits as `"id:Country"` pairs (sorted by DXCC, pipe-separated)
  /// for CSV output, or empty when the path returned no hits. Commas in
  /// country names are stripped so the CSV stays single-column-per-cell.
  nonisolated private static func formatHits(_ hits: [Hit]) -> String {
    guard !hits.isEmpty else { return "" }
    var seen = Set<Int>()
    let unique = hits.filter { seen.insert($0.dxcc_entity).inserted }
    return unique
      .sorted { $0.dxcc_entity < $1.dxcc_entity }
      .map { "\($0.dxcc_entity):\($0.country.replacing(",", with: ""))" }
      .joined(separator: "|")
  }

  /// Clears all cached benchmark results (best, latest, previous, and core)
  /// from memory and UserDefaults. Used to discard stale numbers after a
  /// bitset/legacy code change invalidates them.
  func resetBenchmarkResults() {
    bestBenchmarkResults.removeAll()
    latestBenchmarkResults.removeAll()
    previousBenchmarkResults.removeAll()
    latestCoreBenchmark.removeAll()
    UserDefaults.standard.removeObject(forKey: Self.benchmarkResultsStorageKey)
    UserDefaults.standard.removeObject(forKey: Self.coreBenchmarkStorageKey)
    benchmarkStatus = "Benchmark results cleared"
  }

  private static func loadBestBenchmarkResults() -> [BenchmarkResultKey: BenchmarkResult] {
    guard let data = UserDefaults.standard.data(forKey: benchmarkResultsStorageKey) else {
      return [:]
    }

    do {
      let results = try JSONDecoder().decode([BenchmarkResult].self, from: data)
      return results.reduce(into: [BenchmarkResultKey: BenchmarkResult]()) { partialResult, result in
        guard let key = result.key else { return }
        partialResult[key] = result
      }
    } catch {
      return [:]
    }
  }

  // --------------------------------------------------------------------------

  func logonToQRZ(userId: String, password: String) async {
    qrzLogonStatus = .inProgress
    do {
      let succeeded = try await callLookup.logonToQrz(
        userId: userId,
        password: password
      )
      qrzLogonStatus = succeeded
        ? .success("Logged on as \(userId)")
        : .failure("QRZ refused the connection — try again in a minute")
    } catch {
      qrzLogonStatus = .failure(Self.userFacingMessage(for: error))
    }
  }

  /// Clears the local QRZ session and resets the status indicator.
  func logoffFromQRZ() async {
    await callLookup.logoffFromQrz()
    qrzLogonStatus = .idle
  }

  /// Maps a logon error into a short, user-facing string.
  private static func userFacingMessage(for error: Error) -> String {
    guard let qrzError = error as? QRZManagerError else {
      return error.localizedDescription
    }
    switch qrzError {
    case .invalidCredentials:    return "Username or password incorrect"
    case .requestTooFrequent:    return "Too many requests — wait 60 seconds and retry"
    case .lockout:               return "QRZ is refusing connections from this client"
    case .sessionTimeout:        return "Session timed out"
    case .notFound:              return "QRZ user not found"
    case .sessionKeyAvailable:   return "Already logged on"
    case .unknown:               return "Logon failed (unknown error)"
    }
  }

  private let callSigns = [
    "w6op", "wa6yul", "TX9", "TX4YKP/R", "/KH0PR", "W6OP/4", "OEM3SGU/3", "AM70URE/8", "5N31/OK3CLA", "BV100", "BY1PK/VE6LB", "VE6LB/BY1PK", "DC3RJ/P/W3", "RAEM", "AJ3M/BY1RX", "4D71/N0NM", "OEM3SGU",
    "AM70URE/8",
                         "PU2Z",
                         "IG0NFQ",
                         "IG0NFU",
                         "W6OP",
                         "TJ/W6OP",
                         "W6OP/3B7",
                         "KL6OP",
                         "YA6AA",
                         "3Y2/W6OP",
                         "W6OP/VA6",
                         "VA6AY",
                         "CE7AA",
                         "3G0DA",
                         "FK6DA",
                         "BA6V",
                         "5J7AA",
                         "TX4YKP/R",
                         "TX4YKP/B",
                         "TX4YKP",
                         "TX5YKP",
                         "TX6YKP",
                         "TX7YKP",
                         "TX8YKP",
                         "KG4AA",
                         "KG4AAA",
                         "BS4BAY/P",
                         "CT8AA",
                         "BU7JP",
                         "BU7JP/P",
                         "VE0AAA",
                         "VE3NEA",
                         "VK9O",
                         "VK9OZ",
                         "VK9OC",
                         "VK0M/MB5KET",
                         "VK0H/MB5KET",
                         "WK0B",
                         "VP2V/MB5KET",
                         "VP2M/MB5KET",
                         "VK9X/W6OP",
                         "VK9/W6OP",
                         "VK9/W6OA",
                         "VK9/W6OB",
                         "VK9/W6OC",
                         "VK9/W6OD",
                         "VK9/W6OE",
                         "VK9/W6OF",
                         "RA9BW",
                         "RA9BW/3",
                         "LR9B/22QIR",
                         "6KDJ/UW5XMY",
                         "WP5QOV/P",
                         "WC23/BY7FW",
                         // bad calls
                         "NJY8/QV3ZBY",
                         "QZ5U/IG0NFQ",
                         "Z42OIO"]
} // end class
private extension Duration {
  /// Total elapsed time in microseconds (truncated).
  var microseconds: Int64 {
    components.seconds * 1_000_000
      + Int64(components.attoseconds / 1_000_000_000_000)
  }

  /// Total elapsed time in nanoseconds (truncated).
  var nanoseconds: Int64 {
    components.seconds * 1_000_000_000
      + Int64(components.attoseconds / 1_000_000_000)
  }
}

