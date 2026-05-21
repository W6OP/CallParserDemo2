//
//  ExceptionReportView.swift
//  CallParserDemo2
//
//  Shows the CSV exception report produced by ``Model/runExceptionReport(dataSet:)``,
//  with a Copy button so the user can paste the disagreement list into a document.
//

import SwiftUI
import AppKit

struct ExceptionReportView: View {
    let report: String?
    let status: String?

    @State private var displayedReport = ""

    private var hasReport: Bool {
        !displayedReport.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exception Report")
                .font(.caption.bold())
                .foregroundStyle(Color.mediumBlueText)

            HStack(spacing: 12) {
                if let status {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mediumBlueText)
                }

                Spacer()

                if hasReport {
                    Button("Copy", systemImage: "doc.on.doc") {
                        copyToPasteboard(displayedReport)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }

            if hasReport {
                TextEditor(text: $displayedReport)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.mediumBlueText)
                    .scrollContentBackground(.hidden)
                    .textSelection(.enabled)
                    .frame(maxHeight: 220)
                    .padding(4)
                    .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
            }
        }
        .onAppear {
            displayedReport = report ?? ""
        }
        .onChange(of: report) { _, newValue in
            displayedReport = newValue ?? ""
        }
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
