import UIKit
import AVFoundation
import FirebaseStorage
import FirebaseFirestore
import SDWebImage
import ARKit

// MARK: - GradientLabel

class GradientLabel: UILabel {
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    private func setupGradient() {
        gradientLayer.colors = [
            UIColor(red: 0/255, green: 204/255, blue: 204/255, alpha: 1.0).cgColor,
            UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 0.5)
        gradientLayer.locations  = [0, 1]
        
        layer.addSublayer(gradientLayer)
        layer.mask = textLayer()
    }
    
    private func textLayer() -> CALayer {
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = font
        textLayer.fontSize = font.pointSize
        textLayer.alignmentMode = .center
        textLayer.foregroundColor = UIColor.black.cgColor
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.frame = bounds
        return textLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        layer.mask = textLayer()
    }
    
    func startAnimatingGradient() {
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0, 0.5, 1]
        animation.toValue   = [0.5, 1, 1.5]
        animation.duration  = 4
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "gradientAnimation")
    }
}

// MARK: - HomeViewController

class HomeViewController: UIViewController {
    
    // MARK: - Properties
    
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    
    private let titleLabel: GradientLabel = {
        let label = GradientLabel()
        label.text = "Home"
        label.font = UIFont(name: "AvenirNext-Bold", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.4
        label.layer.shadowOffset = CGSize(width: 2, height: 2)
        label.layer.shadowRadius = 3
        label.layer.masksToBounds = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// A **floating** “Create Anchor” button at the bottom-right corner
    private let createAnchorButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("", for: .normal) // We'll show icon only
        button.tintColor = .white
        button.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold, scale: .large)
        let plusImage   = UIImage(systemName: "plus", withConfiguration: largeConfig)
        button.setImage(plusImage, for: .normal)
        
        button.layer.cornerRadius = 30
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 5
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Filter states (optional)
    private var selectedSite: String?
    private var selectedSection: String?
    private var selectedSubsection: String?
    
    // Filter options (populated from Firestore)
    private var allSites: [String] = []
    private var allSections: [String] = []
    private var allSubsections: [String] = []
    
    // The categories we want
    private let categories = ["Troubleshooting", "Guide", "Daily Routine"]
    
    // Holds the images keyed by category type
    private var categoryData: [String: [ImageItem]] = [:]
    
    // CollectionView references for each category
    private var categoryCollectionViews: [String: UICollectionView] = [:]
    
    // **New**: array for favorites
    private var favorites: [ImageItem] = []
    
    // A dedicated collection view for favorites (story style)
    private var favoritesCollectionView: UICollectionView?
    
    // Scroll & content
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBackgroundGradient()
        setupViews()
        setupConstraints()
        setupActions()
        setupGesture()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Fetch data
        fetchFilterOptions()
        fetchImagesFromFirebase()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        titleLabel.startAnimatingGradient()
    }
    
    // MARK: - Setup
    
