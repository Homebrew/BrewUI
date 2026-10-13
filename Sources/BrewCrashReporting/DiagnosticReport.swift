//
//  DiagnosticReport.swift
//  Brew
//

import Foundation

/// The parts of a macOS crash report (`~/Library/Logs/DiagnosticReports/Homebrew-*.ips`)
/// worth showing in a GitHub issue.
public struct DiagnosticReport: Sendable, Equatable {
    public struct Frame: Sendable, Equatable {
        public let imageName: String
        public let imageOffset: Int
        public let symbol: String?
        public let symbolOffset: Int?
        public let sourceFile: String?
        public let sourceLine: Int?
    }

    public let bundleIdentifier: String
    public let capturedAt: Date
    public let appVersion: String
    public let buildNumber: String
    public let osVersion: String
    public let exceptionSummary: String
    public let terminationReason: String?
    public let applicationSpecificInformation: [String]
    public let lastExceptionBacktrace: [Frame]
    public let crashedThreadLabel: String
    public let crashedThreadFrames: [Frame]
}

public enum DiagnosticReportParsingError: Error, Equatable {
    case missingHeader
    case missingFaultingThread
}

public enum DiagnosticReportParser {
    /// A report is a one-line JSON header followed by a pretty-printed JSON body.
    public static func parse(_ data: Data) throws -> DiagnosticReport {
        guard let newline = data.firstIndex(of: UInt8(ascii: "\n")) else {
            throw DiagnosticReportParsingError.missingHeader
        }
        let decoder = JSONDecoder()
        let header = try decoder.decode(IPSHeader.self, from: data[..<newline])
        let body = try decoder.decode(IPSBody.self, from: data[data.index(after: newline)...])

        let threadIndex = body.threads.firstIndex { $0.triggered == true } ?? body.faultingThread
        guard let threadIndex, body.threads.indices.contains(threadIndex) else {
            throw DiagnosticReportParsingError.missingFaultingThread
        }
        let thread = body.threads[threadIndex]

        let resolve = { (frames: [IPSFrame]) in
            frames.map { $0.resolved(against: body.usedImages) }
        }
        return DiagnosticReport(
            bundleIdentifier: body.bundleInfo?.bundleIdentifier ?? header.bundleID,
            capturedAt: body.captureTime.flatMap(ipsDateFormatter.date(from:))
                ?? header.date ?? .distantPast,
            appVersion: body.bundleInfo?.shortVersion ?? header.appVersion,
            buildNumber: body.bundleInfo?.version ?? header.buildVersion,
            osVersion: body.osVersion.map { "\($0.train) (\($0.build))" } ?? header.osVersion,
            exceptionSummary: body.exception?.summary ?? "Unknown exception",
            terminationReason: body.termination?.indicator,
            applicationSpecificInformation: body.asi?.values.flatMap(\.self) ?? [],
            lastExceptionBacktrace: resolve(body.lastExceptionBacktrace ?? []),
            crashedThreadLabel: thread.label(index: threadIndex),
            crashedThreadFrames: resolve(thread.frames),
        )
    }
}

// MARK: - The .ips schema

private let ipsDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS Z"
    return formatter
}()

private struct IPSHeader: Decodable {
    let bundleID: String
    let appVersion: String
    let buildVersion: String
    let osVersion: String
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case bundleID
        case appVersion = "app_version"
        case buildVersion = "build_version"
        case osVersion = "os_version"
        case timestamp
    }

    var date: Date? {
        ipsDateFormatter.date(from: timestamp)
    }
}

private struct IPSBody: Decodable {
    let bundleInfo: IPSBundleInfo?
    let osVersion: IPSOSVersion?
    let captureTime: String?
    let exception: IPSException?
    let termination: IPSTermination?
    let asi: [String: [String]]?
    let faultingThread: Int?
    let lastExceptionBacktrace: [IPSFrame]?
    let threads: [IPSThread]
    let usedImages: [IPSImage]
}

private struct IPSBundleInfo: Decodable {
    let bundleIdentifier: String?
    let shortVersion: String?
    let version: String?

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier = "CFBundleIdentifier"
        case shortVersion = "CFBundleShortVersionString"
        case version = "CFBundleVersion"
    }
}

private struct IPSOSVersion: Decodable {
    let train: String
    let build: String
}

private struct IPSException: Decodable {
    let type: String?
    let signal: String?
    let subtype: String?
    let message: String?

    var summary: String {
        var parts: [String] = []
        if let type {
            parts.append(signal.map { "\(type) (\($0))" } ?? type)
        }
        if let subtype {
            parts.append(subtype)
        }
        if let message {
            parts.append(message)
        }
        return parts.isEmpty ? "Unknown exception" : parts.joined(separator: " – ")
    }
}

private struct IPSTermination: Decodable {
    let indicator: String?
}

private struct IPSImage: Decodable {
    let name: String?
    let path: String?
}

private struct IPSFrame: Decodable {
    let imageIndex: Int
    let imageOffset: Int
    let symbol: String?
    let symbolLocation: Int?
    let sourceFile: String?
    let sourceLine: Int?

    func resolved(against images: [IPSImage]) -> DiagnosticReport.Frame {
        let image = images.indices.contains(imageIndex) ? images[imageIndex] : nil
        let name = image?.name
            ?? image?.path.map { URL(fileURLWithPath: $0).lastPathComponent }
            ?? "???"
        return DiagnosticReport.Frame(
            imageName: name,
            imageOffset: imageOffset,
            symbol: symbol,
            symbolOffset: symbolLocation,
            // ReportCrash writes `/<compiler-generated>` for thunks.
            sourceFile: sourceFile.flatMap { $0.hasPrefix("/<") ? nil : $0 },
            sourceLine: sourceLine,
        )
    }
}

private struct IPSThread: Decodable {
    let name: String?
    let queue: String?
    let triggered: Bool?
    let frames: [IPSFrame]

    func label(index: Int) -> String {
        let detail = [name, queue].compactMap(\.self).joined(separator: ", ")
        return detail.isEmpty ? "Thread \(index)" : "Thread \(index) (\(detail))"
    }
}
