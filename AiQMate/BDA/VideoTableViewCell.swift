// VideoTableViewCell.swift
import UIKit

class VideoTableViewCell: UITableViewCell {

    // MARK: - UI Elements

    // Use static properties for brandColor and backgroundColorCell
    private static let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private static let backgroundColorCell = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)

    // Container view to add padding and styling
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = VideoTableViewCell.backgroundColorCell
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        // Added border
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 0.3).cgColor
        return view
    }()

    let videoImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.backgroundColor = UIColor.darkGray // Placeholder color
        return iv
    }()

    let videoTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.white
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.numberOfLines = 2
        return label
    }()

    let videoTypeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = VideoTableViewCell.brandColor
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()

    let videoAuthorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.lightGray
        label.font = UIFont.systemFont(ofSize: 15)
        return label
    }()

    let videoStatsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.lightGray
        label.font = UIFont.systemFont(ofSize: 13)
        return label
    }()

    let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        button.tintColor = VideoTableViewCell.brandColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let summaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "info.circle"), for: .normal)
        button.tintColor = VideoTableViewCell.brandColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Initializers
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupUI()
    }

    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear // Set cell background to clear
        selectionStyle = .none

        contentView.addSubview(containerView)

        // Add all UI elements to the containerView
        containerView.addSubview(videoImageView)
        containerView.addSubview(videoTitleLabel)
        containerView.addSubview(videoTypeLabel)
        containerView.addSubview(videoAuthorLabel)
        containerView.addSubview(videoStatsLabel)
        containerView.addSubview(playButton)
        containerView.addSubview(summaryButton)

        NSLayoutConstraint.activate([
            // Container View Constraints
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            // Video Image View
            videoImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            videoImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            videoImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            videoImageView.heightAnchor.constraint(equalTo: videoImageView.widthAnchor, multiplier: 9.0/16.0),

            // Video Title Label
            videoTitleLabel.topAnchor.constraint(equalTo: videoImageView.bottomAnchor, constant: 12),
            videoTitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            videoTitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            // Video Type Label
            videoTypeLabel.topAnchor.constraint(equalTo: videoTitleLabel.bottomAnchor, constant: 4),
            videoTypeLabel.leadingAnchor.constraint(equalTo: videoTitleLabel.leadingAnchor),
            videoTypeLabel.trailingAnchor.constraint(equalTo: videoTitleLabel.trailingAnchor),

            // Video Author Label
            videoAuthorLabel.topAnchor.constraint(equalTo: videoTypeLabel.bottomAnchor, constant: 8),
            videoAuthorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            videoAuthorLabel.trailingAnchor.constraint(lessThanOrEqualTo: summaryButton.leadingAnchor, constant: -10),

            // Video Stats Label
            videoStatsLabel.topAnchor.constraint(equalTo: videoAuthorLabel.bottomAnchor, constant: 2),
            videoStatsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            videoStatsLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            // Play Button
            playButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            playButton.centerYAnchor.constraint(equalTo: videoAuthorLabel.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 30),
            playButton.heightAnchor.constraint(equalToConstant: 30),

            // Summary Button
            summaryButton.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -10),
            summaryButton.centerYAnchor.constraint(equalTo: videoAuthorLabel.centerYAnchor),
            summaryButton.widthAnchor.constraint(equalToConstant: 30),
            summaryButton.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    // MARK: - Configuration
    /// Configures the cell with video data and view count.
    /// - Parameters:
    ///   - video: The `Video` model containing video information.
    ///   - viewCount: The number of views for the video.
    func configure(with video: Video, viewCount: Int) {
        videoTitleLabel.text = video.name
        videoTypeLabel.text = video.type
        videoAuthorLabel.text = video.uploader
        let dateString = DateFormatter.localizedString(from: video.uploadTime, dateStyle: .short, timeStyle: .none)
        videoStatsLabel.text = "\(viewCount) views · \(dateString)"

        // Load thumbnail image asynchronously if available
        if let thumbnailURL = video.thumbnailURL {
            loadImage(from: thumbnailURL)
        } else {
            // Set a placeholder image if thumbnail is not available
            videoImageView.image = UIImage(systemName: "video")?.withTintColor(.lightGray, renderingMode: .alwaysOriginal)
        }
    }

    /// Asynchronously loads an image from the given URL and sets it to the videoImageView.
    /// - Parameter url: The URL of the image to load.
    private func loadImage(from url: URL) {
        // Reset the image view
        videoImageView.image = nil

        // Create a data task to fetch the image
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            // Handle errors
            if let error = error {
                print("Error loading thumbnail image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.videoImageView.image = UIImage(systemName: "video")?.withTintColor(.lightGray, renderingMode: .alwaysOriginal)
                }
                return
            }

            // Ensure data is received and can be converted to UIImage
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.videoImageView.image = image
                }
            } else {
                DispatchQueue.main.async {
                    self?.videoImageView.image = UIImage(systemName: "video")?.withTintColor(.lightGray, renderingMode: .alwaysOriginal)
                }
            }
        }

        task.resume()
    }
}