    private func setupBackgroundGradient() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0).cgColor,
            UIColor(red: 0/255, green: 40/255, blue: 50/255, alpha: 1.0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint   = CGPoint(x: 1, y: 1)
        gradient.frame = view.bounds
        view.layer.insertSublayer(gradient, at: 0)
    }
    
    private func setupViews() {
        // Title at the top
        view.addSubview(titleLabel)
        
        // Scroll & content
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Floating button on top of everything
        view.addSubview(createAnchorButton)
        
        // 1) Create and add "Favorites" container at the very top
        let favoritesContainer = createFavoritesContainer()
        contentView.addArrangedSubview(favoritesContainer)
        
        // 2) Create a “card” for each category
        for cat in categories {
            let card = createCategoryCard(title: cat)
            contentView.addArrangedSubview(card)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // ContentView inside scroll
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
            
            // Floating button (bottom-right)
            createAnchorButton.widthAnchor.constraint(equalToConstant: 60),
            createAnchorButton.heightAnchor.constraint(equalToConstant: 60),
            createAnchorButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            createAnchorButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        createAnchorButton.addTarget(self, action: #selector(createAnchorTapped), for: .touchUpInside)
    }
    
    private func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(titleTapped))
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(tap)
    }
    
    // MARK: - Favorites Container
    
    /// Creates a "Favorites" section that scrolls horizontally
    private func createFavoritesContainer() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // A label: "Favorites"
        let favLabel = UILabel()
        favLabel.text = "Favorites"
        favLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        favLabel.textColor = .white
        favLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(favLabel)
        
        // CollectionView for favorites
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 60, height: 80)  // circle ~ 60x60 + label space
        layout.minimumLineSpacing = 12
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Register our custom FavoriteCell
        collectionView.register(FavoriteCell.self, forCellWithReuseIdentifier: "FavoriteCell")
        collectionView.dataSource = self
        collectionView.delegate   = self
        
        favoritesCollectionView = collectionView
        
        container.addSubview(collectionView)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Fav label top
            favLabel.topAnchor.constraint(equalTo: container.topAnchor),
            favLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            // CollectionView
            collectionView.topAnchor.constraint(equalTo: favLabel.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 90),
            // bottom of container
            collectionView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - Category Cards
    
    private func createCategoryCard(title: String) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor(white: 1, alpha: 0.06)
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowOpacity = 0.3
        cardView.layer.shadowRadius = 4
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.alignment = .fill
        cardStack.distribution = .fill
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Header: label + "Show All Anchor"
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .equalSpacing
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        let catLabel = UILabel()
        catLabel.text = title
        catLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        catLabel.textColor = .white
        
        let showAllButton = UIButton(type: .system)
        showAllButton.setTitle("Show All Anchor", for: .normal)
        showAllButton.setTitleColor(brandColor, for: .normal)
        showAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        if let index = categories.firstIndex(of: title) {
            showAllButton.tag = index
        }
        showAllButton.addTarget(self, action: #selector(showAllButtonTapped(_:)), for: .touchUpInside)
        
        headerStack.addArrangedSubview(catLabel)
        headerStack.addArrangedSubview(showAllButton)
        
        // Circle-based stats for this category
        let circleView = createCircleStatsView(for: title)
        
        // Collection view below the circle stats
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 110, height: 40)
        layout.minimumLineSpacing = 10
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(ItemCell.self, forCellWithReuseIdentifier: "ItemCell")
        collectionView.dataSource = self
        collectionView.delegate   = self
        
        // Store reference to reloading this CV
        categoryCollectionViews[title] = collectionView
        
        // Add all components to stack
        cardStack.addArrangedSubview(headerStack)
        cardStack.addArrangedSubview(circleView)
        cardStack.addArrangedSubview(collectionView)
        
        cardView.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12)
        ])
        
        return cardView
    }
    
    /// Circle stats row (Anchors, Annotations, Procedures, AI Procedures) for a given category.
    /// Instead of fetching from Firestore, we'll **generate random** values for each.
    private func createCircleStatsView(for category: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let circleStack = UIStackView()
        circleStack.axis = .horizontal
        circleStack.alignment = .center
        circleStack.distribution = .equalSpacing
        circleStack.spacing = 16
        circleStack.translatesAutoresizingMaskIntoConstraints = false
        
        let metrics = ["Anchors", "Annotations", "Procedures", "AIProc"]
        
        // Random values per metric (e.g., 0..20)
        let anchors = CGFloat(Int.random(in: 0...20))
        let annotations = CGFloat(Int.random(in: 0...20))
        let procedures = CGFloat(Int.random(in: 0...20))
        let aiProcedures = CGFloat(Int.random(in: 0...20))
        
        let actualValues = [anchors, annotations, procedures, aiProcedures]
        let maxValue = (actualValues.max() ?? 1)
        
        for (index, metricName) in metrics.enumerated() {
            let ringView = createCircleRing(
                value: actualValues[index],
                maxValue: maxValue,
                metricName: metricName
            )
            circleStack.addArrangedSubview(ringView)
        }
        
        container.addSubview(circleStack)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 100),
            circleStack.topAnchor.constraint(equalTo: container.topAnchor),
            circleStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            circleStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            circleStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        
        return container
    }
    
    /// Single ring for each metric
    private func createCircleRing(value: CGFloat,
                                  maxValue: CGFloat,
                                  metricName: String) -> UIView {
        let circleSize: CGFloat = 60
        let ringThickness: CGFloat = 6
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: circleSize).isActive = true
        container.heightAnchor.constraint(equalToConstant: circleSize + 25).isActive = true
        
        let countLabel = UILabel()
        countLabel.text = "\(Int(value))"
        countLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        countLabel.textColor = .white
        countLabel.textAlignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let metricLabel = UILabel()
        metricLabel.text = metricName
        metricLabel.font = UIFont.systemFont(ofSize: 8, weight: .regular)
        metricLabel.textColor = .lightGray
        metricLabel.textAlignment = .center
        metricLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let progressLayer = CAShapeLayer()
        let backgroundLayer = CAShapeLayer()
        
        let centerPoint = CGPoint(x: circleSize / 2, y: circleSize / 2)
        let circlePath = UIBezierPath(
            arcCenter: centerPoint,
            radius: (circleSize - ringThickness) / 2,
            startAngle: -CGFloat.pi/2,
            endAngle: CGFloat.pi * 3/2,
            clockwise: true
        )
        
        // Background ring
        backgroundLayer.path = circlePath.cgPath
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = UIColor.darkGray.withAlphaComponent(0.3).cgColor
        backgroundLayer.lineWidth = ringThickness
        
        // Foreground progress
        progressLayer.path = circlePath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = brandColor.cgColor
        progressLayer.lineWidth = ringThickness
        progressLayer.strokeEnd = 0
        
        // Animate from 0..(value/maxValue)
        let ratio = (maxValue > 0) ? (value / maxValue) : 0
        let animateStroke = CABasicAnimation(keyPath: "strokeEnd")
        animateStroke.fromValue = 0
        animateStroke.toValue   = ratio
        animateStroke.duration  = 0.7
        animateStroke.timingFunction = CAMediaTimingFunction(name: .easeOut)
        progressLayer.add(animateStroke, forKey: "progressAnim")
        progressLayer.strokeEnd = ratio
        
        let ringContainer = UIView(frame: CGRect(x: 0, y: 0, width: circleSize, height: circleSize))
        ringContainer.translatesAutoresizingMaskIntoConstraints = false
        ringContainer.layer.addSublayer(backgroundLayer)
        ringContainer.layer.addSublayer(progressLayer)
        
        container.addSubview(ringContainer)
        container.addSubview(countLabel)
        container.addSubview(metricLabel)
        
        NSLayoutConstraint.activate([
            ringContainer.topAnchor.constraint(equalTo: container.topAnchor),
            ringContainer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ringContainer.widthAnchor.constraint(equalToConstant: circleSize),
            ringContainer.heightAnchor.constraint(equalToConstant: circleSize),
            
            countLabel.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: ringContainer.centerYAnchor),
            
            metricLabel.topAnchor.constraint(equalTo: ringContainer.bottomAnchor, constant: 2),
            metricLabel.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor)
        ])
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func createAnchorTapped() {
        checkCameraPermission()
    }
    
    @objc private func titleTapped() {
        let pulse = CASpringAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue   = 1.05
        pulse.duration  = pulse.settlingDuration
        pulse.autoreverses = true
        pulse.initialVelocity = 0.5
        pulse.damping = 1.0
        titleLabel.layer.add(pulse, forKey: "pulse")
    }
    
    @objc private func showAllButtonTapped(_ sender: UIButton) {
        let categoryTitle = categories[sender.tag]
        let items = categoryData[categoryTitle] ?? []
        
        let categoryListVC = CategoryListViewController(categoryName: categoryTitle, imageItems: items)
        let navController = UINavigationController(rootViewController: categoryListVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // MARK: - Data / Firebase
    
    /// Loads images from Firestore "images" collection, filtered if needed.
    private func fetchImagesFromFirebase() {
        let db = Firestore.firestore()
        var query: Query = db.collection("images")
        
        // Optional filter by site, section, subsection
        if let site = selectedSite {
            query = query.whereField("site", isEqualTo: site)
        }
        if let section = selectedSection {
            query = query.whereField("section", isEqualTo: section)
        }
        if let subsection = selectedSubsection {
            query = query.whereField("subsection", isEqualTo: subsection)
        }
        
        query.getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            self?.categoryData = [:]
            self?.favorites = []  // reset favorites
            for doc in snapshot?.documents ?? [] {
                let data = doc.data()
                guard
                    let name = data["name"] as? String,
                    let type = data["type"] as? String,
                    let site = data["site"] as? String,
                    let section = data["section"] as? String,
                    let subsection = data["subsection"] as? String,
                    let urlString = data["url"] as? String,
                    let url = URL(string: urlString)
                else {
                    continue
                }
                
                let isFavorite = data["isFavorite"] as? Bool ?? false
                
                // Build item
                let imageItem = ImageItem(
                    id: doc.documentID,
                    name: name,
                    imageURL: url,
                    site: site,
                    section: section,
                    subsection: subsection,
                    type: type,
                    isFavorite: isFavorite
                )
                
                // If favorite, store in favorites array
                if isFavorite {
                    self?.favorites.append(imageItem)
                }
                
                // Also store by category
                self?.categoryData[type, default: []].append(imageItem)
            }
            
            DispatchQueue.main.async {
                // Reload normal category collection views
                self?.reloadAllCollectionViews()
                
                // Reload the favorites collection
                self?.favoritesCollectionView?.reloadData()
            }
        }
    }
    
    /// Fetches possible filter options (sites, sections, etc.), so the user can filter if desired
    private func fetchFilterOptions() {
        let db = Firestore.firestore()
        db.collection("images").getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Error fetching filter options: \(error.localizedDescription)")
                return
            }
            
            var sitesSet = Set<String>()
            var sectionsSet = Set<String>()
            var subsectionsSet = Set<String>()
            
            for doc in snapshot?.documents ?? [] {
                let data = doc.data()
                if let site = data["site"] as? String,
                   let section = data["section"] as? String,
                   let subsection = data["subsection"] as? String {
                    sitesSet.insert(site)
                    sectionsSet.insert(section)
                    subsectionsSet.insert(subsection)
                }
            }
            
            self?.allSites      = ["All Sites"] + Array(sitesSet).sorted()
            self?.allSections   = ["All Sections"] + Array(sectionsSet).sorted()
            self?.allSubsections = ["All Subsections"] + Array(subsectionsSet).sorted()
        }
    }
    
    /// Reload collection views after data changes
    private func reloadAllCollectionViews() {
        for (_, collectionView) in categoryCollectionViews {
            collectionView.reloadData()
        }
    }
    
    // MARK: - Camera Permission & Image Picker
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentCamera()
                    } else {
                        self?.presentCameraPermissionAlert()
                    }
                }
            }
        case .denied, .restricted:
            presentCameraPermissionAlert()
        @unknown default:
            break
        }
    }
    
    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate   = self
        present(picker, animated: true)
    }
    
    private func presentCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please grant camera access in Settings to use this feature.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate

