
//
// MARK: - 2. SystemAuditViewController.swift - Main System Audit View Controller
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

class SystemAuditViewController: UIViewController {
    
    // MARK: - Properties
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    private let db = Firestore.firestore()
    
    private var auditContainers: [AuditContainer] = []
    
    // MARK: - UI Components
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0).cgColor,
            UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0).cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "System Audit"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "AI-Powered Industrial Fault Detection"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("+ New Audit", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        fetchAuditContainers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide the navigation bar completely
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = headerView.bounds
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = backgroundColor
        
        // Ensure navigation bar is hidden
        navigationController?.navigationBar.isHidden = true
        
        headerView.layer.addSublayer(gradientLayer)
        
        view.addSubview(headerView)
        view.addSubview(addButton)
        view.addSubview(tableView)
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -40),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 120),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            addButton.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            addButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 200),
            addButton.heightAnchor.constraint(equalToConstant: 50),
            
            tableView.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AuditContainerCell.self, forCellReuseIdentifier: "AuditContainerCell")
    }
    
    // MARK: - Actions
    @objc private func addButtonTapped() {
        let uploadVC = SystemAuditUploadViewController()
        uploadVC.delegate = self
        let navController = UINavigationController(rootViewController: uploadVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // MARK: - Data Management
    private func fetchAuditContainers() {
        db.collection("systemAudits")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                if let error = error {
                    print("Error fetching audit containers: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else { return }
                
                self?.auditContainers = documents.compactMap { doc in
                    let data = doc.data()
                    return AuditContainer.fromFirestore(data: data, id: doc.documentID)
                }
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension SystemAuditViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return auditContainers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AuditContainerCell", for: indexPath) as! AuditContainerCell
        let container = auditContainers[indexPath.row]
        cell.configure(with: container)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let container = auditContainers[indexPath.row]
        
        let detailVC = AuditContainerDetailViewController()
        detailVC.auditContainer = container
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
}

// MARK: - SystemAuditUploadDelegate
extension SystemAuditViewController: SystemAuditUploadDelegate {
    func didCreateAuditContainer() {
        // Data will be automatically updated via Firestore listener
    }
}

//
// MARK: - 3. SystemAuditUploadViewController.swift - Upload Images View Controller
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

protocol SystemAuditUploadDelegate: AnyObject {
    func didCreateAuditContainer()
}

class SystemAuditUploadViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: SystemAuditUploadDelegate?
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    private let db = Firestore.firestore()
    
    private var selectedImages: [AuditImage] = []
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let containerNameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter container name"
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.textColor = .white
        textField.layer.cornerRadius = 10
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.white.cgColor
        textField.setLeftPaddingPoints(15)
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let containerTypeTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter container type (e.g., Engine, Pump, Valve)"
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.textColor = .white
        textField.layer.cornerRadius = 10
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.white.cgColor
        textField.setLeftPaddingPoints(15)
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let addImagesButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("+ Add Images", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let imagesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Save & Analyze", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupNavigationBar()
        setupKeyboardDismissal()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = backgroundColor
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(containerNameTextField)
        contentView.addSubview(containerTypeTextField)
        contentView.addSubview(addImagesButton)
        contentView.addSubview(imagesCollectionView)
        contentView.addSubview(saveButton)
        
        // Set text field delegates
        containerNameTextField.delegate = self
        containerTypeTextField.delegate = self
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            containerNameTextField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            containerNameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerNameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            containerNameTextField.heightAnchor.constraint(equalToConstant: 50),
            
            containerTypeTextField.topAnchor.constraint(equalTo: containerNameTextField.bottomAnchor, constant: 20),
            containerTypeTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerTypeTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            containerTypeTextField.heightAnchor.constraint(equalToConstant: 50),
            
            addImagesButton.topAnchor.constraint(equalTo: containerTypeTextField.bottomAnchor, constant: 30),
            addImagesButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            addImagesButton.widthAnchor.constraint(equalToConstant: 200),
            addImagesButton.heightAnchor.constraint(equalToConstant: 50),
            
            imagesCollectionView.topAnchor.constraint(equalTo: addImagesButton.bottomAnchor, constant: 20),
            imagesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            imagesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imagesCollectionView.heightAnchor.constraint(equalToConstant: 300),
            
            saveButton.topAnchor.constraint(equalTo: imagesCollectionView.bottomAnchor, constant: 30),
            saveButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 200),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
        
        addImagesButton.addTarget(self, action: #selector(addImagesButtonTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
    }
    
    private func setupKeyboardDismissal() {
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // Set return key type for text fields
        containerNameTextField.returnKeyType = .next
        containerTypeTextField.returnKeyType = .done
    }
    
    private func setupCollectionView() {
        imagesCollectionView.delegate = self
        imagesCollectionView.dataSource = self
        imagesCollectionView.register(AuditImageCell.self, forCellWithReuseIdentifier: "AuditImageCell")
    }
    
    private func setupNavigationBar() {
        title = "New System Audit"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func addImagesButtonTapped() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = false
        present(imagePicker, animated: true)
    }
    
    @objc private func saveButtonTapped() {
        guard let containerName = containerNameTextField.text, !containerName.isEmpty,
              let containerType = containerTypeTextField.text, !containerType.isEmpty,
              !selectedImages.isEmpty else {
            showAlert(message: "Please fill in all fields and add at least one image.")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Processing", message: "Uploading images and analyzing...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Create container and upload images
        createAuditContainer(name: containerName, type: containerType) { [weak self] in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    self?.delegate?.didCreateAuditContainer()
                    self?.dismiss(animated: true)
                }
            }
        }
    }
    
    private func createAuditContainer(name: String, type: String, completion: @escaping () -> Void) {
        let containerData: [String: Any] = [
            "name": name,
            "type": type,
            "createdAt": FieldValue.serverTimestamp(),
            "totalImages": selectedImages.count,
            "analysisComplete": false
        ]
        
        // Create container document
        let containerRef = db.collection("systemAudits").document()
        
        containerRef.setData(containerData) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.showAlert(message: "Failed to create container: \(error.localizedDescription)")
                }
                return
            }
            
            // Upload and analyze images
            self?.uploadAndAnalyzeImages(containerID: containerRef.documentID, completion: completion)
        }
    }
    
    private func uploadAndAnalyzeImages(containerID: String, completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        for (index, auditImage) in selectedImages.enumerated() {
            group.enter()
            
            // Upload image to Firebase Storage
            uploadImageToStorage(image: auditImage.image) { [weak self] imageURL in
                if let imageURL = imageURL {
                    // Analyze image with OpenAI
                    self?.analyzeImageWithOpenAI(imageURL: imageURL, imageName: auditImage.name, containerType: auditImage.type) { analysisResult in
                        // Save to Firestore
                        let imageData: [String: Any] = [
                            "name": auditImage.name,
                            "type": auditImage.type,
                            "imageURL": imageURL.absoluteString,
                            "analysisResult": analysisResult,
                            "containerID": containerID,
                            "createdAt": FieldValue.serverTimestamp()
                        ]
                        
                        self?.db.collection("systemAudits").document(containerID).collection("images").addDocument(data: imageData) { _ in
                            group.leave()
                        }
                    }
                } else {
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            // Update container to mark analysis as complete
            self.db.collection("systemAudits").document(containerID).updateData([
                "analysisComplete": true
            ]) { _ in
                completion()
            }
        }
    }
    
    private func uploadImageToStorage(image: UIImage, completion: @escaping (URL?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        let storageRef = Storage.storage().reference()
        let imageRef = storageRef.child("systemAudit/\(UUID().uuidString).jpg")
        
        imageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Upload error: \(error)")
                completion(nil)
                return
            }
            
            imageRef.downloadURL { url, error in
                completion(url)
            }
        }
    }
    
    private func analyzeImageWithOpenAI(imageURL: URL, imageName: String, containerType: String, completion: @escaping (String) -> Void) {
        let openAIAPIKey = Config.openAIAPIKey
        
        // First, let's try to get the image data to convert to base64
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            guard let imageData = data, error == nil else {
                completion("Error: Could not download image for analysis")
                return
            }
            
            // Convert image to base64
            let base64Image = imageData.base64EncodedString()
            
            let prompt = """
            You are an industrial equipment inspection AI assistant. Analyze this image of a \(containerType) component named "\(imageName)" and provide a detailed assessment.

            Please identify:
            1. Any visible faults, defects, or potential issues
            2. Wear patterns or signs of deterioration  
            3. Safety concerns or hazards
            4. Maintenance recommendations
            5. Overall condition assessment (Good/Fair/Poor/Critical)

            If this is not industrial equipment, still provide an analysis of any mechanical or structural components visible in the image.
            Be specific and technical in your analysis.
            """
            
            let requestBody: [String: Any] = [
                "model": "gpt-4o",
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "text",
                                "text": prompt
                            ],
                            [
                                "type": "image_url",
                                "image_url": [
                                    "url": "data:image/jpeg;base64,\(base64Image)"
                                ]
                            ]
                        ]
                    ]
                ],
                "max_tokens": 500
            ]
            
            guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
                completion("Error: Failed to create request body")
                return
            }
            
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody
            request.timeoutInterval = 60 // Increase timeout
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Network error: \(error.localizedDescription)")
                    completion("Error: Network issue - \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion("Error: Invalid response")
                    return
                }
                
                print("HTTP Status Code: \(httpResponse.statusCode)")
                
                guard let data = data else {
                    completion("Error: No data received")
                    return
                }
                
                // Print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw API Response: \(responseString)")
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // Check for API errors
                        if let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            completion("API Error: \(message)")
                            return
                        }
                        
                        // Parse successful response
                        if let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let message = firstChoice["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            completion(content.trimmingCharacters(in: .whitespacesAndNewlines))
                        } else {
                            completion("Error: Unexpected response format")
                        }
                    } else {
                        completion("Error: Could not parse JSON response")
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    completion("Error: Failed to parse response - \(error.localizedDescription)")
                }
            }
            
            task.resume()
            
        }.resume()
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension SystemAuditUploadViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.originalImage] as? UIImage else { return }
        
        // Show image details modal
        let imageDetailsVC = AuditImageDetailsViewController(image: image)
        imageDetailsVC.saveHandler = { [weak self] name, type, image in
            let auditImage = AuditImage(image: image, name: name, type: type)
            self?.selectedImages.append(auditImage)
            self?.imagesCollectionView.reloadData()
        }
        
        let navController = UINavigationController(rootViewController: imageDetailsVC)
        present(navController, animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegate
extension SystemAuditUploadViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectedImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AuditImageCell", for: indexPath) as! AuditImageCell
        let auditImage = selectedImages[indexPath.item]
        cell.configure(with: auditImage)
        cell.deleteHandler = { [weak self] in
            self?.selectedImages.remove(at: indexPath.item)
            self?.imagesCollectionView.reloadData()
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 10) / 2
        return CGSize(width: width, height: width + 40)
    }
}

