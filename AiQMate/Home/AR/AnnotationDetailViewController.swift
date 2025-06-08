import UIKit
import FirebaseFirestore
import SDWebImage
import AVKit

class AnnotationDetailViewController: UIViewController {
    
    // MARK: - Properties
    
    var annotation: Annotation!
    var containerName: String = ""
    
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    
    private var detailedInfo: DetailedAdditionalInfo?
    
    // MARK: - UI Elements
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let annotationTextContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let annotationTextLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let stepsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        view.layer.cornerRadius = 15
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let stepsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let noDataLabel: UILabel = {
        let label = UILabel()
        label.text = "No detailed information available for this anchor"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .lightGray
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadDetailedInfo()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = backgroundColor
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        // Setup annotation text container with proper padding
        annotationTextContainer.addSubview(annotationTextLabel)
        
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(annotationTextContainer)
        contentStackView.addArrangedSubview(stepsContainerView)
        contentStackView.addArrangedSubview(noDataLabel)
        
        stepsContainerView.addSubview(stepsStackView)
        
        setupConstraints()
        setupInitialData()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            // Annotation text container constraints
            annotationTextContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            // Annotation text label with padding inside container
            annotationTextLabel.topAnchor.constraint(equalTo: annotationTextContainer.topAnchor, constant: 10),
            annotationTextLabel.leadingAnchor.constraint(equalTo: annotationTextContainer.leadingAnchor, constant: 15),
            annotationTextLabel.trailingAnchor.constraint(equalTo: annotationTextContainer.trailingAnchor, constant: -15),
            annotationTextLabel.bottomAnchor.constraint(equalTo: annotationTextContainer.bottomAnchor, constant: -10),
            
            stepsStackView.topAnchor.constraint(equalTo: stepsContainerView.topAnchor, constant: 15),
            stepsStackView.leadingAnchor.constraint(equalTo: stepsContainerView.leadingAnchor, constant: 15),
            stepsStackView.trailingAnchor.constraint(equalTo: stepsContainerView.trailingAnchor, constant: -15),
            stepsStackView.bottomAnchor.constraint(equalTo: stepsContainerView.bottomAnchor, constant: -15)
        ])
    }
    
    private func setupNavigationBar() {
        title = "Anchor Details"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )
    }
    
    private func setupInitialData() {
        titleLabel.text = annotation.text
        annotationTextLabel.text = "📍 \(annotation.text)"
        
        // Initially hide the containers
        stepsContainerView.isHidden = true
        noDataLabel.isHidden = false
    }
    
    // MARK: - Data Loading
    
    private func loadDetailedInfo() {
        let db = Firestore.firestore()
        
        db.collection("annotationDetailedInfos").document(annotation.id).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading detailed info: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showNoDataState()
                }
                return
            }
            
            guard let document = document, document.exists else {
                DispatchQueue.main.async {
                    self.showNoDataState()
                }
                return
            }
            
            let data = document.data() ?? [:]
            let title = data["title"] as? String ?? ""
            let stepsArray = data["steps"] as? [[String: Any]] ?? []
            
            var steps: [Step] = []
            for stepDict in stepsArray {
                let stepText = stepDict["text"] as? String ?? ""
                let mediaURLs = stepDict["mediaURLs"] as? [String] ?? []
                steps.append(Step(text: stepText, mediaURLs: mediaURLs))
            }
            
            let detailedInfo = DetailedAdditionalInfo(title: title, steps: steps)
            self.detailedInfo = detailedInfo
            
            DispatchQueue.main.async {
                self.displayDetailedInfo(detailedInfo)
            }
        }
    }
    
    private func showNoDataState() {
        stepsContainerView.isHidden = true
        noDataLabel.isHidden = false
    }
    
    private func displayDetailedInfo(_ info: DetailedAdditionalInfo) {
        if info.steps.isEmpty {
            showNoDataState()
            return
        }
        
        // Clear previous steps
        stepsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Update title if available
        if !info.title.isEmpty {
            titleLabel.text = info.title
        }
        
        // Add section header
        let sectionHeaderLabel = UILabel()
        sectionHeaderLabel.text = "📋 Detailed Steps"
        sectionHeaderLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        sectionHeaderLabel.textColor = brandColor
        sectionHeaderLabel.textAlignment = .left
        stepsStackView.addArrangedSubview(sectionHeaderLabel)
        
        // Add each step
        for (index, step) in info.steps.enumerated() {
            let stepView = createStepView(step: step, stepNumber: index + 1)
            stepsStackView.addArrangedSubview(stepView)
        }
        
        stepsContainerView.isHidden = false
        noDataLabel.isHidden = true
    }
    
    // MARK: - Step View Creation
    
    private func createStepView(step: Step, stepNumber: Int) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = brandColor.withAlphaComponent(0.3).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let stepStackView = UIStackView()
        stepStackView.axis = .vertical
        stepStackView.spacing = 10
        stepStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Step header
        let stepHeaderView = UIView()
        stepHeaderView.translatesAutoresizingMaskIntoConstraints = false
        
        let stepNumberLabel = UILabel()
        stepNumberLabel.text = "Step \(stepNumber)"
        stepNumberLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        stepNumberLabel.textColor = brandColor
        stepNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        
        stepHeaderView.addSubview(stepNumberLabel)
        
        // Step text
        let stepTextLabel = UILabel()
        stepTextLabel.text = step.text.isEmpty ? "No description provided" : step.text
        stepTextLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        stepTextLabel.textColor = .white
        stepTextLabel.numberOfLines = 0
        stepTextLabel.translatesAutoresizingMaskIntoConstraints = false
        
        stepStackView.addArrangedSubview(stepHeaderView)
        stepStackView.addArrangedSubview(stepTextLabel)
        
        // Media section
        if !step.mediaURLs.isEmpty {
            let mediaView = createMediaView(mediaURLs: step.mediaURLs)
            stepStackView.addArrangedSubview(mediaView)
        }
        
        containerView.addSubview(stepStackView)
        
        NSLayoutConstraint.activate([
            stepNumberLabel.topAnchor.constraint(equalTo: stepHeaderView.topAnchor),
            stepNumberLabel.leadingAnchor.constraint(equalTo: stepHeaderView.leadingAnchor),
            stepNumberLabel.trailingAnchor.constraint(equalTo: stepHeaderView.trailingAnchor),
            stepNumberLabel.bottomAnchor.constraint(equalTo: stepHeaderView.bottomAnchor),
            
            stepStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            stepStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            stepStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            stepStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15)
        ])
        
        return containerView
    }
    
    private func createMediaView(mediaURLs: [String]) -> UIView {
        let mediaContainerView = UIView()
        mediaContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        let mediaLabel = UILabel()
        mediaLabel.text = "📎 Media (\(mediaURLs.count) items)"
        mediaLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        mediaLabel.textColor = brandColor
        mediaLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let mediaStackView = UIStackView()
        mediaStackView.axis = .vertical
        mediaStackView.spacing = 8
        mediaStackView.translatesAutoresizingMaskIntoConstraints = false
        
        mediaContainerView.addSubview(mediaLabel)
        mediaContainerView.addSubview(mediaStackView)
        
        // Create media items
        for (index, urlString) in mediaURLs.enumerated() {
            guard let url = URL(string: urlString) else { continue }
            
            let mediaItemView = createMediaItemView(url: url, index: index)
            mediaStackView.addArrangedSubview(mediaItemView)
        }
        
        NSLayoutConstraint.activate([
            mediaLabel.topAnchor.constraint(equalTo: mediaContainerView.topAnchor),
            mediaLabel.leadingAnchor.constraint(equalTo: mediaContainerView.leadingAnchor),
            mediaLabel.trailingAnchor.constraint(equalTo: mediaContainerView.trailingAnchor),
            
            mediaStackView.topAnchor.constraint(equalTo: mediaLabel.bottomAnchor, constant: 8),
            mediaStackView.leadingAnchor.constraint(equalTo: mediaContainerView.leadingAnchor),
            mediaStackView.trailingAnchor.constraint(equalTo: mediaContainerView.trailingAnchor),
            mediaStackView.bottomAnchor.constraint(equalTo: mediaContainerView.bottomAnchor)
        ])
        
        return mediaContainerView
    }
    
    private func createMediaItemView(url: URL, index: Int) -> UIView {
        let itemView = UIView()
        itemView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        itemView.layer.cornerRadius = 8
        itemView.translatesAutoresizingMaskIntoConstraints = false
        
        let thumbnailImageView = UIImageView()
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 6
        thumbnailImageView.backgroundColor = UIColor.darkGray
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let mediaTypeLabel = UILabel()
        mediaTypeLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        mediaTypeLabel.textColor = .lightGray
        mediaTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let viewButton = UIButton(type: .system)
        viewButton.setTitle("View", for: .normal)
        viewButton.setTitleColor(brandColor, for: .normal)
        viewButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        viewButton.layer.borderColor = brandColor.cgColor
        viewButton.layer.borderWidth = 1
        viewButton.layer.cornerRadius = 6
        viewButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Determine media type and set up accordingly
        let fileExtension = url.pathExtension.lowercased()
        let isVideo = ["mp4", "mov", "avi", "m4v"].contains(fileExtension)
        
        if isVideo {
            mediaTypeLabel.text = "🎥 Video"
            thumbnailImageView.image = UIImage(systemName: "play.rectangle.fill")
            thumbnailImageView.tintColor = brandColor
            thumbnailImageView.contentMode = .scaleAspectFit
            
            viewButton.addTarget(self, action: #selector(playVideo(_:)), for: .touchUpInside)
        } else {
            mediaTypeLabel.text = "🖼️ Image"
            thumbnailImageView.sd_setImage(with: url, placeholderImage: UIImage(systemName: "photo"))
            
            viewButton.addTarget(self, action: #selector(viewImage(_:)), for: .touchUpInside)
        }
        
        viewButton.tag = index
        
        // Store URL in button for retrieval
        objc_setAssociatedObject(viewButton, "mediaURL", url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        itemView.addSubview(thumbnailImageView)
        itemView.addSubview(mediaTypeLabel)
        itemView.addSubview(viewButton)
        
        NSLayoutConstraint.activate([
            itemView.heightAnchor.constraint(equalToConstant: 80),
            
            thumbnailImageView.leadingAnchor.constraint(equalTo: itemView.leadingAnchor, constant: 10),
            thumbnailImageView.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),
            
            mediaTypeLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 10),
            mediaTypeLabel.topAnchor.constraint(equalTo: itemView.topAnchor, constant: 15),
            
            viewButton.trailingAnchor.constraint(equalTo: itemView.trailingAnchor, constant: -10),
            viewButton.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
            viewButton.widthAnchor.constraint(equalToConstant: 60),
            viewButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        return itemView
    }
    
    // MARK: - Media Actions
    
    @objc private func viewImage(_ sender: UIButton) {
        guard let url = objc_getAssociatedObject(sender, "mediaURL") as? URL else { return }
        
        let imageVC = UIViewController()
        imageVC.view.backgroundColor = .black
        imageVC.modalPresentationStyle = .fullScreen
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.sd_setImage(with: url)
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 20
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(dismissImageViewer), for: .touchUpInside)
        
        imageVC.view.addSubview(imageView)
        imageVC.view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: imageVC.view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: imageVC.view.centerYAnchor),
            imageView.leadingAnchor.constraint(greaterThanOrEqualTo: imageVC.view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(lessThanOrEqualTo: imageVC.view.trailingAnchor, constant: -20),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: imageVC.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: imageVC.view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            closeButton.topAnchor.constraint(equalTo: imageVC.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: imageVC.view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        present(imageVC, animated: true)
    }
    
    @objc private func playVideo(_ sender: UIButton) {
        guard let url = objc_getAssociatedObject(sender, "mediaURL") as? URL else { return }
        
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        present(playerViewController, animated: true) {
            player.play()
        }
    }
    
    @objc private func dismissImageViewer() {
        dismiss(animated: true)
    }
    
    // MARK: - Actions
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}
