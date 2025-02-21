import Foundation

// MARK: - AppError

enum AppError: Error {
    case networkError
    case databaseError
    case imageUploadError
    case invalidInput
    
    var localizedDescription: String {
        switch self {
        case .networkError:
            return "Network error occurred. Please check your internet connection and try again."
        case .databaseError:
            return "Database error occurred. Please try again later."
        case .imageUploadError:
            return "Failed to upload image. Please try again."
        case .invalidInput:
            return "Invalid input. Please check your entries and try again."
        }
    }
}
