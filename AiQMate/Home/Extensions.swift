import UIKit

// MARK: - UIColor Extension

extension UIColor {
    static let customBackgroundColor = UIColor.black
    static let customTextColor = UIColor.white
    static let customAccentColor = UIColor.systemBlue
}

// MARK: - UIFont Extension

extension UIFont {
    static func customFont(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}