// MARK: - UITextFieldDelegate
extension SystemAuditUploadViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == containerNameTextField {
            containerTypeTextField.becomeFirstResponder()
        } else if textField == containerTypeTextField {
            textField.resignFirstResponder()
        }
        return true
    }
}

//
// MARK: - 4. Data Models
//

struct AuditContainer {
    let id: String
    let name: String
    let type: String
    let createdAt: Date
    let totalImages: Int
    let analysisComplete: Bool
    
    static func fromFirestore(data: [String: Any], id: String) -> AuditContainer? {
        guard let name = data["name"] as? String,
              let type = data["type"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let totalImages = data["totalImages"] as? Int,
              let analysisComplete = data["analysisComplete"] as? Bool else {
            return nil
        }
        
        return AuditContainer(
            id: id,
            name: name,
            type: type,
            createdAt: createdAtTimestamp.dateValue(),
            totalImages: totalImages,
            analysisComplete: analysisComplete
        )
    }
}

struct AuditImage {
    let image: UIImage
    let name: String
    let type: String
}

struct AuditImageResult {
    let id: String
    let name: String
    let type: String
    let imageURL: String
    let analysisResult: String
    let createdAt: Date
    
    static func fromFirestore(data: [String: Any], id: String) -> AuditImageResult? {
        guard let name = data["name"] as? String,
              let type = data["type"] as? String,
              let imageURL = data["imageURL"] as? String,
              let analysisResult = data["analysisResult"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        return AuditImageResult(
            id: id,
            name: name,
            type: type,
            imageURL: imageURL,
            analysisResult: analysisResult,
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}

//
// MARK: - 5. AuditContainerCell.swift - Table View Cell for Container List
//

class AuditContainerCell: UITableViewCell {
    
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let imageCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initializers
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(typeLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(imageCountLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -10),
            
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            typeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            dateLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            imageCountLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            imageCountLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            statusLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            statusLabel.widthAnchor.constraint(equalToConstant: 80),
            statusLabel.heightAnchor.constraint(equalToConstant: 25)
        ])
    }
    
    // MARK: - Configuration
    func configure(with container: AuditContainer) {
        nameLabel.text = container.name
        typeLabel.text = "Type: \(container.type)"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        dateLabel.text = formatter.string(from: container.createdAt)
        
        imageCountLabel.text = "\(container.totalImages) images"
        
        if container.analysisComplete {
            statusLabel.text = "Complete"
            statusLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
            statusLabel.textColor = .white
        } else {
            statusLabel.text = "Processing"
            statusLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
            statusLabel.textColor = .white
        }
    }
}

//
// MARK: - 6. AuditImageCell.swift - Collection View Cell for Image Upload
//

class AuditImageCell: UICollectionViewCell {
    
