import UIKit
import FirebaseFirestore
import FirebaseStorage
import SDWebImage

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
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    
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
        tv.separatorStyle = .none
        tv.keyboardDismissMode = .onDrag
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
        tableView.register(EnhancedAnnotationCell.self, forCellReuseIdentifier: "cell")
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
        
        // Setup keyboard dismissal
        setupKeyboardDismissal()
        
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
    
    private func setupKeyboardDismissal() {
        // Tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
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
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return annotations.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! EnhancedAnnotationCell
        let annotation = annotations[indexPath.row]
        let hasDetailedInfo = detailedInfos[annotation.id] != nil
        
        cell.configure(with: annotation, hasDetailedInfo: hasDetailedInfo, brandColor: brandColor)
        
        cell.actionButtonTapped = { [weak self] in
            self?.handleAnnotationAction(annotation: annotation, at: indexPath)
        }
        
        return cell
    }
    
    // MARK: - Actions
    
    private func handleAnnotationAction(annotation: Annotation, at indexPath: IndexPath) {
        let editorVC = AdditionalInfoEditorVC(annotationID: annotation.id,
                                              existingInfo: detailedInfos[annotation.id])
        editorVC.onSave = { [weak self] updatedInfo in
            guard let self = self else { return }
            // Store in memory
            self.detailedInfos[annotation.id] = updatedInfo
            // Save to Firestore
            self.saveDetailedInfoToFirebase(annotationID: annotation.id, info: updatedInfo)
            // Refresh
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
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

// MARK: - Enhanced Annotation Cell

class EnhancedAnnotationCell: UITableViewCell {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 15/255, green: 12/255, blue: 50/255, alpha: 0.8)
        view.layer.cornerRadius = 15
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.3
        view.layer.shadowRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "mappin.circle.fill")
        imageView.tintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let annotationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = .lightGray
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    var actionButtonTapped: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(annotationLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(actionButton)
        containerView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),
            
            annotationLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            annotationLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            annotationLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -8),
            
            statusLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            statusLabel.widthAnchor.constraint(equalToConstant: 80),
            statusLabel.heightAnchor.constraint(equalToConstant: 20),
            
            actionButton.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            actionButton.topAnchor.constraint(equalTo: annotationLabel.bottomAnchor, constant: 8),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            actionButton.widthAnchor.constraint(equalToConstant: 100),
            actionButton.heightAnchor.constraint(equalToConstant: 32),
            
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        actionButton.addTarget(self, action: #selector(actionButtonPressed), for: .touchUpInside)
    }
    
    @objc private func actionButtonPressed() {
        actionButtonTapped?()
    }
    
    func configure(with annotation: Annotation, hasDetailedInfo: Bool, brandColor: UIColor) {
        annotationLabel.text = annotation.text
        
        if hasDetailedInfo {
            statusLabel.text = "Created"
            statusLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
            statusLabel.textColor = .systemGreen
            
            actionButton.setTitle("Edit", for: .normal)
            actionButton.backgroundColor = brandColor.withAlphaComponent(0.2)
            actionButton.setTitleColor(brandColor, for: .normal)
        } else {
            statusLabel.text = "Empty"
            statusLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.3)
            statusLabel.textColor = .systemOrange
            
            actionButton.setTitle("Create", for: .normal)
            actionButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
            actionButton.setTitleColor(.systemBlue, for: .normal)
        }
    }
}

