// ImageItem.swift

import Foundation

struct ImageItem: Equatable {
    let id: String
    let name: String
    let imageURL: URL
    let site: String
    let section: String
    let subsection: String
    let type: String
    var isFavorite: Bool

    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        return lhs.id == rhs.id
    }
}
