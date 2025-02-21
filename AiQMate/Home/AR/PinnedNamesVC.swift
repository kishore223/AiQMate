import UIKit
import FirebaseFirestore
import FirebaseStorage

// MARK: - GradientLabelAR (Gradient Label)
class GradientLabelAR: UILabel {
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

// MARK: - Data Models

// Step model: Each step has text and multiple media URLs
struct Step {
    var text: String
    var mediaURLs: [String]
    
    func toDictionary() -> [String: Any] {
        return [
            "text": text,
            "mediaURLs": mediaURLs
        ]
    }
}

// DetailedAdditionalInfo model: Title and array of steps
struct DetailedAdditionalInfo {
    var title: String
    var steps: [Step]
    
    func toDictionary() -> [String: Any] {
        let stepsArray = steps.map { $0.toDictionary() }
        return [
            "title": title,
            "steps": stepsArray
        ]
    }
}

// MARK: - PinnedNamesVC

class PinnedNamesVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // Array of annotations passed from ObjectDetectionVC
    var annotations: [Annotation] = []
    
    // Title for the container
    var containerTitle: String = "Annotations"
    
    // Dictionary storing detailed infos keyed by annotation.id
    private var detailedInfos: [String: DetailedAdditionalInfo] = [:]
    
    // Gradient colors
    private let backgroundColorTop = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0).cgColor
    private let backgroundColorBottom = UIColor(red: 0/255, green: 40/255, blue: 50/255, alpha: 1.0).cgColor
    
    // UI Elements
    private let titleLabel: GradientLabelAR = {
        let label = GradientLabelAR()
        label.text = ""
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
    
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup gradient background
        setupBackgroundGradient()
        
        // Setup title label
        titleLabel.text = containerTitle
        view.addSubview(titleLabel)
        
        // Setup table view
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Start gradient animation
        titleLabel.startAnimatingGradient()
        
        // Load existing detailed infos from Firestore
        loadAllDetailedInfos()
    }
    
    // MARK: - Setup Methods
    
    private func setupBackgroundGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [backgroundColorTop, backgroundColorBottom]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    // MARK: - Firestore Loading
    
    private func loadAllDetailedInfos() {
        let db = Firestore.firestore()
        let annotationIDs = annotations.map { $0.id }
        
        db.collection("annotationDetailedInfos").getDocuments { snapshot, error in
            if let error = error {
                print("Error loading detailed infos: \(error.localizedDescription)")
                return
            }
            guard let snapshot = snapshot else { return }
            
            for doc in snapshot.documents {
                let docID = doc.documentID
                if annotationIDs.contains(docID) {
                    let dict = doc.data()
                    let title = dict["title"] as? String ?? ""
                    let stepsArray = dict["steps"] as? [[String: Any]] ?? []
                    
                    var steps: [Step] = []
                    for stepDict in stepsArray {
                        let stepText = stepDict["text"] as? String ?? ""
                        let mediaURLs = stepDict["mediaURLs"] as? [String] ?? []
                        steps.append(Step(text: stepText, mediaURLs: mediaURLs))
                    }
                    
                    let info = DetailedAdditionalInfo(title: title, steps: steps)
                    self.detailedInfos[docID] = info
                }
            }
            self.tableView.reloadData()
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return annotations.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell  = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = .clear
        
        let annot = annotations[indexPath.row]
        cell.textLabel?.text = annot.text
        cell.textLabel?.textColor = .white
        
        // Create a "Create"/"Edit" button on the right side
        let createEditButton = UIButton(type: .system)
        createEditButton.setTitleColor(.systemYellow, for: .normal)
        createEditButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        
        // If we already have data for this annotation, show "Edit", else "Create"
        if detailedInfos[annot.id] != nil {
            createEditButton.setTitle("Edit", for: .normal)
        } else {
            createEditButton.setTitle("Create", for: .normal)
        }
        
        createEditButton.addTarget(self, action: #selector(didTapCreateEditButton(_:)), for: .touchUpInside)
        createEditButton.tag = indexPath.row  // store row index for reference
        
        // Adjust size
        createEditButton.sizeToFit()
        cell.accessoryView = createEditButton
        
        return cell
    }
    
    // MARK: - Button Action
    
    @objc private func didTapCreateEditButton(_ sender: UIButton) {
        let rowIndex = sender.tag
        let annotation = annotations[rowIndex]
        
        // Initialize the editor with existing info if available
        let editorVC = AdditionalInfoEditorVC(annotationID: annotation.id,
                                              existingInfo: detailedInfos[annotation.id])
        editorVC.onSave = { [weak self] updatedInfo in
            guard let self = self else { return }
            // Store in memory
            self.detailedInfos[annotation.id] = updatedInfo
            // Save to Firestore
            self.saveDetailedInfoToFirebase(annotationID: annotation.id, info: updatedInfo)
            // Refresh
            self.tableView.reloadData()
        }
        
        navigationController?.pushViewController(editorVC, animated: true)
    }
    
    // MARK: - Firestore Saving
    
    private func saveDetailedInfoToFirebase(annotationID: String, info: DetailedAdditionalInfo) {
        let db = Firestore.firestore()
        db.collection("annotationDetailedInfos")
            .document(annotationID)
            .setData(info.toDictionary()) { error in
                if let error = error {
                    print("Error saving detailed info: \(error.localizedDescription)")
                } else {
                    print("Detailed info saved for annotationID = \(annotationID)")
                }
            }
    }
}

// MARK: - AdditionalInfoEditorVC

private class AdditionalInfoEditorVC: UIViewController,
                                      UITableViewDataSource,
                                      UITableViewDelegate,
                                      UIImagePickerControllerDelegate,
                                      UINavigationControllerDelegate {
    
    // Callback to pass back the updated info
    var onSave: ((DetailedAdditionalInfo) -> Void)?
    
    // The annotation ID we're editing
    private let annotationID: String
    
    // The data structure we'll edit
    private var detailedInfo: DetailedAdditionalInfo
    
    // Gradient label at the top
    private let topLabel: GradientLabelAR = {
        let label = GradientLabelAR()
        label.text = "Write Detailed Info"
        label.font = UIFont(name: "AvenirNext-Bold", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.4
        label.layer.shadowOffset = CGSize(width: 2, height: 2)
        label.layer.shadowRadius = 3
        label.layer.masksToBounds = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Gradient colors
    private let backgroundColorTop = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0).cgColor
    private let backgroundColorBottom = UIColor(red: 0/255, green: 40/255, blue: 50/255, alpha: 1.0).cgColor
    
    // UI Elements
    private let titleTextField = UITextField()
    private let stepsTableView = UITableView()
    private let addStepButton  = UIButton(type: .system)
    
    // To remember which step's media we are adding
    private var currentStepIndexForMedia: Int?
    
    // MARK: - Init
    init(annotationID: String, existingInfo: DetailedAdditionalInfo?) {
        self.annotationID = annotationID
        if let info = existingInfo {
            self.detailedInfo = info
        } else {
            self.detailedInfo = DetailedAdditionalInfo(title: "", steps: [])
        }
        super.init(nibName: nil, bundle: nil)
        
        self.title = "Detailed Info"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup the gradient background
        setupBackgroundGradient()
        
        // Setup top label
        view.addSubview(topLabel)
        NSLayoutConstraint.activate([
            topLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            topLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        // Navigation bar "Save" button
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save,
                                                            target: self,
                                                            action: #selector(didTapSave))
        
        // Setup UI
        setupUI()
        
        // Start gradient animation
        topLabel.startAnimatingGradient()
    }
    
    private func setupBackgroundGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [backgroundColorTop, backgroundColorBottom]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func setupUI() {
        // Title TextField
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        titleTextField.placeholder = "Enter Title Here"
        titleTextField.borderStyle = .roundedRect
        titleTextField.text = detailedInfo.title
        
        // Steps TableView
        stepsTableView.translatesAutoresizingMaskIntoConstraints = false
        stepsTableView.dataSource = self
        stepsTableView.delegate   = self
        stepsTableView.register(StepCell.self, forCellReuseIdentifier: "StepCell")
        stepsTableView.backgroundColor = .clear
        stepsTableView.tableFooterView = UIView()
        
        // Add Step Button
        addStepButton.setTitle("+ Add Step", for: .normal)
        addStepButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        addStepButton.addTarget(self, action: #selector(didTapAddStep), for: .touchUpInside)
        addStepButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        view.addSubview(titleTextField)
        view.addSubview(addStepButton)
        view.addSubview(stepsTableView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Title TextField below topLabel
            titleTextField.topAnchor.constraint(equalTo: topLabel.bottomAnchor, constant: 16),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Add Step Button
            addStepButton.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 16),
            addStepButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            // Steps TableView
            stepsTableView.topAnchor.constraint(equalTo: addStepButton.bottomAnchor, constant: 16),
            stepsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stepsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stepsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    // MARK: - Actions
    @objc private func didTapAddStep() {
        detailedInfo.steps.append(Step(text: "", mediaURLs: []))
        stepsTableView.reloadData()
    }
    
    @objc private func didTapSave() {
        // Grab the title from the textfield
        detailedInfo.title = titleTextField.text ?? ""
        
        // Pass back to the parent
        onSave?(detailedInfo)
        
        // Pop the view controller
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detailedInfo.steps.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "StepCell", for: indexPath) as? StepCell else {
            return UITableViewCell()
        }
        
        let step = detailedInfo.steps[indexPath.row]
        cell.configure(step: step, index: indexPath.row)
        
        // Callbacks
        cell.onTextChanged = { [weak self] newText, stepIndex in
            guard let self = self else { return }
            self.detailedInfo.steps[stepIndex].text = newText
        }
        
        cell.onAddMediaTapped = { [weak self] stepIndex in
            guard let self = self else { return }
            self.currentStepIndexForMedia = stepIndex
            self.showImagePicker()
        }
        
        return cell
    }
    
    // MARK: - Image Picker
    
    private func showImagePicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        guard let stepIndex = currentStepIndexForMedia else {
            picker.dismiss(animated: true)
            return
        }
        picker.dismiss(animated: true)
        
        // Get the image
        guard let image = info[.originalImage] as? UIImage else { return }
        // Compress the image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        
        // Upload to Firebase Storage
        let storageRef = Storage.storage().reference()
        let fileName = "\(UUID().uuidString).jpg"
        let imageRef = storageRef.child("detailedStepsMedia").child(fileName)
        
        imageRef.putData(imageData, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                print("Error uploading media: \(error.localizedDescription)")
                return
            }
            imageRef.downloadURL { url, error in
                if let error = error {
                    print("Error fetching downloadURL: \(error.localizedDescription)")
                    return
                }
                guard let downloadURL = url else { return }
                
                DispatchQueue.main.async {
                    self?.detailedInfo.steps[stepIndex].mediaURLs.append(downloadURL.absoluteString)
                    self?.stepsTableView.reloadRows(at: [IndexPath(row: stepIndex, section: 0)], with: .automatic)
                }
            }
        }
    }
}

// MARK: - StepCell

private class StepCell: UITableViewCell {
    
    // Callbacks
    var onTextChanged: ((String, Int) -> Void)?
    var onAddMediaTapped: ((Int) -> Void)?
    
    // UI Elements
    private let stepTextView = UITextView()
    private let addMediaButton = UIButton(type: .system)
    private let mediaCollectionView: UICollectionView
    
    // Data
    private var mediaURLs: [String] = []
    private var stepIndex: Int = 0
    
    // Reuse Identifier
    private let mediaCellIdentifier = "StepMediaCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        
        // Setup Collection View Layout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 80, height: 80)
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        mediaCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        mediaCollectionView.translatesAutoresizingMaskIntoConstraints = false
        mediaCollectionView.backgroundColor = .clear
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        
        // Configure stepTextView
        stepTextView.translatesAutoresizingMaskIntoConstraints = false
        stepTextView.font = UIFont.systemFont(ofSize: 16)
        stepTextView.layer.borderColor = UIColor.lightGray.cgColor
        stepTextView.layer.borderWidth = 1
        stepTextView.layer.cornerRadius = 4
        stepTextView.delegate = self
        
        // Configure addMediaButton
        addMediaButton.translatesAutoresizingMaskIntoConstraints = false
        addMediaButton.setTitle("Add Media", for: .normal)
        addMediaButton.addTarget(self, action: #selector(didTapAddMedia), for: .touchUpInside)
        
        // Configure mediaCollectionView
        mediaCollectionView.dataSource = self
        mediaCollectionView.delegate   = self
        mediaCollectionView.register(StepMediaCell.self, forCellWithReuseIdentifier: mediaCellIdentifier)
        mediaCollectionView.showsHorizontalScrollIndicator = false
        
        // Add subviews
        contentView.addSubview(stepTextView)
        contentView.addSubview(addMediaButton)
        contentView.addSubview(mediaCollectionView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            stepTextView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stepTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stepTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stepTextView.heightAnchor.constraint(equalToConstant: 80),
            
            addMediaButton.topAnchor.constraint(equalTo: stepTextView.bottomAnchor, constant: 8),
            addMediaButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            addMediaButton.heightAnchor.constraint(equalToConstant: 30),
            
            mediaCollectionView.topAnchor.constraint(equalTo: addMediaButton.bottomAnchor, constant: 8),
            mediaCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mediaCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mediaCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            mediaCollectionView.heightAnchor.constraint(equalToConstant: 80),
        ])
    }
    
    @objc private func didTapAddMedia() {
        onAddMediaTapped?(stepIndex)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Configure cell with step data
    func configure(step: Step, index: Int) {
        stepIndex = index
        stepTextView.text = step.text
        mediaURLs = step.mediaURLs
        mediaCollectionView.reloadData()
    }
}

// MARK: - UITextViewDelegate
extension StepCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        onTextChanged?(textView.text, stepIndex)
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension StepCell: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mediaURLs.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StepMediaCell", for: indexPath) as? StepMediaCell else {
            return UICollectionViewCell()
        }
        let urlString = mediaURLs[indexPath.item]
        cell.configure(with: urlString)
        return cell
    }
    
    // Optional: Handle media tap (e.g., to view full image)
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Implement as needed
    }
}

// MARK: - StepMediaCell

private class StepMediaCell: UICollectionViewCell {
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 8
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    // Placeholder image
    private let placeholderImage = UIImage(systemName: "photo")?.withTintColor(.lightGray, renderingMode: .alwaysOriginal)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        
        imageView.image = placeholderImage
    }
    
    func configure(with urlString: String) {
        imageView.image = placeholderImage
        guard let url = URL(string: urlString) else { return }
        
        // Fetch image asynchronously
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
