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
  @Published var latestBenchmarkResults: [BenchmarkDataSet: BenchmarkResult] = [:]
  @Published var previousBenchmarkResults: [BenchmarkDataSet: BenchmarkResult] = [:]
  @Published var bestBenchmarkResults: [BenchmarkDataSet: BenchmarkResult] = [:]
  @Published var benchmarkStatus: String?
  @Published var benchmarkRunning = false
  @Published var qrzLogonStatus: QRZLogonStatus = .idle

  // Call Parser
  let callLookup: CallLookup

  private static let benchmarkResultsStorageKey = "benchmarkResults.best"

  init(loggingLevel: Bool) {
    callLookup = CallLookup(
      parsedData: PrefixFileParser.parse(),
      verboseLogging: loggingLevel
    )
    bestBenchmarkResults = Self.loadBestBenchmarkResults()
  }

  /// Lookup a single call.
  func lookupSingleCall(call: String) {
    Task { [callLookup] in
      publishedHitList = await callLookup.lookupCall(callSign: call)
    }
  }

  /// Look up a pair of call signs in parallel.
  func lookupCallPair(spotter: String, dx: String) {
    Task { [callLookup] in
      let hitPair = await callLookup.lookupCallPairGrouped(
        spotter: spotter,
        dx: dx
      )
      updatePublishedHitList(hits: hitPair.spotter + hitPair.dx)
    }
  }

  @MainActor func updatePublishedHitList(hits: [Hit]) {
    publishedHitList = hits
  }

  func downloadBigCTY() {
    Task { [callLookup] in
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
    Task { [callLookup] in
      let results = await callLookup.lookupBatch(callSigns: callSigns)
      updatePublishedHitList(hits: results.values.flatMap { $0 })
    }
  }

  /// Benchmarks a data set and persists the result when it beats the
  /// stored best for that data set.
  func runBenchmark(dataSet: BenchmarkDataSet) {
    previousBenchmarkResults[dataSet] = bestBenchmarkResults[dataSet]
    latestBenchmarkResults.removeValue(forKey: dataSet)
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

      let start = ContinuousClock.now
      let results = await lookup.candidatesBatch(callSigns: callSigns)
      let processed = results.values.filter { $0 > 0 }.count
      let elapsed = ContinuousClock.now - start

      let milliseconds = elapsed.components.seconds * 1000
        + Int64(elapsed.components.attoseconds / 1_000_000_000_000_000)
      let benchmarkResult = BenchmarkResult(
        dataSet: dataSet,
        resolvedCount: processed,
        totalCount: callSigns.count,
        milliseconds: milliseconds
      )

      await MainActor.run {
        self.latestBenchmarkResults[dataSet] = benchmarkResult
        self.storeBestBenchmarkResult(benchmarkResult)
        self.benchmarkRunning = false
      }
    }
  }

  func clearCache() {
    Task { [callLookup] in
      await callLookup.clearLookupCache()
    }
    publishedHitList.removeAll()
  }

  /// Clears all cached benchmark results.
  func resetBenchmarkResults() {
    bestBenchmarkResults.removeAll()
    latestBenchmarkResults.removeAll()
    previousBenchmarkResults.removeAll()
    UserDefaults.standard.removeObject(forKey: Self.benchmarkResultsStorageKey)
    benchmarkStatus = "Benchmark results cleared"
  }

  private func storeBestBenchmarkResult(_ result: BenchmarkResult) {
    guard let dataSet = result.dataSet else { return }
    if let existingResult = bestBenchmarkResults[dataSet], !result.isFaster(than: existingResult) {
      return
    }
    bestBenchmarkResults[dataSet] = result
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

  private static func loadBestBenchmarkResults() -> [BenchmarkDataSet: BenchmarkResult] {
    guard let data = UserDefaults.standard.data(forKey: benchmarkResultsStorageKey) else {
      return [:]
    }
    do {
      let results = try JSONDecoder().decode([BenchmarkResult].self, from: data)
      return results.reduce(into: [BenchmarkDataSet: BenchmarkResult]()) { partial, result in
        guard let dataSet = result.dataSet else { return }
        partial[dataSet] = result
      }
    } catch {
      return [:]
    }
  }

  // MARK: - QRZ

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

  func logoffFromQRZ() async {
    await callLookup.logoffFromQrz()
    qrzLogonStatus = .idle
  }

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
    "w6op", "wa6yul", "TX9", "TX4YKP/R", "/KH0PR", "W6OP/4", "OEM3SGU/3",
    "AM70URE/8", "5N31/OK3CLA", "BV100", "BY1PK/VE6LB", "VE6LB/BY1PK",
    "DC3RJ/P/W3", "RAEM", "AJ3M/BY1RX", "4D71/N0NM", "OEM3SGU",
    "AM70URE/8", "PU2Z", "IG0NFQ", "IG0NFU", "W6OP", "TJ/W6OP", "W6OP/3B7",
    "KL6OP", "YA6AA", "3Y2/W6OP", "W6OP/VA6", "VA6AY", "CE7AA", "3G0DA",
    "FK6DA", "BA6V", "5J7AA", "TX4YKP/R", "TX4YKP/B", "TX4YKP", "TX5YKP",
    "TX6YKP", "TX7YKP", "TX8YKP", "KG4AA", "KG4AAA", "BS4BAY/P", "CT8AA",
    "BU7JP", "BU7JP/P", "VE0AAA", "VE3NEA", "VK9O", "VK9OZ", "VK9OC",
    "VK0M/MB5KET", "VK0H/MB5KET", "WK0B", "VP2V/MB5KET", "VP2M/MB5KET",
    "VK9X/W6OP", "VK9/W6OP", "VK9/W6OA", "VK9/W6OB", "VK9/W6OC", "VK9/W6OD",
    "VK9/W6OE", "VK9/W6OF", "RA9BW", "RA9BW/3", "LR9B/22QIR", "6KDJ/UW5XMY",
    "WP5QOV/P", "WC23/BY7FW",
    // bad calls
    "NJY8/QV3ZBY", "QZ5U/IG0NFQ", "Z42OIO"
  ]
}
