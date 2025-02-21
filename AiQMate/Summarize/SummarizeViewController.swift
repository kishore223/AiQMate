// SummarizeViewController.swift
import UIKit
import AVKit
import AVFoundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import MobileCoreServices
import Speech

// MARK: - Video Model
struct Video {
    var filename: String
    var url: URL
    var uploadTime: Date
    var uploader: String
    var name: String
    var type: String
    var thumbnailURL: URL? // New property for thumbnail URL
}

// MARK: - SummarizeViewController
class SummarizeViewController: UIViewController {

    // MARK: - UI Elements

    // Use the same brandColor and backgroundColor as in HomeViewController
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)

    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    // Add a GradientLabel for the header title
    private let titleLabel: GradientLabel = {
        let label = GradientLabel()
        label.text = "Summarize Video"
        label.font = UIFont(name: "AvenirNext-Bold", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.7
        label.layer.shadowOffset = CGSize(width: 3, height: 3)
        label.layer.shadowRadius = 5
        label.layer.masksToBounds = false
        return label
    }()
    // Update the gradientLayer property
    private let gradientLayer: CAGradientLayer = {
        let gradientLayer = CAGradientLayer()
        // Match the gradient colors from ProfileViewController
        gradientLayer.colors = [
            UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 0.6).cgColor,
            UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 0.3).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        return gradientLayer
    }()

    private var headerButtonsStackView: UIStackView!
    private var searchBar: UISearchBar!
    private var tableView: UITableView!

    // MARK: - Data Properties
    private var allVideos: [Video] = []
    private var filteredVideos: [Video] = []
    private var viewCounts: [String: Int] = [:]
    private var searchQuery: String = ""
    private var currentFilterType: String? = nil

    // MARK: - Firebase References
    private let storage = Storage.storage()
    private let firestore = Firestore.firestore()
    private let auth = Auth.auth()

    // MARK: - Other Properties
    private var selectedVideo: Video?
    private var tempVideoURL: URL?
    private var videoName: String = ""
    private var videoType: String = ""
    private var currentUser: User?

    // Text fields for video details
    private var nameTextField: UITextField!
    private var typeTextField: UITextField!

    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    // MARK: - Buffer Overlay Properties
    private var bufferOverlayView: BufferView?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGradient()
        currentUser = auth.currentUser
        fetchVideos()
        loadViewCounts()

        // Hide the default navigation title
        self.navigationItem.title = "" // Clear the title to avoid conflict
        self.navigationController?.navigationBar.isHidden = true // Hide the navigation bar if needed
    }


    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 200) // Adjusted to cover top 100 points
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = backgroundColor

        // Add headerView
        view.addSubview(headerView)

        // Add titleLabel to headerView
        headerView.addSubview(titleLabel)

        // Header Buttons
        let sortButton = UIButton(type: .system)
        sortButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        sortButton.tintColor = brandColor
        sortButton.addTarget(self, action: #selector(handleSort), for: .touchUpInside)
        sortButton.accessibilityLabel = "Sort Videos"

        let uploadButton = UIButton(type: .system)
        uploadButton.setImage(UIImage(systemName: "folder.badge.plus.fill"), for: .normal)
        uploadButton.tintColor = brandColor
        uploadButton.addTarget(self, action: #selector(handleVideoUpload), for: .touchUpInside)
        uploadButton.accessibilityLabel = "Upload Video"

        let recordButton = UIButton(type: .system)
        recordButton.setImage(UIImage(systemName: "video.fill"), for: .normal)
        recordButton.tintColor = brandColor
        recordButton.addTarget(self, action: #selector(handleVideoRecord), for: .touchUpInside)
        recordButton.accessibilityLabel = "Record Video"

        headerButtonsStackView = UIStackView(arrangedSubviews: [sortButton, uploadButton, recordButton])
        headerButtonsStackView.axis = .horizontal
        headerButtonsStackView.spacing = 10
        headerButtonsStackView.alignment = .center
        headerButtonsStackView.distribution = .equalSpacing
        headerButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerButtonsStackView)

        // Add Search Bar
        searchBar = UISearchBar()
        searchBar.placeholder = "Search videos..."
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.barTintColor = backgroundColor
        searchBar.tintColor = brandColor
        searchBar.searchTextField.textColor = .white
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(searchBar)

        // Table View
        tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(VideoTableViewCell.self, forCellReuseIdentifier: "VideoCell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag // Dismiss keyboard when scrolling
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Set up constraints
        NSLayoutConstraint.activate([
            // Header View Constraints
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 90), // Increase the height to give more space

            // Title Label Constraints
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor,constant: -20 ), // Adjust top padding
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -20),

            // Search Bar Constraints
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24), // Add space between title and search bar
            searchBar.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: headerButtonsStackView.leadingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 40),

            // Header Buttons Stack View Constraints
            headerButtonsStackView.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor), // Align with search bar vertically
            headerButtonsStackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            headerButtonsStackView.heightAnchor.constraint(equalToConstant: 40),

            // Table View Constraints
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

    }

    // MARK: - Gradient Setup
    private func setupGradient() {
        // Remove the gradient from headerView and add it to the main view
        // This ensures the gradient is at the top of the page
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    // MARK: - Data Fetching
    private func fetchVideos() {
        let storageRef = storage.reference().child("videos")

        storageRef.listAll { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error listing videos: \(error.localizedDescription)")
                self.showAlert(title: "Error", message: "Failed to list videos.")
                return
            }

            guard let items = result?.items else {
                print("No videos found in storage.")
                return
            }

            var videoData: [Video] = []
            let dispatchGroup = DispatchGroup()

            for item in items {
                dispatchGroup.enter()
                item.getMetadata { (metadata, error) in
                    if let error = error {
                        print("Error getting metadata for \(item.name): \(error.localizedDescription)")
                        dispatchGroup.leave()
                        return
                    }

                    item.downloadURL { (url, error) in
                        if let error = error {
                            print("Error getting download URL for \(item.name): \(error.localizedDescription)")
                            dispatchGroup.leave()
                            return
                        }

                        if let url = url, let metadata = metadata {
                            let filename = item.name
                            let uploadTime = metadata.timeCreated ?? Date()
                            let uploader = metadata.customMetadata?["uploader"] ?? "Unknown"
                            let name = metadata.customMetadata?["name"] ?? "Unnamed Video"
                            let type = metadata.customMetadata?["type"] ?? "Unspecified"
                            let thumbnailURLString = metadata.customMetadata?["thumbnailURL"]
                            let thumbnailURL = thumbnailURLString != nil ? URL(string: thumbnailURLString!) : nil

                            let video = Video(filename: filename, url: url, uploadTime: uploadTime, uploader: uploader, name: name, type: type, thumbnailURL: thumbnailURL)
                            videoData.append(video)
                        }
                        dispatchGroup.leave()
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                self.allVideos = videoData
                self.filterVideos()
                self.tableView.reloadData()
            }
        }
    }

    private func loadViewCounts() {
        firestore.collection("viewCounts").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error loading view counts: \(error.localizedDescription)")
                self.showAlert(title: "Error", message: "Failed to load view counts.")
                return
            }

            guard let documents = snapshot?.documents else { return }

            var counts: [String: Int] = [:]
            for document in documents {
                let data = document.data()
                if let count = data["count"] as? Int {
                    counts[document.documentID] = count
                }
            }
            self.viewCounts = counts
            self.tableView.reloadData()
        }
    }

    private func saveViewCount(filename: String, count: Int) {
        firestore.collection("viewCounts").document(filename).setData(["count": count]) { error in
            if let error = error {
                print("Error saving view count for \(filename): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Video Filtering and Organizing
    private func filterVideos() {
        filteredVideos = allVideos

        // Apply search filter
        if !searchQuery.isEmpty {
            filteredVideos = filteredVideos.filter { $0.name.lowercased().contains(searchQuery.lowercased()) }
        }

        // Apply type filter
        if let filterType = currentFilterType {
            filteredVideos = filteredVideos.filter { $0.type == filterType }
        }

        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func handleSort() {
        // Get unique video types
        let videoTypes = Set(allVideos.map { $0.type }).sorted()
        var actions: [UIAlertAction] = []

        // Add 'All' option
        let allAction = UIAlertAction(title: "All", style: .default) { _ in
            self.currentFilterType = nil
            self.filterVideos()
        }
        actions.append(allAction)

        // Add actions for each type
        for type in videoTypes {
            let action = UIAlertAction(title: type, style: .default) { _ in
                self.currentFilterType = type
                self.filterVideos()
            }
            actions.append(action)
        }

        // Add cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        actions.append(cancelAction)

        // Present action sheet
        let actionSheet = UIAlertController(title: "Filter by Type", message: nil, preferredStyle: .actionSheet)
        for action in actions {
            actionSheet.addAction(action)
        }

        // For iPad support
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        present(actionSheet, animated: true, completion: nil)
    }

    @objc private func handleOpenVideo(_ sender: UIButton) {
        let index = sender.tag
        let video: Video = filteredVideos[index]

        selectedVideo = video

        let player = AVPlayer(url: video.url)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        present(playerVC, animated: true) {
            player.play()
        }

        // Update view counts
        let filename = video.filename
        let newCount = (viewCounts[filename] ?? 0) + 1
        viewCounts[filename] = newCount
        saveViewCount(filename: filename, count: newCount)
    }

    @objc private func handleViewSummary(_ sender: UIButton) {
        let index = sender.tag
        let video: Video = filteredVideos[index]

        let filename = video.filename

        firestore.collection("video_summaries").document(filename).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching summary for \(filename): \(error.localizedDescription)")
                self.showAlert(title: "Error", message: "Failed to fetch summary.")
                return
            }

            var summaryText = "No summary available for this video."
            if let document = document, document.exists {
                if let data = document.data(), let summary = data["summary"] as? String {
                    summaryText = summary
                }
            }

            // Show summary in a modal
            let summaryVC = UIViewController()
            summaryVC.view.backgroundColor = UIColor(white: 0, alpha: 0.7)
            summaryVC.modalPresentationStyle = .overFullScreen

            let contentView = UIView()
            contentView.backgroundColor = backgroundColor // Match container color with page's background color
            contentView.layer.cornerRadius = 15
            contentView.layer.borderWidth = 1
            contentView.layer.borderColor = brandColor.withAlphaComponent(0.5).cgColor // Subtle border for visual distinction
            contentView.layer.shadowColor = UIColor.black.cgColor // Added shadow for depth
            contentView.layer.shadowOpacity = 0.3
            contentView.layer.shadowOffset = CGSize(width: 0, height: 5)
            contentView.layer.shadowRadius = 10
            contentView.clipsToBounds = false
            contentView.translatesAutoresizingMaskIntoConstraints = false

            let titleLabel = UILabel()
            titleLabel.text = "Video Summary"
            titleLabel.textColor = UIColor.white
            titleLabel.font = UIFont.boldSystemFont(ofSize: 24) // Slightly smaller font for balance
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.textAlignment = .center

            let textView = UITextView()
            let formattedSummaryText = summaryText.replacingOccurrences(of: "\n", with: "\n\n") // Adds an extra line break after each newline
            textView.text = formattedSummaryText
            textView.textColor = UIColor.white
            textView.font = UIFont.systemFont(ofSize: 16, weight: .regular) // Reduced font size for readability
            textView.backgroundColor = UIColor.clear // Transparent background to blend with container
            textView.isEditable = false
            textView.isScrollEnabled = true // Allow scrolling for longer summaries
            textView.layer.cornerRadius = 10
            textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20) // Padding for better text spacing
            textView.layer.borderColor = brandColor.withAlphaComponent(0.3).cgColor // Optional border for focus
            textView.layer.borderWidth = 1
            textView.translatesAutoresizingMaskIntoConstraints = false

            let closeButton = UIButton(type: .system)
            closeButton.setTitle("Close", for: .normal)
            closeButton.backgroundColor = brandColor
            closeButton.setTitleColor(UIColor.white, for: .normal)
            closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            closeButton.layer.cornerRadius = 12
            closeButton.addTarget(self, action: #selector(self.closeSummaryModal), for: .touchUpInside)
            closeButton.translatesAutoresizingMaskIntoConstraints = false

            contentView.addSubview(titleLabel)
            contentView.addSubview(textView)
            contentView.addSubview(closeButton)

            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30), // Added extra space
                titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

                textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24), // Added extra space
                textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300), // Increased height for better readability

                closeButton.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 24), // Added extra space
                closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30), // Added extra space
                closeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                closeButton.widthAnchor.constraint(equalToConstant: 120),
                closeButton.heightAnchor.constraint(equalToConstant: 45)
            ])

            summaryVC.view.addSubview(contentView)

            NSLayoutConstraint.activate([
                contentView.centerYAnchor.constraint(equalTo: summaryVC.view.centerYAnchor),
                contentView.leadingAnchor.constraint(equalTo: summaryVC.view.leadingAnchor, constant: 20),
                contentView.trailingAnchor.constraint(equalTo: summaryVC.view.trailingAnchor, constant: -20),
                contentView.heightAnchor.constraint(lessThanOrEqualToConstant: 650) // Further increased maximum height for larger summaries
            ])

            self.present(summaryVC, animated: true, completion: nil)
        }
    }

    @objc private func closeSummaryModal() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func closeVideoDetailsModal() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func handleVideoUpload() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.sourceType = .photoLibrary
        picker.videoQuality = .typeHigh
        present(picker, animated: true, completion: nil)
    }

    @objc private func handleVideoRecord() {
        // Check if camera is available
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(title: "Camera Unavailable", message: "This device has no camera.")
            return
        }

        let picker = UIImagePickerController()
        picker.delegate = self
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.sourceType = .camera
        picker.cameraCaptureMode = .video
        picker.videoQuality = .typeHigh
        present(picker, animated: true, completion: nil)
    }

    // MARK: - Video Details Modal
    private func showVideoDetailsModal() {
        guard let tempVideoURL = tempVideoURL else { return }

        let detailsVC = UIViewController()
        detailsVC.view.backgroundColor = UIColor(white: 0, alpha: 0.7)
        detailsVC.modalPresentationStyle = .overFullScreen

        let contentView = UIView()
        contentView.backgroundColor = backgroundColor
        contentView.layer.cornerRadius = 15
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 0.3).cgColor
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Video Details"
        titleLabel.textColor = UIColor.white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Assign to class properties for access in handleSaveVideo
        nameTextField = UITextField()
        nameTextField.placeholder = "Video Name"
        nameTextField.textColor = UIColor.white
        nameTextField.backgroundColor = UIColor.darkGray
        nameTextField.layer.cornerRadius = 8
        nameTextField.setLeftPaddingPoints(10)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false

        typeTextField = UITextField()
        typeTextField.placeholder = "Video Type"
        typeTextField.textColor = UIColor.white
        typeTextField.backgroundColor = UIColor.darkGray
        typeTextField.layer.cornerRadius = 8
        typeTextField.setLeftPaddingPoints(10)
        typeTextField.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.backgroundColor = brandColor
        saveButton.setTitleColor(UIColor.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.addTarget(self, action: #selector(handleSaveVideo), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.backgroundColor = UIColor.systemRed
        cancelButton.setTitleColor(UIColor.white, for: .normal)
        cancelButton.layer.cornerRadius = 10
        cancelButton.addTarget(self, action: #selector(closeVideoDetailsModal), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(nameTextField)
        contentView.addSubview(typeTextField)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            // Title Label
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // Name TextField
            nameTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            nameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameTextField.heightAnchor.constraint(equalToConstant: 40),

            // Type TextField
            typeTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 16),
            typeTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            typeTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            typeTextField.heightAnchor.constraint(equalToConstant: 40),

            // Save Button
            saveButton.topAnchor.constraint(equalTo: typeTextField.bottomAnchor, constant: 16),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 40),

            // Cancel Button
            cancelButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])

        detailsVC.view.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.centerYAnchor.constraint(equalTo: detailsVC.view.centerYAnchor),
            contentView.leadingAnchor.constraint(equalTo: detailsVC.view.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: detailsVC.view.trailingAnchor, constant: -20),
        ])

        // Present the details modal
        self.present(detailsVC, animated: true, completion: nil)
    }

    // MARK: - Upload Handling

    @objc private func handleSaveVideo() {
        guard let tempVideoURL = tempVideoURL else {
            print("Temporary video URL is nil.")
            showAlert(title: "Error", message: "Video file is missing. Please try again.")
            return
        }

        guard let videoName = nameTextField.text, !videoName.isEmpty,
              let videoType = typeTextField.text, !videoType.isEmpty else {
            showAlert(title: "Missing Information", message: "Please provide both video name and type.")
            return
        }

        // Check file size (e.g., limit to 500MB)
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: tempVideoURL.path)
            if let fileSize = fileAttributes[.size] as? UInt64 {
                let fileSizeInMB = Double(fileSize) / (1024.0 * 1024.0)
                if fileSizeInMB > 500.0 {
                    showAlert(title: "File Too Large", message: "Please select a video smaller than 500MB.")
                    return
                }
            }
        } catch {
            print("Error retrieving file size: \(error.localizedDescription)")
            showAlert(title: "Error", message: "Unable to process the video file. Please try a different one.")
            return
        }

        // Dismiss the video details modal
        dismiss(animated: true) {
            // Show buffer overlay after dismissing the modal
            self.showBufferOverlay()

            // Generate a unique filename
            let timestamp = Int(Date().timeIntervalSince1970)
            let sanitizedVideoName = videoName.replacingOccurrences(of: " ", with: "_")
            let filename = "\(timestamp)_\(sanitizedVideoName).mov"

            let storageRef = self.storage.reference().child("videos/\(filename)")

            // Create metadata
            let metadata = StorageMetadata()
            metadata.contentType = "video/quicktime"
            metadata.customMetadata = [
                "name": videoName,
                "type": videoType,
                "uploader": self.currentUser?.email ?? "Unknown"
            ]

            print("Starting upload for filename: \(filename)")

            // Upload the video with progress tracking
            let uploadTask = storageRef.putFile(from: tempVideoURL, metadata: metadata) { [weak self] metadata, error in
                guard let self = self else { return }

                if let error = error {
                    print("Error uploading video: \(error.localizedDescription)")
                    self.hideBufferOverlay()
                    self.showAlert(title: "Upload Failed", message: "Failed to upload video. Please ensure you have a stable internet connection and try again.\n\nError: \(error.localizedDescription)")
                    return
                }

                // Optionally, get download URL after upload
                storageRef.downloadURL { (url, error) in
                    if let error = error {
                        print("Error getting download URL: \(error.localizedDescription)")
                        // Optionally, notify the user
                    } else if let url = url {
                        print("Video uploaded successfully. Download URL: \(url.absoluteString)")
                    }
                }

                // Proceed to generate and upload thumbnail
                self.generateThumbnail(from: tempVideoURL) { [weak self] thumbnailImage in
                    guard let self = self, let thumbnailImage = thumbnailImage else {
                        self?.hideBufferOverlay()
                        self?.showAlert(title: "Thumbnail Error", message: "Failed to generate thumbnail.")
                        return
                    }

                    // Upload thumbnail
                    self.uploadThumbnail(image: thumbnailImage, for: filename) { [weak self] thumbnailURL in
                        guard let self = self, let thumbnailURL = thumbnailURL else {
                            self?.hideBufferOverlay()
                            self?.showAlert(title: "Thumbnail Upload Error", message: "Failed to upload thumbnail.")
                            return
                        }

                        // Update video metadata with thumbnailURL
                        self.updateVideoMetadata(storageRef: storageRef, thumbnailURL: thumbnailURL) { success in
                            if success {
                                print("Thumbnail URL added to video metadata.")

                                // Extract text from video
                                self.extractTextFromVideo(videoURL: tempVideoURL, filename: filename)

                                // Refresh video list
                                self.fetchVideos()

                                // Hide buffer overlay
                                self.hideBufferOverlay()
                            } else {
                                self.hideBufferOverlay()
                                self.showAlert(title: "Metadata Update Error", message: "Failed to update video metadata with thumbnail URL.")
                            }
                        }
                    }
                }
            }

            // Observe upload progress
            uploadTask.observe(.progress) { [weak self] snapshot in
                guard let self = self, let progress = snapshot.progress else { return }
                let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                print("Upload is \(percentComplete)% complete.")

                DispatchQueue.main.async {
                    self.bufferOverlayView?.updateProgress(Float(progress.fractionCompleted))
                }
            }

            // Handle successful completion
            uploadTask.observe(.success) { [weak self] _ in
                guard let self = self else { return }
                print("Upload task completed successfully.")
            }

            // Handle failure
            uploadTask.observe(.failure) { [weak self] snapshot in
                guard let self = self else { return }
                if let error = snapshot.error {
                    print("Upload task failed with error: \(error.localizedDescription)")
                    self.showAlert(title: "Upload Failed", message: "Failed to upload video. Please try again.\n\nError: \(error.localizedDescription)")
                    self.hideBufferOverlay()
                }
            }
        }
    }

    // MARK: - Thumbnail Generation and Upload

    /// Generates a thumbnail image from the given video URL.
    /// - Parameters:
    ///   - videoURL: The URL of the video.
    ///   - completion: Completion handler with the generated UIImage or nil.
    private func generateThumbnail(from videoURL: URL, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global().async {
            let asset = AVAsset(url: videoURL)
            let assetImgGenerate = AVAssetImageGenerator(asset: asset)
            assetImgGenerate.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 1, preferredTimescale: 60)
            do {
                let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
                let thumbnail = UIImage(cgImage: img)
                completion(thumbnail)
            } catch {
                print("Error generating thumbnail: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    /// Uploads the thumbnail image to Firebase Storage.
    /// - Parameters:
    ///   - image: The thumbnail UIImage.
    ///   - filename: The original video filename to associate the thumbnail.
    ///   - completion: Completion handler with the thumbnail URL or nil.
    private func uploadThumbnail(image: UIImage, for filename: String, completion: @escaping (URL?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert thumbnail image to JPEG data.")
            completion(nil)
            return
        }

        let thumbnailRef = storage.reference().child("thumbnails/\(filename).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        thumbnailRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("Error uploading thumbnail: \(error.localizedDescription)")
                completion(nil)
                return
            }

            thumbnailRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting thumbnail download URL: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                if let url = url {
                    completion(url)
                } else {
                    completion(nil)
                }
            }
        }
    }

    /// Updates the video's metadata with the thumbnail URL.
    /// - Parameters:
    ///   - storageRef: The StorageReference of the uploaded video.
    ///   - thumbnailURL: The URL of the uploaded thumbnail.
    ///   - completion: Completion handler with a success flag.
    private func updateVideoMetadata(storageRef: StorageReference, thumbnailURL: URL, completion: @escaping (Bool) -> Void) {
        storageRef.getMetadata { metadata, error in
            if let error = error {
                print("Error fetching metadata for update: \(error.localizedDescription)")
                completion(false)
                return
            }

            guard var metadata = metadata else {
                print("No metadata found for update.")
                completion(false)
                return
            }

            metadata.customMetadata?["thumbnailURL"] = thumbnailURL.absoluteString

            storageRef.updateMetadata(metadata) { metadata, error in
                if let error = error {
                    print("Error updating metadata: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                completion(true)
            }
        }
    }

    // MARK: - Buffer Overlay Methods

    /// Displays the buffer overlay with a loading spinner and progress bar.
    private func showBufferOverlay() {
        // Prevent multiple overlays
        guard bufferOverlayView == nil else { return }

        let buffer = BufferView()
        buffer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buffer)

        NSLayoutConstraint.activate([
            buffer.topAnchor.constraint(equalTo: view.topAnchor),
            buffer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buffer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buffer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        bufferOverlayView = buffer
    }

    /// Hides and removes the buffer overlay.
    private func hideBufferOverlay() {
        DispatchQueue.main.async {
            self.bufferOverlayView?.removeFromSuperview()
            self.bufferOverlayView = nil
        }
    }

    // MARK: - Text Extraction and Summarization

    private func extractTextFromVideo(videoURL: URL, filename: String) {
        print("Starting text extraction from video: \(filename)")
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self = self else { return }
            switch authStatus {
            case .authorized:
                self.recognizeSpeechFromVideo(videoURL: videoURL, filename: filename)
            case .denied, .restricted, .notDetermined:
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Speech recognition authorization denied.")
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Unknown speech recognition authorization status.")
                }
            }
        }
    }

    private func recognizeSpeechFromVideo(videoURL: URL, filename: String) {
        // Extract audio from video using AVAssetExportSession
        let asset = AVAsset(url: videoURL)

        // Check if the asset has audio tracks
        if asset.tracks(withMediaType: .audio).isEmpty {
            DispatchQueue.main.async {
                self.showAlert(title: "No Audio Found", message: "The selected video does not contain an audio track.")
            }
            return
        }

        // Create a unique temporary file URL for the extracted audio
        let tempDir = NSTemporaryDirectory()
        let tempFilePath = tempDir + "\(filename).m4a"
        let tempFileURL = URL(fileURLWithPath: tempFilePath)

        // Remove the file if it already exists
        if FileManager.default.fileExists(atPath: tempFileURL.path) {
            do {
                try FileManager.default.removeItem(at: tempFileURL)
            } catch {
                print("Error removing existing file: \(error.localizedDescription)")
            }
        }

        // Create an AVAssetExportSession to export the audio track
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            DispatchQueue.main.async {
                self.showAlert(title: "Error", message: "Failed to create export session.")
            }
            return
        }

        exportSession.outputURL = tempFileURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(start: CMTime.zero, duration: asset.duration)

        print("Starting audio export to: \(tempFileURL)")

        exportSession.exportAsynchronously { [weak self] in
            guard let self = self else { return }
            switch exportSession.status {
            case .completed:
                // Check if the audio file exists and is valid
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: tempFileURL.path)[.size] as? UInt64) ?? 0
                    if fileSize > 0 {
                        print("Audio file exported successfully: \(tempFileURL)")
                        self.recognizeSpeechFromAudioFile(audioURL: tempFileURL, filename: filename)
                    } else {
                        DispatchQueue.main.async {
                            self.showAlert(title: "Extraction Error", message: "Extracted audio file is empty.")
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showAlert(title: "Extraction Error", message: "Failed to export audio from video.")
                    }
                }
            case .failed:
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Failed to export audio: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                }
            case .cancelled:
                DispatchQueue.main.async {
                    self.showAlert(title: "Cancelled", message: "Audio export was cancelled.")
                }
            default:
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Audio export failed.")
                }
            }
        }
    }

    private func recognizeSpeechFromAudioFile(audioURL: URL, filename: String) {
        print("Starting speech recognition for audio file: \(audioURL)")
        // Create an SFSpeechURLRecognitionRequest with the audio file URL
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)

        // Perform speech recognition
        speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Speech recognition failed: \(error.localizedDescription)")
                }
                return
            }

            if let result = result, result.isFinal {
                let transcription = result.bestTranscription.formattedString
                print("Transcription obtained: \(transcription)")
                if transcription.isEmpty {
                    DispatchQueue.main.async {
                        self.showAlert(title: "Transcription Error", message: "No speech was recognized in the video.")
                    }
                    return
                }
                // Proceed with saving transcription
                self.saveTranscription(transcription, filename: filename)
            }
        }
    }

    // MARK: - OpenAI Integration for Summarization

    private func summarizeText(_ text: String, completion: @escaping (String?) -> Void) {
        // Retrieve the OpenAI API key from the Config
        let apiKey = Config.openAIAPIKey

        // Ensure the API key is not empty
        guard !apiKey.isEmpty else {
            print("OpenAI API key is missing.")
            completion(nil)
            return
        }

        // Define the OpenAI API endpoint
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        // Create the URL request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepare the request body
        let messages = [
            ["role": "system", "content": "You are a helpful assistant that summarizes video transcriptions into a step-by-step procedure."],
            ["role": "user", "content": "Please summarize the following transcription into a step-by-step procedure:\n\n\(text)"]
        ]

        let body: [String: Any] = [
            "model": "gpt-3.5-turbo", // You can choose other models like "gpt-4" if available
            "messages": messages,
            "max_tokens": 500, // Adjust based on desired summary length
            "temperature": 0.7 // Controls the randomness of the output
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Error serializing JSON: \(error.localizedDescription)")
            completion(nil)
            return
        }

        print("Sending transcription to OpenAI for summarization.")

        // Create the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle errors
            if let error = error {
                print("Error calling OpenAI API: \(error.localizedDescription)")
                completion(nil)
                return
            }

            // Ensure data is received
            guard let data = data else {
                print("No data received from OpenAI API")
                completion(nil)
                return
            }

            // Parse the JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let summary = message["content"] as? String {
                    completion(summary.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    print("Invalid response format from OpenAI API")
                    completion(nil)
                }
            } catch {
                print("Error parsing OpenAI API response: \(error.localizedDescription)")
                completion(nil)
            }
        }

        // Start the data task
        task.resume()
    }

    // MARK: - Transcription and Summarization

    private func saveTranscription(_ transcription: String, filename: String) {
        // Call OpenAI API to get the summary
        summarizeText(transcription) { [weak self] summary in
            guard let self = self else { return }
            // Check if summary was successfully retrieved
            guard let summary = summary else {
                // If summarization failed, save the original transcription
                print("Summarization failed. Saving original transcription.")
                self.firestore.collection("video_summaries").document(filename).setData(["summary": transcription]) { error in
                    if let error = error {
                        print("Error saving transcription for \(filename): \(error.localizedDescription)")
                        self.showAlert(title: "Error", message: "Failed to save transcription.\n\nError: \(error.localizedDescription)")
                    } else {
                        print("Transcription saved successfully for \(filename).")
                        self.showAlert(title: "Success", message: "Video uploaded and transcription saved successfully.")
                        self.dismissUploadModal()
                    }
                }
                return
            }

            // Save the summary to Firestore
            self.firestore.collection("video_summaries").document(filename).setData(["summary": summary]) { error in
                if let error = error {
                    print("Error saving summary for \(filename): \(error.localizedDescription)")
                    self.showAlert(title: "Error", message: "Failed to save summary.\n\nError: \(error.localizedDescription)")
                } else {
                    print("Summary saved successfully for \(filename).")
                    self.showAlert(title: "Success", message: "Video uploaded and summarized successfully.")
                    self.dismissUploadModal()
                }
            }
        }
    }

    // MARK: - Modal Dismissal

    private func dismissUploadModal() {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - Helper Functions

    /// Displays an alert with the given title and message.
    /// - Parameters:
    ///   - title: The title of the alert.
    ///   - message: The message body of the alert.
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: - UITableViewDataSource
extension SummarizeViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1 // Single section
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredVideos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath) as? VideoTableViewCell else {
            // If casting fails, return a default UITableViewCell
            return UITableViewCell()
        }

        let video = filteredVideos[indexPath.row]
        let viewCount = viewCounts[video.filename] ?? 0
        cell.configure(with: video, viewCount: viewCount)

        // Add targets to buttons
        cell.playButton.tag = indexPath.row
        cell.playButton.addTarget(self, action: #selector(handleOpenVideo(_:)), for: .touchUpInside)

        cell.summaryButton.tag = indexPath.row
        cell.summaryButton.addTarget(self, action: #selector(handleViewSummary(_:)), for: .touchUpInside)

        return cell
    }
}

// MARK: - UITableViewDelegate
extension SummarizeViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil // No headers needed
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0 // No headers
    }
}

// MARK: - UISearchBarDelegate
extension SummarizeViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchQuery = searchText
        filterVideos()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder() // Dismiss keyboard
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension SummarizeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    // Handle selected or recorded video
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        picker.dismiss(animated: true, completion: nil)

        if let mediaType = info[.mediaType] as? String, mediaType == (kUTTypeMovie as String) {
            if let mediaURL = info[.mediaURL] as? URL {
                // Generate a unique temporary file path
                let tempDir = NSTemporaryDirectory()
                let tempFileName = UUID().uuidString + ".mov"
                let tempFilePath = tempDir + tempFileName
                let tempFileURL = URL(fileURLWithPath: tempFilePath)

                do {
                    // Copy the video to the temporary directory
                    try FileManager.default.copyItem(at: mediaURL, to: tempFileURL)
                    tempVideoURL = tempFileURL
                    print("Video copied to temporary URL: \(tempFileURL)")
                    showVideoDetailsModal()
                } catch {
                    print("Error copying video file: \(error.localizedDescription)")
                    showAlert(title: "Upload Error", message: "Failed to process the selected video. Please try again.")
                }
            }
        }
    }
}
