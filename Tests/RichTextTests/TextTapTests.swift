import Foundation
import Testing
@testable import RichText

struct TextTapTests {
    /// The characters before the index, to compare positions by what precedes them.
    private func prefix(_ text: AttributedString, _ index: AttributedString.Index) -> String {
        String(text.characters[text.startIndex..<index])
    }

    @Test func anOffsetPastAMultiByteCharacterLandsAfterIt() {
        // The thumb is two UTF-16 units.
        let text = AttributedString("a👍b")

        #expect(prefix(text, text.characterIndex(atUTF16Offset: 1)) == "a")
        #expect(prefix(text, text.characterIndex(atUTF16Offset: 3)) == "a👍")
    }

    @Test func anOffsetInsideACharacterRoundsDown() {
        let text = AttributedString("a👍b")

        #expect(prefix(text, text.characterIndex(atUTF16Offset: 2)) == "a")
    }

    @Test func anAttachmentCountsAsOneCharacter() {
        let text = AttributedString("a\u{FFFC}b")

        #expect(prefix(text, text.characterIndex(atUTF16Offset: 2)) == "a\u{FFFC}")
    }

    @Test func offsetsOutOfRangeAreClamped() {
        let text = AttributedString("ab")

        #expect(text.characterIndex(atUTF16Offset: -1) == text.startIndex)
        #expect(text.characterIndex(atUTF16Offset: 9) == text.endIndex)
    }
}
