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
  @State private var callSign = ""
  @AppStorage("username") var userId: String = ""
  @AppStorage("password") var password: String = ""
  @State var prefixDataList = [Hit]()

  var body: some View {
    VStack{
      HStack{
        TextField("QRZ Logon", text: $userId)
          .frame(maxWidth: 75)
        TextField("Password", text: $password)
          .frame(maxWidth: 225)
        Button(action: {
          model.logonToQRZ(userId: userId, password: password)
        }) {
          Text("Logon")
        }
        Spacer()
      }
      HStack{
        TextField("Enter Call Sign", text: $callSign)
          .frame(maxWidth: 100)
        Button(action: {model.lookupSingleCall(call: self.callSign);
        }) {
          Text("Lookup")
        }
        Spacer()
      }
      HStack {
        Button(action: { model.lookupCallPair(spotter: "TX4YKP", dx: "OA5TY")
        }) {
          Text("Lookup Pair Async Let")
        }
        Spacer()
      }
      HStack {
        //Button(action: { model.lookupCallPair(spotter: ("W6OP", 4), dx: ("C5C", 5))
        Button(action: { model.lookupCallPair(spotter: ("W6OP"), dx: ("C5C"))
        }) {
          Text("Lookup Pair xCluster")
        }
        Spacer()
      }
      HStack {
        Button(action: {model.clearCache()}) {
          Text("Clear cache")
        }
        Spacer()
      }
      HStack {
        PrefixDataRow(prefixDataList: prefixDataList)
      }
    }
    .frame(minWidth: 800)
    .padding()
  }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        .environmentObject(Model())
    }
}

struct PrefixDataRow: View {
  @EnvironmentObject var model: Model
  @State public var prefixDataList: [Hit]

    var body: some View {

      ScrollView {
      VStack {
       ForEach(model.publishedHitList, id: \.self) { hit in
          HStack {
            Text(hit.call)
            .frame(minWidth: 90, alignment: .leading)
            .padding()
            Divider()

            Text(hit.kind.rawValue)
              .frame(minWidth: 65, alignment: .leading)
            .padding()
             Divider()

            Text(hit.country)
              .frame(minWidth: 150, maxWidth: 150, alignment: .leading)
            .padding()
             Divider()

            Text(hit.province)
                .frame(minWidth: 150, maxWidth: 150, alignment: .leading)
                .padding()
                Divider()

            Text(String(hit.dxcc_entity))
              .frame(minWidth: 55, maxWidth: 55, alignment: .leading)
            .padding()

          }.frame(maxHeight: 10)
        }//.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 500)
      }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 500, maxHeight: 500, alignment: .topLeading)
    }
  }
}
