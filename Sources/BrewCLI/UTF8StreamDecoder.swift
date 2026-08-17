//
//  UTF8StreamDecoder.swift
//  BrewCLI
//

import Foundation

/// Decodes a byte stream that arrives in arbitrary chunks.
///
/// Reads land on byte boundaries the writer never chose, so a multi-byte character can be split across
/// two of them. Only a genuinely *incomplete* trailing sequence is held back — at most three bytes.
/// Everything else is decoded eagerly, with U+FFFD substituted for bytes that cannot be decoded, so a
/// malformed byte costs one character rather than stalling the stream behind it.
enum UTF8StreamDecoder {
    /// Consumes and returns everything in `buffer` that is decodable now, leaving behind only a trailing
    /// sequence still waiting for its continuation bytes.
    static func takeDecodablePrefix(_ buffer: inout Data) -> String {
        let ready = buffer.prefix(buffer.count - incompleteTrailingSequenceLength(buffer))
        guard !ready.isEmpty else {
            return ""
        }
        buffer = Data(buffer.dropFirst(ready.count))
        return lossyString(ready)
    }

    /// Decodes bytes with U+FFFD substituted for anything invalid.
    ///
    /// `optional_data_string_conversion` prefers the failable initialiser, and rightly so for data that
    /// is *supposed* to be valid, where returning nil surfaces corruption instead of hiding it. Command
    /// output is not that: it is whatever the child happened to write, and nil there discards a whole
    /// run's output — or a whole line of it — over one stray byte from a mangled locale or a filename
    /// that was never UTF-8. Losing that byte is the smaller failure, and the only one a user can act on.
    static func lossyString(_ bytes: some Collection<UInt8>) -> String {
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: bytes, as: UTF8.self)
    }

    /// The length of a trailing sequence whose continuation bytes have not arrived yet, or zero.
    ///
    /// A sequence is at most four bytes, so only the last three can be incomplete. Walks back over
    /// continuation bytes to the lead byte and compares what it promises against what is present. A byte
    /// that cannot start a sequence is never held back: waiting on it would stall the stream forever.
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

    /// One for anything that cannot lead a multi-byte sequence, including the always-invalid `0xC0`,
    /// `0xC1` and `0xF5...0xFF`, so such a byte is passed through to become U+FFFD rather than held back.
    private static func expectedSequenceLength(leadByte: UInt8) -> Int {
        switch leadByte {
        case 0xC2 ... 0xDF: 2
        case 0xE0 ... 0xEF: 3
        case 0xF0 ... 0xF4: 4
        default: 1
        }
    }
}