extension HomeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let image = info[.originalImage] as? UIImage {
            let detailsVC = ImageDetailsViewController(image: image) { [weak self] name, type, site, section, subsection in
                self?.saveImageToFirebase(image,
                                          name: name,
                                          type: type,
                                          site: site,
                                          section: section,
                                          subsection: subsection)
            }
            let navController = UINavigationController(rootViewController: detailsVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
    }
    
    private func saveImageToFirebase(_ image: UIImage,
                                     name: String,
                                     type: String,
                                     site: String,
                                     section: String,
                                     subsection: String) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let storageRef = Storage.storage().reference()
            .child("images/\(UUID().uuidString).jpg")
        
        storageRef.putData(imageData, metadata: nil) { [weak self] (_, error) in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                return
            }
            
            storageRef.downloadURL { (url, error) in
                guard let downloadURL = url else { return }
                
                let db = Firestore.firestore()
                let docRef = db.collection("images").document()
                docRef.setData([
                    "name": name,
                    "type": type,
                    "site": site,
                    "section": section,
                    "subsection": subsection,
                    "url": downloadURL.absoluteString,
                    "timestamp": FieldValue.serverTimestamp(),
                    "isFavorite": false
                ]) { error in
                    if let error = error {
                        print("Error saving image data: \(error.localizedDescription)")
                    } else {
                        print("Image data saved successfully")
                        let imageItem = ImageItem(
                            id: docRef.documentID,
                            name: name,
                            imageURL: downloadURL,
                            site: site,
                            section: section,
                            subsection: subsection,
                            type: type,
                            isFavorite: false
                        )
                        self?.addImageToCategory(imageItem)
                    }
                }
            }
        }
    }
    
    private func addImageToCategory(_ imageItem: ImageItem) {
        // Only add if it matches current filters
        if let site = selectedSite, site != imageItem.site { return }
        if let section = selectedSection, section != imageItem.section { return }
        if let subsection = selectedSubsection, subsection != imageItem.subsection { return }
        
        // If it's favorite, add to favorites array
        if imageItem.isFavorite {
            favorites.append(imageItem)
        }
        
        categoryData[imageItem.type, default: []].append(imageItem)
        DispatchQueue.main.async {
            // Reload the relevant category's collection
            if let collectionView = self.categoryCollectionViews[imageItem.type] {
                collectionView.reloadData()
            }
            // Reload favorites
            self.favoritesCollectionView?.reloadData()
        }
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate

extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // If this is our favoritesCollectionView
        if collectionView == favoritesCollectionView {
            return favorites.count
        }
        
        // Otherwise it's one of the category collectionViews
        guard let catEntry = categoryCollectionViews.first(where: { $0.value == collectionView }) else {
            return 0
        }
        let catName = catEntry.key
        return categoryData[catName]?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Favorites
        if collectionView == favoritesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FavoriteCell",
                                                          for: indexPath) as! FavoriteCell
            let item = favorites[indexPath.item]
            cell.configure(with: item)
            return cell
        }
        
        // Normal categories
        guard let catEntry = categoryCollectionViews.first(where: { $0.value == collectionView }) else {
            return UICollectionViewCell()
        }
        let catName = catEntry.key
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ItemCell",
                                                      for: indexPath) as! ItemCell
        
        let items = categoryData[catName] ?? []
        let imageItem = items[indexPath.item]
        cell.configure(with: imageItem)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        if collectionView == favoritesCollectionView {
            let favorite = favorites[indexPath.item]
            print("Tapped favorite anchor: \(favorite.name)")
            // Possibly show details or AR view
            return
        }
        
        // Normal categories
        guard let catEntry = categoryCollectionViews.first(where: { $0.value == collectionView }) else {
            return
        }
        let catName = catEntry.key
        
        let items = categoryData[catName] ?? []
        let imageItem = items[indexPath.item]
        
        // Possibly present a detail screen or AR view
        print("Selected item: \(imageItem.name)")
    }
}

// MARK: - FavoriteCell (a circle cell “insta story” style)

class FavoriteCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let nameLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Circle for image
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 30 // half of 60
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Name label (optional)
        nameLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(imageView)
        contentView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            
            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with item: ImageItem) {
        // Load image (using SDWebImage or similar)
        imageView.sd_setImage(with: item.imageURL, placeholderImage: UIImage(systemName: "photo"))
        nameLabel.text = item.name
    }
}
