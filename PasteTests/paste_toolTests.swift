//
//  paste_toolTests.swift
//  CopydockTests
//
//  Unit tests for card classification and display helpers.
//

import Testing
import Foundation
@testable import Copydock

struct CardKindTests {

    private func textItem(_ text: String) -> ClipboardItemModel {
        ClipboardItemModel(itemType: .text, plainText: text)
    }

    @Test func httpsURLIsLink() {
        #expect(CardKind(item: textItem("https://pasteapp.io/pricing")) == .link)
    }

    @Test func httpURLIsLink() {
        #expect(CardKind(item: textItem("http://example.com/page?a=1")) == .link)
    }

    @Test func wwwPrefixedHostIsLink() {
        #expect(CardKind(item: textItem("www.example.com")) == .link)
    }

    @Test func sentenceContainingURLIsText() {
        #expect(CardKind(item: textItem("see https://example.com for details")) == .text)
    }

    @Test func multilineURLIsText() {
        #expect(CardKind(item: textItem("https://a.com\nhttps://b.com")) == .text)
    }

    @Test func plainSentenceIsText() {
        #expect(CardKind(item: textItem("remember to buy milk")) == .text)
    }

    @Test func sixDigitNumberIsTextNotColor() {
        // Real Paste keeps plain six-digit codes (verification codes) as text.
        #expect(CardKind(item: textItem("235442")) == .text)
    }

    @Test func hexWithLettersIsColor() {
        #expect(CardKind(item: textItem("#1A2B3C")) == .color)
        #expect(CardKind(item: textItem("1a2b3c")) == .color)
    }

    @Test func shorthandHexIsTextLikePaste() {
        // Paste keeps #FFF as text; only six-digit forms become swatches.
        #expect(CardKind(item: textItem("#FFF")) == .text)
    }

    @Test func imageItemIsImage() {
        let item = ClipboardItemModel(itemType: .image, imageData: Data([0x89, 0x50]))
        #expect(CardKind(item: item) == .image)
    }

    @Test func fileItemIsFile() {
        let item = ClipboardItemModel(itemType: .file, filePaths: ["/tmp/a.txt"])
        #expect(CardKind(item: item) == .file)
    }

    @Test func displayURLStripsSchemeAndTrailingSlash() {
        #expect(CardKind.displayURL("https://pasteapp.io/") == "pasteapp.io")
        #expect(CardKind.displayURL("http://example.com/a?b=c") == "example.com/a?b=c")
    }
}
