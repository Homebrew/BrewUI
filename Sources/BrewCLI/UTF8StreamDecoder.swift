//
//  UTF8StreamDecoder.swift
//  BrewCLI
//

import Foundation

/// Decodes a byte stream that arrives in arbitrary chunks, holding back only a split trailing sequence.
enum UTF8StreamDecoder {
    static func takeDecodablePrefix(_ buffer: inout Data) -> String {
        let ready = buffer.prefix(buffer.count - incompleteTrailingSequenceLength(buffer))
        guard !ready.isEmpty else {
            return ""
        }
        buffer = Data(buffer.dropFirst(ready.count))
        return lossyString(ready)
    }

    /// Lossy on purpose: command output is whatever the child wrote, and the failable initialiser the
    /// lint rule prefers would discard a whole run — or a whole line — over one stray byte.
    static func lossyString(_ bytes: some Collection<UInt8>) -> String {
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: bytes, as: UTF8.self)
    }

    /// Walks back over continuation bytes to the lead byte and compares what it promises against what is
    /// present. A byte that cannot lead a sequence is never held back — waiting on it would never end.
    static func incompleteTrailingSequenceLength(_ buffer: Data) -> Int {
        for trailing in 1 ..< 4 where trailing <= buffer.count {
            let byte = buffer[buffer.index(buffer.endIndex, offsetBy: -trailing)]
            if isContinuationByte(byte) {
                continue
            }
            return expectedSequenceLength(leadByte: byte) > trailing ? trailing : 0
        }
        return 0
    }

    private static func isContinuationByte(_ byte: UInt8) -> Bool {
        byte & 0b1100_0000 == 0b1000_0000
    }

    private static func expectedSequenceLength(leadByte: UInt8) -> Int {
        switch leadByte {
        case 0xC2 ... 0xDF: 2
        case 0xE0 ... 0xEF: 3
        case 0xF0 ... 0xF4: 4
        // Includes 0xC0, 0xC1 and 0xF5...0xFF, which can never lead.
        default: 1
        }
    }
}
