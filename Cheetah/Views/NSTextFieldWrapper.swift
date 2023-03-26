import SwiftUI
import AppKit

class CustomNSTextField: RSHeightHuggingTextField {
    var onSelectedRangesChanged: ((NSRange?) -> Void)?
    
    @objc func textViewDidChangeSelection(_ notification: NSNotification) {
        onSelectedRangesChanged?(currentEditor()?.selectedRange)
    }
}

struct NSTextFieldWrapper: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> CustomNSTextField {
        let textField = CustomNSTextField(frame: NSRect())
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = true
        textField.drawsBackground = false
        textField.delegate = context.coordinator
        textField.onSelectedRangesChanged = { range in
            if let range = range {
                DispatchQueue.main.async {
                    self.selectedRange = range
                }
            }
        }
        return textField
    }

    func updateNSView(_ nsView: CustomNSTextField, context: Context) {
        nsView.stringValue = text
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NSTextFieldWrapper

        init(_ textField: NSTextFieldWrapper) {
            self.parent = textField
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            self.parent.text = textField.stringValue
        }
    }
}
