//
//  InlineAttachmentTextView+AppKit.swift
//  RichText
//
//  Created by Yanan Li on 2026/6/20.
//

#if canImport(AppKit)

import AppKit

extension InlineAttachmentTextView {
    
    var textContainerOffset: CGPoint {
        textContainerOrigin
    }
    
    override func layout() {
        super.layout()
        if let cachedContentHeightWidth,
           cachedContentHeightWidth != bounds.width {
            cachedContentHeight = nil
            invalidateIntrinsicContentSize()
        }
        updateInlineAttachmentViews()
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: PlatformView.noIntrinsicMetric, height: _measuredContentHeight)
    }
    
    private var _measuredContentHeight: CGFloat {
        if let cachedContentHeight,
           cachedContentHeightWidth == bounds.width {
            return cachedContentHeight
        }
        
        if let textLayoutManager {
            textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
            
            var maximumY: CGFloat = 0
            textLayoutManager.enumerateTextSegments(
                in: textLayoutManager.documentRange,
                type: .standard,
                options: [.rangeNotRequired]
            ) { _, segmentFrame, _, _ in
                maximumY = max(maximumY, segmentFrame.maxY)
                return true
            }
            
            let measuredContentHeight = ceil(maximumY + textContainerOffset.y)
            cachedContentHeight = measuredContentHeight
            cachedContentHeightWidth = bounds.width
            return measuredContentHeight
        }
        
        if let layoutManager = _layoutManager,
           let textContainer = _textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let measuredContentHeight = ceil(
                layoutManager.usedRect(for: textContainer).maxY
                + textContainerOffset.y
            )
            cachedContentHeight = measuredContentHeight
            cachedContentHeightWidth = bounds.width
            return measuredContentHeight
        }
        
        return bounds.height
    }
    
    /// AppKit tracks the selection inside `mouseDown`, so a click is known
    /// once it returns: one click that selected nothing, off links and inline
    /// views, and not followed by a second that makes it a double click.
    override func mouseDown(with event: NSEvent) {
        pendingClick?.cancel()
        pendingClick = nil
        super.mouseDown(with: event)

        guard let onClick,
              event.clickCount == 1,
              selectedRange().length == 0,
              let window else { return }

        let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
        let character = characterIndex(for: screenPoint)
        if character != NSNotFound, character < attributedString().length,
           NSAttributedString.Key.ownsTaps(attributedString().attributes(at: character, effectiveRange: nil)) {
            return
        }

        let offset = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        pendingClick = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(NSEvent.doubleClickInterval))
            guard !Task.isCancelled, let self, self.selectedRange().length == 0 else { return }
            onClick(offset)
        }
    }

    // FIXME: This only works for "Copy" and "Search with Google".
    // Lookup, Translate, Share are using original strings
    override func attributedSubstring(
        forProposedRange range: NSRange,
        actualRange: NSRangePointer?
    ) -> NSAttributedString? {
        guard let original = super.attributedSubstring(
            forProposedRange: range,
            actualRange: actualRange
        ) else { return nil }

        return replaceAttachmentWithEquivalentText(
            in: original
        )
    }
    
}

#endif
