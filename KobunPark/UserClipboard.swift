//
//  UserClipboard.swift
//  KobunPark
//

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum UserClipboard {
    @discardableResult
    static func write(_ text: String) -> Bool {
        guard !text.isEmpty else {
            return false
        }

#if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
#elseif canImport(UIKit)
        UIPasteboard.general.string = text
        return true
#else
        return false
#endif
    }
}
