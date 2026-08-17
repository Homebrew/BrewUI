//
//  UTF8StreamDecoderTests.swift
//  BrewTests
//

@testable import BrewCLI
import Foundation
import Testing

struct UTF8StreamDecoderTests {
    @Test func `plain ASCII is taken whole`() {
        var buffer = Data("hello".utf8)

        #expect(UTF8StreamDecoder.takeDecodablePrefix(&buffer) == "hello")
        #expect(buffer.isEmpty)
    }

    @Test func `an empty buffer yields nothing`() {
        var buffer = Data()

        #expect(UTF8StreamDecoder.takeDecodablePrefix(&buffer).isEmpty)
    }

    @Test func `a sequence split across reads is held back and then completed`() {
        // "é" is 0xC3 0xA9; the read ended between its two bytes.
        var buffer = Data([0x61, 0xC3])

        #expect(UTF8StreamDecoder.takeDecodablePrefix(&buffer) == "a")
        #expect(buffer == Data([0xC3]))

        buffer.append(0xA9)
        #expect(UTF8StreamDecoder.takeDecodablePrefix(&buffer) == "é")
        #expect(buffer.isEmpty)
    }

    @Test func `a four-byte sequence split at every boundary still reassembles`() {
        // U+1F600, 0xF0 0x9F 0x98 0x80.
        let emoji: [UInt8] = [0xF0, 0x9F, 0x98, 0x80]

        for split in 1 ..< emoji.count {
            var buffer = Data(emoji.prefix(split))
            #expect(UTF8StreamDecoder.takeDecodablePrefix(&buffer).isEmpty)

            buffer.append(contentsOf: emoji.dropFirst(split))
            #expect(UTF8StreamDecoder.takeDecodablePrefix(&buffer) == "😀")
        }
    }

    /// The bug this replaced held back only trailing bytes, so a bad byte anywhere else made the whole
    /// chunk undecodable and cost a *leading* byte per read instead.
    @Test func `an invalid byte mid-buffer costs one character, not the text around it`() {
        var buffer = Data([0x41] + [0xFF] + Array("BC".utf8))

        let text = UTF8StreamDecoder.takeDecodablePrefix(&buffer)

        #expect(text.contains("A") && text.contains("BC"))
        #expect(buffer.isEmpty)
    }

    @Test func `invalid bytes never accumulate, however many arrive`() {
        // The failure mode being guarded: bad bytes arriving faster than they are consumed grew the
        // buffer without bound and stalled every later line behind it.
        var buffer = Data()

        for _ in 0 ..< 100 {
            buffer.append(contentsOf: [0xFF, 0xFE] + Array("ok\n".utf8))
            _ = UTF8StreamDecoder.takeDecodablePrefix(&buffer)
        }

        #expect(buffer.count <= 3)
    }

    @Test func `an always-invalid lead byte is not mistaken for an incomplete sequence`() {
        // 0xC0 and 0xF5 can never start a sequence, so waiting for continuations would stall forever.
        for leadByte in [UInt8(0xC0), UInt8(0xC1), UInt8(0xF5), UInt8(0xFF)] {
            #expect(UTF8StreamDecoder.incompleteTrailingSequenceLength(Data([leadByte])) == 0)
        }
    }

    @Test func `a complete sequence at the end is not held back`() {
        #expect(UTF8StreamDecoder.incompleteTrailingSequenceLength(Data("é".utf8)) == 0)
        #expect(UTF8StreamDecoder.incompleteTrailingSequenceLength(Data("😀".utf8)) == 0)
    }

    @Test func `an incomplete sequence reports the bytes it is holding`() {
        #expect(UTF8StreamDecoder.incompleteTrailingSequenceLength(Data([0xF0])) == 1)
        #expect(UTF8StreamDecoder.incompleteTrailingSequenceLength(Data([0xF0, 0x9F])) == 2)
        #expect(UTF8StreamDecoder.incompleteTrailingSequenceLength(Data([0xF0, 0x9F, 0x98])) == 3)
    }

    @Test func `orphaned continuation bytes are passed through rather than held`() {
        // No lead byte within reach, so holding them back would stall the stream.
        #expect(UTF8StreamDecoder.incompleteTrailingSequenceLength(Data([0x80, 0x80, 0x80])) == 0)
    }
}
