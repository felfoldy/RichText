//
//  TextTapModifier.swift
//  RichText
//

import SwiftUI

extension EnvironmentValues {
    @Entry var textTapAction: (@MainActor (AttributedString, AttributedString.Index) -> Void)?
}

extension View {
    /// Reports where a `TextView` was tapped, as a position in the text it was
    /// given: the insertion point nearest the tap. Taps on links and inline
    /// views are left to them and not reported.
    public func onTextTap(
        perform action: @escaping @MainActor (AttributedString, AttributedString.Index) -> Void
    ) -> some View {
        environment(\.textTapAction, action)
    }
}

extension AttributedString {
    /// The position `utf16Offset` UTF-16 units in, as the text view counts,
    /// rounded down to a character boundary.
    func characterIndex(atUTF16Offset utf16Offset: Int) -> AttributedString.Index {
        let string = String(characters)
        let utf16 = string.utf16
        var index = utf16.index(utf16.startIndex, offsetBy: min(max(utf16Offset, 0), utf16.count))
        while index > string.startIndex, index.samePosition(in: string) == nil {
            index = utf16.index(before: index)
        }
        return characters.index(startIndex, offsetBy: string[..<index].count)
    }
}

extension NSAttributedString.Key {
    /// Marks a run whose taps belong to something else: a link or an inline view.
    static func ownsTaps(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        attributes[.link] != nil
            || attributes[.attachment] != nil
            || attributes[.inlineHostingAttachment] != nil
    }
}
