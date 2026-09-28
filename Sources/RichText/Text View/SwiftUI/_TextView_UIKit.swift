//
//  _TextView_UIKit.swift
//  RichText
//
//  Created by Yanan Li on 2025/10/4.
//

#if canImport(UIKit)
import SwiftUI

struct _TextView_UIKit: UIViewRepresentable {
    var content: TextContent
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIView(context: Context) -> InlineAttachmentTextView {
        let textView = InlineAttachmentTextView(
            usingTextLayoutManager: context.environment.usesTextLayoutManager
        )
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textDragDelegate = context.coordinator
        context.coordinator.textView = textView
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        
        textView.textContainer.lineFragmentPadding = .zero
        textView.textContainerInset = .zero
        textView.contentInset = .zero
        
        return textView
    }
    
    func updateUIView(_ textView: InlineAttachmentTextView, context: Context) {
        context.coordinator.parent = self

        let configuration = TextViewRenderConfiguration(context: context)
        TextAttributeConverter.mergeRenderConfigurationIntoTextView(
            textView,
            configuration: configuration
        )
        let attributedString = content.attributedString(configuration: configuration)
        textView.applyAttributedStringPreservingAttachments(attributedString)

        context.coordinator.renderedText = attributedString
        context.coordinator.setTapAction(context.environment.textTapAction)
    }
    
    // For UITextView, it comes with a UIScrollView
    //
    // Since we have override `intrinsticContentSize` and disabled scrolling, it should act like a normal UIView
    //
    // For better control of SwiftUI View size when place it inside a ScrollView, we use `sizeThatFits` to explicitly calculate a size in SwiftUI.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: InlineAttachmentTextView,
        context: Context
    ) -> CGSize? {
        uiView.sizeThatFits(
            proposal.replacingUnspecifiedDimensions(
                by: CGSize(
                    width: UIView.noIntrinsicMetric,
                    height: UIView.noIntrinsicMetric
                )
            )
        )
    }
    
    final class Coordinator: NSObject, UITextViewDelegate, UITextDragDelegate, UIGestureRecognizerDelegate {
        var parent: _TextView_UIKit
        weak var textView: InlineAttachmentTextView?
        var editMenuInteraction: UIEditMenuInteraction?
        /// What the text view was last given, which still carries the caller's
        /// own attributes; the view's storage only keeps the ones it draws.
        var renderedText = AttributedString()
        private var tapAction: (@MainActor (AttributedString, AttributedString.Index) -> Void)?
        private var tapRecognizer: UITapGestureRecognizer?
        /// Only there to fail: a tap waits for it, so a double tap that
        /// selects a word is not also reported as a tap.
        private var doubleTapRecognizer: UITapGestureRecognizer?
        
        init(_ parent: _TextView_UIKit) {
            self.parent = parent
        }

        /// Installs the recognizer only while someone listens.
        func setTapAction(_ action: (@MainActor (AttributedString, AttributedString.Index) -> Void)?) {
            tapAction = action
            guard let textView else { return }

            if action != nil, tapRecognizer == nil {
                let doubleTap = UITapGestureRecognizer()
                doubleTap.numberOfTapsRequired = 2
                doubleTap.delegate = self
                textView.addGestureRecognizer(doubleTap)
                doubleTapRecognizer = doubleTap

                let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                recognizer.delegate = self
                recognizer.require(toFail: doubleTap)
                textView.addGestureRecognizer(recognizer)
                tapRecognizer = recognizer
            } else if action == nil, let recognizer = tapRecognizer {
                textView.removeGestureRecognizer(recognizer)
                doubleTapRecognizer.map(textView.removeGestureRecognizer)
                tapRecognizer = nil
                doubleTapRecognizer = nil
            }
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let textView,
                  let tapAction else { return }

            let point = recognizer.location(in: textView)
            if let characterRange = textView.characterRange(at: point) {
                let location = textView.offset(from: textView.beginningOfDocument, to: characterRange.start)
                if location >= 0, location < textView.attributedText.length,
                   NSAttributedString.Key.ownsTaps(textView.attributedText.attributes(at: location, effectiveRange: nil)) {
                    return
                }
            }

            guard let position = textView.closestPosition(to: point) else { return }
            let offset = textView.offset(from: textView.beginningOfDocument, to: position)
            tapAction(renderedText, renderedText.characterIndex(atUTF16Offset: offset))
        }

        // Alongside the text view's own taps, which place and clear selection.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
        
        func textDraggableView(
            _ textDraggableView: UIView & UITextDraggable,
            itemsForDrag dragRequest: UITextDragRequest
        ) -> [UIDragItem] {
            guard let textView = textDraggableView as? InlineAttachmentTextView else {
                return dragRequest.suggestedItems
            }

            if textView.containsInlineAttachment(in: dragRequest.dragRange) {
                return []
            } else {
                return dragRequest.suggestedItems
            }
        }
    }
}

private extension InlineAttachmentTextView {
    func containsInlineAttachment(in textRange: UITextRange) -> Bool {
        let rangeStart = offset(from: beginningOfDocument, to: textRange.start)
        let rangeEnd = offset(from: beginningOfDocument, to: textRange.end)
        guard rangeStart >= 0,
              rangeEnd >= rangeStart else {
            return false
        }

        let range = NSRange(location: rangeStart, length: rangeEnd - rangeStart)
        guard range.length > 0,
              NSMaxRange(range) <= attributedText.length else {
            return false
        }

        var containsInlineAttachment = false
        attributedText.enumerateAttributes(in: range) { attributes, _, stop in
            if attributes[.inlineHostingAttachment] is InlineHostingAttachment ||
                attributes[.attachment] is InlineHostingAttachment {
                containsInlineAttachment = true
                stop.pointee = true
            }
        }

        return containsInlineAttachment
    }
}
#endif
