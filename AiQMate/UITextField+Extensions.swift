// UITextField+Extensions.swift
import UIKit

// MARK: - UITextField Extensions
extension UITextField {
    /// Adds left padding to the text field.
    /// - Parameter amount: The width of the padding in points.
    func setLeftPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
    
    /// Adds right padding to the text field.
    /// - Parameter amount: The width of the padding in points.
    func setRightPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.rightView = paddingView
        self.rightViewMode = .always
    }
}