    // MARK: - Properties
    var deleteHandler: (() -> Void)?
    
    // MARK: - UI Components
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.textColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .lightGray
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .red
        button.backgroundColor = .white
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = UIColor.white.withAlphaComponent(0.05)
        layer.cornerRadius = 8
        
        addSubview(imageView)
        addSubview(nameLabel)
        addSubview(typeLabel)
        addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            typeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            typeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            typeLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),
            
            deleteButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func deleteButtonTapped() {
        deleteHandler?()
    }
    
    // MARK: - Configuration
    func configure(with auditImage: AuditImage) {
        imageView.image = auditImage.image
        nameLabel.text = auditImage.name
        typeLabel.text = auditImage.type
    }
}

//
// MARK: - 7. AuditImageDetailsViewController.swift - Modal for Adding Image Details
//

class AuditImageDetailsViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: - Properties
    let image: UIImage
    var saveHandler: ((String, String, UIImage) -> Void)?
    
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Image name (e.g., Front Panel, Left Side)"
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.textColor = .white
        textField.layer.cornerRadius = 10
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.white.cgColor
        textField.setLeftPaddingPoints(15)
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let typeTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Component type (e.g., Motor, Valve, Pipe)"
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.textColor = .white
        textField.layer.cornerRadius = 10
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.white.cgColor
        textField.setLeftPaddingPoints(15)
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    // MARK: - Initializers
    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupKeyboardDismissal()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = backgroundColor
        