// MARK: - Enhanced AdditionalInfoEditorVC

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
    
    // Colors
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    
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
    
    // UI Elements
    private let titleTextField = UITextField()
    private let stepsTableView = UITableView()
    private let addStepButton = UIButton(type: .system)
    
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
        
        // Setup keyboard handling
        setupKeyboardHandling()
        
        // Start gradient animation
        topLabel.startAnimatingGradient()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    
    private func setupBackgroundGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0).cgColor,
            UIColor(red: 0/255, green: 40/255, blue: 50/255, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func setupUI() {
        // Title TextField
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        titleTextField.placeholder = "Enter Title Here"
        titleTextField.backgroundColor = UIColor(red: 15/255, green: 12/255, blue: 50/255, alpha: 0.8)
        titleTextField.textColor = .white
        titleTextField.layer.cornerRadius = 12
        titleTextField.layer.borderWidth = 1
        titleTextField.layer.borderColor = brandColor.withAlphaComponent(0.3).cgColor
        titleTextField.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleTextField.text = detailedInfo.title
        titleTextField.returnKeyType = .done
        titleTextField.delegate = self
        
        // Add padding to text field
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: titleTextField.frame.height))
        titleTextField.leftView = paddingView
        titleTextField.leftViewMode = .always
        
        // Steps TableView
        stepsTableView.translatesAutoresizingMaskIntoConstraints = false
        stepsTableView.dataSource = self
        stepsTableView.delegate   = self
        stepsTableView.register(EnhancedStepCell.self, forCellReuseIdentifier: "StepCell")
        stepsTableView.backgroundColor = .clear
        stepsTableView.separatorStyle = .none
        stepsTableView.tableFooterView = UIView()
        stepsTableView.keyboardDismissMode = .onDrag
        
        // Add Step Button
        addStepButton.setTitle("+ Add Step", for: .normal)
        addStepButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        addStepButton.setTitleColor(.white, for: .normal)
        addStepButton.backgroundColor = brandColor
        addStepButton.layer.cornerRadius = 12
        addStepButton.layer.shadowColor = UIColor.black.cgColor
        addStepButton.layer.shadowOpacity = 0.3
        addStepButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        addStepButton.layer.shadowRadius = 4
        addStepButton.addTarget(self, action: #selector(didTapAddStep), for: .touchUpInside)
        addStepButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        view.addSubview(titleTextField)
        view.addSubview(addStepButton)
        view.addSubview(stepsTableView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Title TextField below topLabel
            titleTextField.topAnchor.constraint(equalTo: topLabel.bottomAnchor, constant: 20),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Add Step Button
            addStepButton.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 16),
            addStepButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            addStepButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addStepButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Steps TableView
            stepsTableView.topAnchor.constraint(equalTo: addStepButton.bottomAnchor, constant: 16),
            stepsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stepsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stepsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func setupKeyboardHandling() {
        // Tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // Keyboard notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        stepsTableView.contentInset = contentInsets
        stepsTableView.scrollIndicatorInsets = contentInsets
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let contentInsets = UIEdgeInsets.zero
        stepsTableView.contentInset = contentInsets
        stepsTableView.scrollIndicatorInsets = contentInsets
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Actions
    @objc private func didTapAddStep() {
        detailedInfo.steps.append(Step(text: "", mediaURLs: []))
        let newIndexPath = IndexPath(row: detailedInfo.steps.count - 1, section: 0)
        stepsTableView.insertRows(at: [newIndexPath], with: .automatic)
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
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "StepCell", for: indexPath) as? EnhancedStepCell else {
            return UITableViewCell()
        }
        
        let step = detailedInfo.steps[indexPath.row]
        cell.configure(step: step, index: indexPath.row, brandColor: brandColor)
        
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
        
        cell.onDeleteStepTapped = { [weak self] stepIndex in
            guard let self = self else { return }
            self.deleteStep(at: stepIndex)
        }
        
        cell.onDeleteMediaTapped = { [weak self] stepIndex, mediaIndex in
            guard let self = self else { return }
            self.deleteMedia(stepIndex: stepIndex, mediaIndex: mediaIndex)
        }
        
        return cell
    }
    
    // MARK: - Delete Functions
    
    private func deleteStep(at stepIndex: Int) {
        let alert = UIAlertController(title: "Delete Step",
                                    message: "Are you sure you want to delete this step?",
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            // Delete media files from Firebase Storage first
            let step = self.detailedInfo.steps[stepIndex]
            self.deleteMediaFiles(mediaURLs: step.mediaURLs) {
                DispatchQueue.main.async {
                    self.detailedInfo.steps.remove(at: stepIndex)
                    let indexPath = IndexPath(row: stepIndex, section: 0)
                    self.stepsTableView.deleteRows(at: [indexPath], with: .automatic)
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    private func deleteMedia(stepIndex: Int, mediaIndex: Int) {
        let alert = UIAlertController(title: "Delete Media",
                                    message: "Are you sure you want to delete this media?",
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            let mediaURL = self.detailedInfo.steps[stepIndex].mediaURLs[mediaIndex]
            
            // Delete from Firebase Storage
            self.deleteMediaFiles(mediaURLs: [mediaURL]) {
                DispatchQueue.main.async {
                    self.detailedInfo.steps[stepIndex].mediaURLs.remove(at: mediaIndex)
                    let indexPath = IndexPath(row: stepIndex, section: 0)
                    self.stepsTableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    private func deleteMediaFiles(mediaURLs: [String], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        for urlString in mediaURLs {
            guard let url = URL(string: urlString) else { continue }
            
            group.enter()
            let storageRef = Storage.storage().reference(forURL: urlString)
            storageRef.delete { error in
                if let error = error {
                    print("Error deleting media file: \(error.localizedDescription)")
                } else {
                    print("Media file deleted successfully")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .global()) {
            completion()
        }
    }
    
    // MARK: - Image Picker
    
    private func showImagePicker() {
        let alert = UIAlertController(title: "Add Media", message: "Choose media type", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            self.presentImagePicker(sourceType: .photoLibrary)
        })
        
        alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            self.presentImagePicker(sourceType: .camera)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            let alert = UIAlertController(title: "Error", message: "Source type not available", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.image", "public.movie"]
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
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Uploading", message: "Please wait...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: loadingAlert.view.bottomAnchor, constant: -50)
        ])
        
        present(loadingAlert, animated: true)
        
        // Handle image
        if let image = info[.originalImage] as? UIImage {
            uploadImage(image) { [weak self] url, error in
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true)
                    if let url = url {
                        self?.detailedInfo.steps[stepIndex].mediaURLs.append(url.absoluteString)
                        let indexPath = IndexPath(row: stepIndex, section: 0)
                        self?.stepsTableView.reloadRows(at: [indexPath], with: .automatic)
                    } else if let error = error {
                        self?.showAlert(message: "Upload failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        // Handle video
        else if let videoURL = info[.mediaURL] as? URL {
            uploadVideo(videoURL) { [weak self] url, error in
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true)
                    if let url = url {
                        self?.detailedInfo.steps[stepIndex].mediaURLs.append(url.absoluteString)
                        let indexPath = IndexPath(row: stepIndex, section: 0)
                        self?.stepsTableView.reloadRows(at: [indexPath], with: .automatic)
                    } else if let error = error {
                        self?.showAlert(message: "Upload failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        currentStepIndexForMedia = nil
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        currentStepIndexForMedia = nil
    }
    
    // MARK: - Upload Functions
    
    private func uploadImage(_ image: UIImage, completion: @escaping (URL?, Error?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil, NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"]))
            return
        }
        
        let storageRef = Storage.storage().reference()
        let fileName = "\(UUID().uuidString).jpg"
        let imageRef = storageRef.child("detailedStepsMedia").child(fileName)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            imageRef.downloadURL { url, error in
                completion(url, error)
            }
        }
    }
    
    private func uploadVideo(_ videoURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        let storageRef = Storage.storage().reference()
        let fileName = "\(UUID().uuidString).mp4"
        let videoRef = storageRef.child("detailedStepsMedia").child(fileName)
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        videoRef.putFile(from: videoURL, metadata: metadata) { metadata, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            videoRef.downloadURL { url, error in
                completion(url, error)
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension AdditionalInfoEditorVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Enhanced Step Cell

private class EnhancedStepCell: UITableViewCell, UITextViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
   
   // Callbacks
   var onTextChanged: ((String, Int) -> Void)?
   var onAddMediaTapped: ((Int) -> Void)?
   var onDeleteStepTapped: ((Int) -> Void)?
   var onDeleteMediaTapped: ((Int, Int) -> Void)?
   
   // UI Elements
   private let containerView: UIView = {
       let view = UIView()
       view.backgroundColor = UIColor(red: 15/255, green: 12/255, blue: 50/255, alpha: 0.8)
       view.layer.cornerRadius = 15
       view.layer.borderWidth = 1
       view.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
       view.layer.shadowColor = UIColor.black.cgColor
       view.layer.shadowOffset = CGSize(width: 0, height: 2)
       view.layer.shadowOpacity = 0.3
       view.layer.shadowRadius = 5
       view.translatesAutoresizingMaskIntoConstraints = false
       return view
   }()
   
   private let headerView: UIView = {
       let view = UIView()
       view.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 0.1)
       view.layer.cornerRadius = 10
       view.translatesAutoresizingMaskIntoConstraints = false
       return view
   }()
   
   private let stepNumberLabel: UILabel = {
       let label = UILabel()
       label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
       label.textColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
       label.translatesAutoresizingMaskIntoConstraints = false
       return label
   }()
   
   private let deleteStepButton: UIButton = {
       let button = UIButton(type: .system)
       button.setImage(UIImage(systemName: "trash.fill"), for: .normal)
       button.tintColor = .systemRed
       button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
       button.layer.cornerRadius = 15
       button.translatesAutoresizingMaskIntoConstraints = false
       return button
   }()
   
   private let stepTextView: UITextView = {
       let textView = UITextView()
       textView.font = UIFont.systemFont(ofSize: 16)
       textView.textColor = .white
       textView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
       textView.layer.cornerRadius = 10
       textView.layer.borderWidth = 1
       textView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
       textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
       textView.translatesAutoresizingMaskIntoConstraints = false
       textView.returnKeyType = .done
       return textView
   }()
   
   private let addMediaButton: UIButton = {
       let button = UIButton(type: .system)
       button.setTitle("📎 Add Media", for: .normal)
       button.setTitleColor(.white, for: .normal)
       button.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
       button.layer.cornerRadius = 8
       button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
       button.translatesAutoresizingMaskIntoConstraints = false
       return button
   }()
   
   private let mediaCollectionView: UICollectionView
   
   // Data
   private var mediaURLs: [String] = []
   private var stepIndex: Int = 0
   
   override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
       // Setup Collection View Layout
       let layout = UICollectionViewFlowLayout()
       layout.scrollDirection = .horizontal
       layout.itemSize = CGSize(width: 100, height: 100)
       layout.minimumLineSpacing = 8
       layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
       mediaCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
       mediaCollectionView.translatesAutoresizingMaskIntoConstraints = false
       mediaCollectionView.backgroundColor = .clear
       mediaCollectionView.showsHorizontalScrollIndicator = false
       
       super.init(style: style, reuseIdentifier: reuseIdentifier)
       
       backgroundColor = .clear
       selectionStyle = .none
       
       setupUI()
       setupConstraints()
       setupActions()
   }
   
   required init?(coder: NSCoder) {
       fatalError("init(coder:) has not been implemented")
   }
   
   private func setupUI() {
       // Configure stepTextView
       stepTextView.delegate = self
       
       // Configure mediaCollectionView
       mediaCollectionView.dataSource = self
       mediaCollectionView.delegate = self
       mediaCollectionView.register(EnhancedMediaCell.self, forCellWithReuseIdentifier: "MediaCell")
       
       // Add subviews
       contentView.addSubview(containerView)
       containerView.addSubview(headerView)
       headerView.addSubview(stepNumberLabel)
       headerView.addSubview(deleteStepButton)
       containerView.addSubview(stepTextView)
       containerView.addSubview(addMediaButton)
       containerView.addSubview(mediaCollectionView)
   }
   
   private func setupConstraints() {
       NSLayoutConstraint.activate([
           // Container View
           containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
           containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
           containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
           containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
           
           // Header View
           headerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
           headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
           headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
           headerView.heightAnchor.constraint(equalToConstant: 40),
           
           // Step Number Label
           stepNumberLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
           stepNumberLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
           
           // Delete Step Button
           deleteStepButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
           deleteStepButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
           deleteStepButton.widthAnchor.constraint(equalToConstant: 30),
           deleteStepButton.heightAnchor.constraint(equalToConstant: 30),
           
           // Step Text View
           stepTextView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
           stepTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
           stepTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
           stepTextView.heightAnchor.constraint(equalToConstant: 80),
           
           // Add Media Button
           addMediaButton.topAnchor.constraint(equalTo: stepTextView.bottomAnchor, constant: 12),
           addMediaButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
           addMediaButton.widthAnchor.constraint(equalToConstant: 120),
           addMediaButton.heightAnchor.constraint(equalToConstant: 32),
           
           // Media Collection View
           mediaCollectionView.topAnchor.constraint(equalTo: addMediaButton.bottomAnchor, constant: 12),
           mediaCollectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
           mediaCollectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
           mediaCollectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
           mediaCollectionView.heightAnchor.constraint(equalToConstant: 100),
       ])
   }
   
   private func setupActions() {
       addMediaButton.addTarget(self, action: #selector(didTapAddMedia), for: .touchUpInside)
       deleteStepButton.addTarget(self, action: #selector(didTapDeleteStep), for: .touchUpInside)
   }
   
   @objc private func didTapAddMedia() {
       onAddMediaTapped?(stepIndex)
   }
   
   @objc private func didTapDeleteStep() {
       onDeleteStepTapped?(stepIndex)
   }
   
   // Configure cell with step data
   func configure(step: Step, index: Int, brandColor: UIColor) {
       stepIndex = index
       stepNumberLabel.text = "Step \(index + 1)"
       stepTextView.text = step.text
       mediaURLs = step.mediaURLs
       
       // Update placeholder
       if step.text.isEmpty {
           stepTextView.text = "Enter step description..."
           stepTextView.textColor = .lightGray
       } else {
           stepTextView.textColor = .white
       }
       
       mediaCollectionView.reloadData()
       
       // Hide collection view if no media
       mediaCollectionView.isHidden = mediaURLs.isEmpty
   }
   
   // MARK: - UITextViewDelegate
   
   func textViewDidBeginEditing(_ textView: UITextView) {
       if textView.textColor == .lightGray {
           textView.text = nil
           textView.textColor = .white
       }
   }
   
   func textViewDidEndEditing(_ textView: UITextView) {
       if textView.text.isEmpty {
           textView.text = "Enter step description..."
           textView.textColor = .lightGray
       }
   }
   
   func textViewDidChange(_ textView: UITextView) {
       let text = textView.textColor == .lightGray ? "" : textView.text
       onTextChanged?(text ?? "", stepIndex)
   }
   
   func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
       if text == "\n" {
           textView.resignFirstResponder()
           return false
       }
       return true
   }
   
   // MARK: - UICollectionViewDataSource & Delegate
   
   func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
       return mediaURLs.count
   }
   
   func collectionView(_ collectionView: UICollectionView,
                       cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
       guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaCell", for: indexPath) as? EnhancedMediaCell else {
           return UICollectionViewCell()
       }
       
       let urlString = mediaURLs[indexPath.item]
       cell.configure(with: urlString)
       
       cell.onDeleteTapped = { [weak self] in
           self?.onDeleteMediaTapped?(self?.stepIndex ?? 0, indexPath.item)
       }
       
       return cell
   }
}

// MARK: - Enhanced Media Cell

private class EnhancedMediaCell: UICollectionViewCell {
   
   var onDeleteTapped: (() -> Void)?
   
   private let imageView: UIImageView = {
       let iv = UIImageView()
       iv.contentMode = .scaleAspectFill
       iv.layer.cornerRadius = 12
       iv.clipsToBounds = true
       iv.backgroundColor = UIColor.darkGray
       iv.translatesAutoresizingMaskIntoConstraints = false
       return iv
   }()
   
   private let deleteButton: UIButton = {
       let button = UIButton(type: .system)
       button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
       button.tintColor = .systemRed
       button.backgroundColor = .white
       button.layer.cornerRadius = 12
       button.layer.shadowColor = UIColor.black.cgColor
       button.layer.shadowOpacity = 0.3
       button.layer.shadowOffset = CGSize(width: 0, height: 1)
       button.layer.shadowRadius = 2
       button.translatesAutoresizingMaskIntoConstraints = false
       return button
   }()
   
   private let typeIndicatorView: UIView = {
       let view = UIView()
       view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
       view.layer.cornerRadius = 8
       view.translatesAutoresizingMaskIntoConstraints = false
       return view
   }()
   
   private let typeLabel: UILabel = {
       let label = UILabel()
       label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
       label.textColor = .white
       label.textAlignment = .center
       label.translatesAutoresizingMaskIntoConstraints = false
       return label
   }()
   
   override init(frame: CGRect) {
       super.init(frame: frame)
       
       contentView.addSubview(imageView)
       contentView.addSubview(deleteButton)
       contentView.addSubview(typeIndicatorView)
       typeIndicatorView.addSubview(typeLabel)
       
       // Layout constraints
       NSLayoutConstraint.activate([
           imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
           imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
           imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
           imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
           
           deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -8),
           deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 8),
           deleteButton.widthAnchor.constraint(equalToConstant: 24),
           deleteButton.heightAnchor.constraint(equalToConstant: 24),
           
           typeIndicatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
           typeIndicatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
           typeIndicatorView.widthAnchor.constraint(equalToConstant: 40),
           typeIndicatorView.heightAnchor.constraint(equalToConstant: 16),
           
           typeLabel.centerXAnchor.constraint(equalTo: typeIndicatorView.centerXAnchor),
           typeLabel.centerYAnchor.constraint(equalTo: typeIndicatorView.centerYAnchor)
       ])
       
       deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
   }
   
   @objc private func deleteTapped() {
       onDeleteTapped?()
   }
   
   func configure(with urlString: String) {
       guard let url = URL(string: urlString) else { return }
       
       let fileExtension = url.pathExtension.lowercased()
       let isVideo = ["mp4", "mov", "avi", "m4v"].contains(fileExtension)
       
       if isVideo {
           typeLabel.text = "VIDEO"
           imageView.image = UIImage(systemName: "play.rectangle.fill")
           imageView.tintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
           imageView.contentMode = .scaleAspectFit
       } else {
           typeLabel.text = "IMAGE"
           imageView.sd_setImage(with: url, placeholderImage: UIImage(systemName: "photo"))
           imageView.contentMode = .scaleAspectFill
       }
   }
   
   required init?(coder: NSCoder) {
       fatalError("init(coder:) has not been implemented")
   }
}
