// BufferView.swift
import UIKit

class BufferView: UIView {

    // MARK: - UI Elements
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = UIColor.white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        return indicator
    }()

    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.progressTintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0) // brandColor
        pv.trackTintColor = UIColor.lightGray
        pv.progress = 0.0
        pv.translatesAutoresizingMaskIntoConstraints = false
        return pv
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.text = "Uploading... 0%"
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup
    private func setupView() {
        self.backgroundColor = UIColor(white: 0, alpha: 0.7)

        self.addSubview(activityIndicator)
        self.addSubview(progressView)
        self.addSubview(progressLabel)

        NSLayoutConstraint.activate([
            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -30),

            // Progress View
            progressView.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -40),
            progressView.heightAnchor.constraint(equalToConstant: 4),

            // Progress Label
            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 10),
            progressLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        ])
    }

    // MARK: - Public Methods
    /// Updates the progress bar and label.
    /// - Parameter progress: The current progress (0.0 to 1.0).
    func updateProgress(_ progress: Float) {
        DispatchQueue.main.async {
            self.progressView.progress = progress
            let percentage = Int(progress * 100)
            self.progressLabel.text = "Uploading... \(percentage)%"
        }
    }
}