        imageView.image = image
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(imageView)
        contentView.addSubview(nameTextField)
        contentView.addSubview(typeTextField)
        
        // Set text field delegates
        nameTextField.delegate = self
        typeTextField.delegate = self
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.75),
            
            nameTextField.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 30),
            nameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 50),
            
            typeTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 20),
            typeTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            typeTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            typeTextField.heightAnchor.constraint(equalToConstant: 50),
            typeTextField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
        
        // Set return key types
        nameTextField.returnKeyType = .next
        typeTextField.returnKeyType = .done
    }
    
    private func setupKeyboardDismissal() {
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupNavigationBar() {
        title = "Image Details"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .white
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveButtonTapped)
        )
        
        navigationItem.rightBarButtonItem?.tintColor = brandColor
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func saveButtonTapped() {
        guard let name = nameTextField.text, !name.isEmpty,
              let type = typeTextField.text, !type.isEmpty else {
            showAlert(message: "Please fill in all fields.")
            return
        }
        
        saveHandler?(name, type, image)
        dismiss(animated: true)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

//
// MARK: - 8. AuditContainerDetailViewController.swift - Detail View for Container Results
//

class AuditContainerDetailViewController: UIViewController {
    
    // MARK: - Properties
    var auditContainer: AuditContainer!
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    private let db = Firestore.firestore()
    
    private var imageResults: [AuditImageResult] = []
    
    // MARK: - UI Components
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0).cgColor,
            UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0).cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        fetchImageResults()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = headerView.bounds
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = backgroundColor
        
        titleLabel.text = auditContainer.name
        subtitleLabel.text = "Type: \(auditContainer.type) • \(auditContainer.totalImages) images"
        
        headerView.layer.addSublayer(gradientLayer)
        
        view.addSubview(headerView)
        view.addSubview(tableView)
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.isHidden = false
        navigationController?.navigationBar.tintColor = .white
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AuditResultCell.self, forCellReuseIdentifier: "AuditResultCell")
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Data Management
    private func fetchImageResults() {
        db.collection("systemAudits")
            .document(auditContainer.id)
            .collection("images")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                if let error = error {
                    print("Error fetching image results: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else { return }
                
                self?.imageResults = documents.compactMap { doc in
                    let data = doc.data()
                    return AuditImageResult.fromFirestore(data: data, id: doc.documentID)
                }
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension AuditContainerDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return imageResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AuditResultCell", for: indexPath) as! AuditResultCell
        let result = imageResults[indexPath.row]
        cell.configure(with: result)
        return cell
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

//
// MARK: - 9. AuditResultCell.swift - Table View Cell for Analysis Results
//

class AuditResultCell: UITableViewCell {
    
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let analysisLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initializers
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(thumbnailImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(typeLabel)
        containerView.addSubview(analysisLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            thumbnailImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            thumbnailImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 80),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 80),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            typeLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            typeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            analysisLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 12),
            analysisLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            analysisLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            analysisLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Configuration
    func configure(with result: AuditImageResult) {
        nameLabel.text = result.name
        typeLabel.text = result.type
        analysisLabel.text = result.analysisResult
        
        // Load thumbnail image
        if let url = URL(string: result.imageURL) {
            loadImage(from: url)
        }
    }
    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.thumbnailImageView.image = image
                }
            }
        }.resume()
    }
}
