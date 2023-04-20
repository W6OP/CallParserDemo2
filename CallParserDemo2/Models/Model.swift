//
//  Model.swift
//  CallParserDemo2
//
//  Created by Peter Bourget on 4/18/23.
//

import Foundation
import CallParser

class Model: ObservableObject {

  @Published var publishedHitList = [Hit]()

  // Call Parser
  let callParser = PrefixFileParser()
  var callLookup: CallLookup

  init() {
    // initialize the Call Parser
    callLookup = CallLookup(prefixFileParser: callParser)
  }

  // MARK: NEW STUFF --------------------------------------------------------------------------


  /// Lookup a single call using a continuation.
  /// - Parameter call: String:
  func lookupSingleCall(call: String)  {
    Task {
      @MainActor in
      publishedHitList = await callLookup.lookupCall(callSign: call)
    }
  }

  /// Look up a pair of call signs using a continuation.
  /// - Parameters:
  ///   - spotter: String:
  ///   - dx: String:
  func lookupCallPair(spotter: String, dx: String) {
      Task {
        @MainActor in
          //self.publishedHitList = await callLookup.lookupCall(spotter: spotter, dx: dx)
        async let spotter = await callLookup.lookupCall(callSign: spotter)
        async let dxStation = await callLookup.lookupCall(callSign: dx)
        //await publishedHitList.append(contentsOf: spotter + dxStation)

        await publishedHitList = [spotter[0], dxStation[0]]
        }
  }

//  func lookupCallPair(spotter: (call: String, sequence: Int), dx: (call: String, sequence: Int)) {
//      Task {
//        @MainActor in
//        let spotId = 34
//        //self.publishedHitList = await callLookup.lookupCallPair(spotter: (spotter.call, spotter.sequence, spotId: spotId), dx:  (dx.call, dx.sequence, spotId: spotId))
//        self.publishedHitList = await callLookup.lookupCallPair(spotter: spotter.call, dx: dx.call)
//      }
//  }

  func clearCache() {
    callLookup.clearCache()
    publishedHitList.removeAll()
  }

  // --------------------------------------------------------------------------

  func logonToQRZ(userId: String, password: String) {

    Task {
      do {
        let _ = try await callLookup.logonToQrz(userId: userId, password: password)
      } catch {
        print("logon error: \(error)")
      }
    }
    /*
     2023-01-21 08:11:16.613897-0800 CallParser Demo[5871:451190] [QRZManager] Request Session Key.
     session key request failed: ["Remark": "cpu: 0.060s", "Error": "Username/password incorrect ", "GMTime": "Sat Jan 21 16:11:17 2023"]
     getSessionKey failed: The operation couldn’t be completed. (CallParser.QRZManagerError error 2.)
     logon error: The operation couldn’t be completed. (CallParser.QRZManagerError error 2.)
     */
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
