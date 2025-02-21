import UIKit
import FirebaseFirestore
import FirebaseStorage
import ARKit
import SceneKit
import AVKit

// MARK: - ProcedureViewController

class ProcedureViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ProcedureFormDelegate {

    // MARK: - Properties

    var procedures: [Procedure] = []
    var containerID: String!
    var imageItem: ImageItem!

    private let brandColor = UIColor(red: 0.0/255.0, green: 146.0/255.0, blue: 155.0/255.0, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5.0/255.0, green: 2.0/255.0, blue: 27.0/255.0, alpha: 1.0)

    private let tableView = UITableView()
    private let createButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create Procedure", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.0/255.0, green: 146.0/255.0, blue: 155.0/255.0, alpha: 1.0)
        button.layer.cornerRadius = 10
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 5
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .white
        button.imageView?.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // Firestore listener
    private var listener: ListenerRegistration?

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupCreateButton()
        setupTableView()
        fetchProcedures()

        // Add a back button to dismiss the modal
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )
        navigationController?.navigationBar.tintColor = .white
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Remove Firestore listener when the view is about to disappear
        listener?.remove()
    }

    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Setup Methods

    private func setupView() {
        view.backgroundColor = backgroundColor
        title = "Procedures"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
    }

    private func setupCreateButton() {
        createButton.addTarget(self, action: #selector(handleCreateProcedure), for: .touchUpInside)
        view.addSubview(createButton)

        NSLayoutConstraint.activate([
            createButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            createButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupTableView() {
        tableView.register(ProcedureCell.self, forCellReuseIdentifier: "ProcedureCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = backgroundColor
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView = UIView()

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 10),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
        ])
    }

    // MARK: - Action Methods

    @objc private func handleCreateProcedure() {
        let procedureFormVC = ProcedureFormViewController()
        procedureFormVC.delegate = self
        procedureFormVC.containerID = self.containerID
        procedureFormVC.imageItem = self.imageItem // Pass imageItem
        let navController = UINavigationController(rootViewController: procedureFormVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }

    // MARK: - Fetch Procedures

    private func fetchProcedures() {
        let db = Firestore.firestore()
        listener = db.collection("procedures")
            .whereField("containerID", isEqualTo: self.containerID) // Filter by container ID
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                if let error = error {
                    print("Firestore listener error:", error)
                    return
                }

                self?.procedures = []
                for document in querySnapshot?.documents ?? [] {
                    let data = document.data()
                    if let procedure = Procedure.fromFirestore(data: data, id: document.documentID) {
                        self?.procedures.append(procedure)
                    }
                }
                self?.tableView.reloadData()
            }
    }

    // MARK: - UITableViewDataSource & UITableViewDelegate Methods

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return procedures.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "ProcedureCell", for: indexPath) as! ProcedureCell
        let procedure = procedures[indexPath.row]
        cell.configure(with: procedure, brandColor: brandColor)

        cell.editAction = { [weak self] in
            self?.handleEditProcedure(procedure)
        }

        cell.deleteAction = { [weak self] in
            self?.handleDeleteProcedure(procedure)
        }

        cell.playAction = { [weak self] in
            self?.handlePlayProcedure(procedure)
        }

        return cell
    }

    // Handle row selection if needed
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect the row
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - ProcedureFormDelegate

    func didSaveProcedure() {
        // Fetch procedures again
        fetchProcedures()
    }

    // MARK: - Edit, Delete, and Play Procedures

    private func handleEditProcedure(_ procedure: Procedure) {
        let procedureFormVC = ProcedureFormViewController()
        procedureFormVC.delegate = self
        procedureFormVC.procedureToEdit = procedure
        procedureFormVC.containerID = self.containerID // Pass container ID
        procedureFormVC.imageItem = self.imageItem // Pass imageItem
        let navController = UINavigationController(rootViewController: procedureFormVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }

    private func handleDeleteProcedure(_ procedure: Procedure) {
        let alert = UIAlertController(
            title: "Delete Procedure",
            message: "Are you sure you want to delete this procedure? This action cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.deleteProcedure(procedure)
        }))
        present(alert, animated: true, completion: nil)
    }

    private func deleteProcedure(_ procedure: Procedure) {
        let db = Firestore.firestore()
        db.collection("procedures").document(procedure.id).delete { [weak self] error in
            if let error = error {
                print("Error removing procedure: \(error.localizedDescription)")
                let alert = UIAlertController(title: "Error", message: "Failed to delete procedure. Please try again.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
                return
            }
            // Update local data
            self?.procedures.removeAll { $0.id == procedure.id }
            self?.tableView.reloadData()
            let successAlert = UIAlertController(title: "Success", message: "Procedure deleted successfully", preferredStyle: .alert)
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(successAlert, animated: true, completion: nil)
        }
    }

    private func handlePlayProcedure(_ procedure: Procedure) {
        let arVC = ProcedureARViewController()
        arVC.procedure = procedure
        arVC.imageItem = self.imageItem // Pass imageItem
        let navController = UINavigationController(rootViewController: arVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }
}

// MARK: - ProcedureFormViewController

protocol ProcedureFormDelegate: AnyObject {
    func didSaveProcedure()
}

class ProcedureFormViewController: UIViewController,
                                  UITableViewDataSource,
                                  UITableViewDelegate,
                                  UITextFieldDelegate,
                                  ARPinDelegate,
                                  UIImagePickerControllerDelegate,
                                  UINavigationControllerDelegate {

    weak var delegate: ProcedureFormDelegate?
    var procedureToEdit: Procedure?
    var containerID: String!
    var imageItem: ImageItem!

    // UI Elements
    let nameTextField = UITextField()
    let descriptionTextField = UITextField()
    let stepsTableView = UITableView()
    var steps: [ProcedureStep] = []

    let backgroundColor = UIColor(red: 5.0/255.0, green: 2.0/255.0, blue: 27.0/255.0, alpha: 1.0)
    let brandColor = UIColor(red: 0.0/255.0, green: 146.0/255.0, blue: 155.0/255.0, alpha: 1.0)

    // For handling media selection
    var selectedStepIndexForMedia: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavigationBar()
        setupForm()
        setupKeyboardDismissal()
    }

    private func setupView() {
        view.backgroundColor = backgroundColor
    }

    private func setupNavigationBar() {
        title = procedureToEdit == nil ? "Create Procedure" : "Edit Procedure"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(handleCancel)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(handleSave)
        )
        navigationItem.rightBarButtonItem?.tintColor = brandColor
    }

    private func setupForm() {
        // Name TextField
        nameTextField.placeholder = "Procedure Name"
        nameTextField.backgroundColor = UIColor(red: 15.0/255.0, green: 12.0/255.0, blue: 50.0/255.0, alpha: 1.0)
        nameTextField.textColor = .white
        nameTextField.layer.cornerRadius = 10
        nameTextField.layer.borderWidth = 1
        nameTextField.layer.borderColor = UIColor.white.cgColor
        nameTextField.setLeftPaddingPoints(10)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.delegate = self
        nameTextField.returnKeyType = .done

        // Description TextField
        descriptionTextField.placeholder = "Procedure Description"
        descriptionTextField.backgroundColor = UIColor(red: 15.0/255.0, green: 12.0/255.0, blue: 50.0/255.0, alpha: 1.0)
        descriptionTextField.textColor = .white
        descriptionTextField.layer.cornerRadius = 10
        descriptionTextField.layer.borderWidth = 1
        descriptionTextField.layer.borderColor = UIColor.white.cgColor
        descriptionTextField.setLeftPaddingPoints(10)
        descriptionTextField.translatesAutoresizingMaskIntoConstraints = false
        descriptionTextField.delegate = self
        descriptionTextField.returnKeyType = .done

        // Steps TableView
        stepsTableView.register(ProcedureStepCell.self, forCellReuseIdentifier: "ProcedureStepCell")
        stepsTableView.delegate = self
        stepsTableView.dataSource = self
        stepsTableView.backgroundColor = backgroundColor
        stepsTableView.separatorStyle = .none
        stepsTableView.translatesAutoresizingMaskIntoConstraints = false
        stepsTableView.tableFooterView = UIView()

        // Add Step Button
        let addStepButton = UIButton(type: .system)
        addStepButton.setTitle("Add Step", for: .normal)
        addStepButton.setTitleColor(.white, for: .normal)
        addStepButton.backgroundColor = brandColor
        addStepButton.layer.cornerRadius = 10
        addStepButton.layer.shadowColor = UIColor.black.cgColor
        addStepButton.layer.shadowOpacity = 0.3
        addStepButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        addStepButton.layer.shadowRadius = 5
        addStepButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        addStepButton.addTarget(self, action: #selector(handleAddStep), for: .touchUpInside)
        addStepButton.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        view.addSubview(nameTextField)
        view.addSubview(descriptionTextField)
        view.addSubview(addStepButton)
        view.addSubview(stepsTableView)

        // Constraints
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nameTextField.heightAnchor.constraint(equalToConstant: 50),

            descriptionTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 10),
            descriptionTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            descriptionTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            descriptionTextField.heightAnchor.constraint(equalToConstant: 50),

            addStepButton.topAnchor.constraint(equalTo: descriptionTextField.bottomAnchor, constant: 10),
            addStepButton.leadingAnchor.constraint(equalTo: descriptionTextField.leadingAnchor),
            addStepButton.trailingAnchor.constraint(equalTo: descriptionTextField.trailingAnchor),
            addStepButton.heightAnchor.constraint(equalToConstant: 50),

            stepsTableView.topAnchor.constraint(equalTo: addStepButton.bottomAnchor, constant: 10),
            stepsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stepsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stepsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // If editing, populate fields
        if let procedure = procedureToEdit {
            nameTextField.text = procedure.name
            descriptionTextField.text = procedure.description
            steps = procedure.steps
        }
    }

    private func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        stepsTableView.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func handleCancel() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func handleSave() {
        guard let name = nameTextField.text, !name.isEmpty else {
            showAlert(message: "Procedure name is required.")
            return
        }
        guard let description = descriptionTextField.text, !description.isEmpty else {
            showAlert(message: "Procedure description is required.")
            return
        }
        if steps.isEmpty {
            showAlert(message: "Please add at least one step.")
            return
        }
        saveProcedure(name: name, description: description)
    }

    @objc private func handleAddStep() {
        steps.append(ProcedureStep(description: "", position: nil, media: []))
        stepsTableView.reloadData()
    }

    private func saveProcedure(name: String, description: String) {
        let db = Firestore.firestore()

        // Prepare steps data
        var stepsData: [[String: Any]] = []
        let group = DispatchGroup()
        var uploadErrorOccurred = false

        for (index, step) in steps.enumerated() {
            group.enter()
            var stepData: [String: Any] = [
                "description": step.description
            ]

            // Include position data if available
            if let position = step.position {
                stepData["position"] = [
                    "x": position.x,
                    "y": position.y,
                    "z": position.z
                ]
            }

            // We will build an array of media for Firestore
            var mediaArray: [[String: Any]] = []

            // For each media item in the step, we need to upload if it's local
            let mediaUploadGroup = DispatchGroup()

            for (mediaIndex, mediaItem) in step.media.enumerated() {
                mediaUploadGroup.enter()
                if let localURL = mediaItem.localURL {
                    uploadMedia(mediaURL: localURL) { [weak self] url, error in
                        if let error = error {
                            print("Error uploading media: \(error.localizedDescription)")
                            uploadErrorOccurred = true
                            mediaUploadGroup.leave()
                        } else if let url = url {
                            // Create dictionary for this media
                            let mediaDict: [String: Any] = [
                                "url": url.absoluteString,
                                "type": mediaItem.type,
                                "name": mediaItem.name
                            ]
                            mediaArray.append(mediaDict)
                            // Update step in memory so we won't re-upload
                            self?.steps[index].media[mediaIndex].remoteURL = url
                            self?.steps[index].media[mediaIndex].localURL = nil
                            mediaUploadGroup.leave()
                        }
                    }
                } else if let remoteURL = mediaItem.remoteURL {
                    // Already remote, just store as is
                    let mediaDict: [String: Any] = [
                        "url": remoteURL.absoluteString,
                        "type": mediaItem.type,
                        "name": mediaItem.name
                    ]
                    mediaArray.append(mediaDict)
                    mediaUploadGroup.leave()
                } else {
                    // No media links
                    mediaUploadGroup.leave()
                }
            }

            mediaUploadGroup.notify(queue: .main) {
                stepData["media"] = mediaArray
                stepsData.append(stepData)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if uploadErrorOccurred {
                self.showAlert(message: "Failed to upload one or more media. Please try again.")
                return
            }

            // Additional fields in your Firestore doc:
            let containerName = self.imageItem?.name ?? "Unknown"
            let categoryName = self.imageItem?.type ?? "Unknown"

            let procedureData: [String: Any] = [
                "name": name,
                "description": description,
                "steps": stepsData,
                "createdAt": FieldValue.serverTimestamp(),
                "containerID": self.containerID,
                "containerName": containerName,
                "categoryName": categoryName
            ]

            if let procedureToEdit = self.procedureToEdit {
                // Update existing procedure
                db.collection("procedures").document(procedureToEdit.id).setData(procedureData) { error in
                    if let error = error {
                        print("Error updating procedure:", error)
                        self.showAlert(message: "Failed to update procedure. Please try again.")
                        return
                    }
                    self.delegate?.didSaveProcedure()
                    self.dismiss(animated: true, completion: nil)
                }
            } else {
                // Create new procedure
                db.collection("procedures").addDocument(data: procedureData) { error in
                    if let error = error {
                        print("Error saving procedure:", error)
                        self.showAlert(message: "Failed to save procedure. Please try again.")
                        return
                    }
                    self.delegate?.didSaveProcedure()
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

    private func uploadMedia(mediaURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        let storageRef = Storage.storage().reference()
        let mediaID = UUID().uuidString
        let fileExtension = mediaURL.pathExtension.lowercased()
        let mediaRef = storageRef.child("procedureMedia/\(mediaID).\(fileExtension)")

        // Determine content type based on file extension
        var contentType: String
        switch fileExtension {
        case "jpg", "jpeg":
            contentType = "image/jpeg"
        case "png":
            contentType = "image/png"
        case "mp4":
            contentType = "video/mp4"
        case "mov":
            contentType = "video/quicktime"
        default:
            contentType = "application/octet-stream"
        }

        let metadata = StorageMetadata()
        metadata.contentType = contentType

        mediaRef.putFile(from: mediaURL, metadata: metadata) { metadata, error in
            if let error = error {
                print("Error uploading media: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            mediaRef.downloadURL { url, error in
                if let error = error {
                    print("Error fetching download URL: \(error.localizedDescription)")
                }
                completion(url, error)
            }
        }
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Procedure", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UITableViewDataSource & UITableViewDelegate Methods

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return steps.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "ProcedureStepCell", for: indexPath) as! ProcedureStepCell
        let step = steps[indexPath.row]
        cell.configure(with: step, stepNumber: indexPath.row + 1, brandColor: brandColor)

        // Capture references
        cell.descriptionTextField.delegate = self
        cell.descriptionTextField.tag = indexPath.row

        cell.descriptionChanged = { [weak self] text in
            self?.steps[indexPath.row].description = text
        }

        cell.pinStepAction = { [weak self] in
            guard let self = self else { return }
            let stepDescription = self.steps[indexPath.row].description
            if !stepDescription.isEmpty {
                let arPinVC = ARPinViewController()
                arPinVC.delegate = self
                arPinVC.stepIndex = indexPath.row
                arPinVC.stepDescription = stepDescription
                arPinVC.imageItem = self.imageItem // Pass imageItem
                let navController = UINavigationController(rootViewController: arPinVC)
                navController.modalPresentationStyle = .fullScreen
                self.present(navController, animated: true, completion: nil)
            } else {
                self.showAlert(message: "Please enter a description before pinning the step.")
            }
        }

        // Add media
        cell.addMediaAction = { [weak self] in
            self?.selectedStepIndexForMedia = indexPath.row
            self?.presentMediaPicker()
        }

        // Remove a specific media
        cell.removeSpecificMedia = { [weak self] mediaIndex in
            self?.steps[indexPath.row].media.remove(at: mediaIndex)
            self?.stepsTableView.reloadRows(at: [indexPath], with: .automatic)
        }

        return cell
    }

    // MARK: - Media Picker

    private func presentMediaPicker() {
        let mediaPicker = UIImagePickerController()
        mediaPicker.delegate = self
        mediaPicker.mediaTypes = ["public.image", "public.movie"]
        present(mediaPicker, animated: true)
    }

    // UIImagePickerControllerDelegate methods

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        selectedStepIndexForMedia = nil
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let stepIndex = selectedStepIndexForMedia else {
            picker.dismiss(animated: true, completion: nil)
            return
        }

        // Determine if user picked image or video
        var mediaType = "image"
        var tempURL: URL?

        if let videoURL = info[.mediaURL] as? URL {
            mediaType = "video"
            // Copy video to temporary directory
            let tempDirectory = NSTemporaryDirectory()
            let tempFileName = UUID().uuidString + "." + videoURL.pathExtension
            let tempFileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(tempFileName)
            do {
                try FileManager.default.copyItem(at: videoURL, to: tempFileURL)
                tempURL = tempFileURL
            } catch {
                print("Error copying video: \(error.localizedDescription)")
                showAlert(message: "Failed to copy video. Please try again.")
            }
        } else if let image = info[.originalImage] as? UIImage {
            mediaType = "image"
            // Save image to temporary directory
            if let data = image.jpegData(compressionQuality: 0.8) {
                let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString + ".jpg")
                do {
                    try data.write(to: tempFileURL)
                    tempURL = tempFileURL
                } catch {
                    print("Error saving image: \(error.localizedDescription)")
                    showAlert(message: "Failed to save image. Please try again.")
                }
            }
        }

        // Dismiss the picker first
        picker.dismiss(animated: true) {
            guard let safeURL = tempURL else {
                self.selectedStepIndexForMedia = nil
                return
            }

            // Prompt user for a name for this media
            let alert = UIAlertController(title: "Media Name",
                                          message: "Enter a name for this \(mediaType):",
                                          preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "Media name"
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                self.selectedStepIndexForMedia = nil
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                let mediaName = alert.textFields?.first?.text ?? "Untitled"

                // Create a new ProcedureMedia with the user-provided name
                let newMedia = ProcedureMedia(
                    remoteURL: nil,
                    localURL: safeURL,
                    type: mediaType,
                    name: mediaName
                )
                self.steps[stepIndex].media.append(newMedia)

                // Reload the specific step cell to update the media collection
                self.stepsTableView.reloadRows(
                    at: [IndexPath(row: stepIndex, section: 0)],
                    with: .automatic
                )
                self.selectedStepIndexForMedia = nil
            }))

            self.present(alert, animated: true, completion: nil)
        }
    }

    // MARK: - ARPinDelegate

    func didPinStep(at position: SCNVector3, for stepIndex: Int) {
        steps[stepIndex].position = position
        stepsTableView.reloadData()
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameTextField || textField == descriptionTextField {
            textField.resignFirstResponder()
            return true
        } else {
            // For step description fields
            textField.resignFirstResponder()
            return true
        }
    }
}

// MARK: - ProcedureCell

class ProcedureCell: UITableViewCell {

    // MARK: - Properties

    let containerView = UIView()
    let nameLabel = UILabel()
    let descriptionLabel = UILabel()
    let stepsLabel = UILabel()
    let editButton = UIButton(type: .system)
    let deleteButton = UIButton(type: .system)
    let playButton = UIButton(type: .system)

    var editAction: (() -> Void)?
    var deleteAction: (() -> Void)?
    var playAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupCell()
    }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        // Container View
        containerView.backgroundColor = UIColor(red: 15.0/255.0, green: 12.0/255.0, blue: 50.0/255.0, alpha: 1.0)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Name Label
        nameLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Description Label
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .lightGray
        descriptionLabel.numberOfLines = 2
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        // Steps Label
        stepsLabel.font = UIFont.systemFont(ofSize: 14)
        stepsLabel.textColor = .white
        stepsLabel.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        setupButton(button: editButton, systemName: "pencil", action: #selector(editButtonTapped))
        setupButton(button: deleteButton, systemName: "trash", action: #selector(deleteButtonTapped))
        setupButton(button: playButton, systemName: "play.circle", action: #selector(playButtonTapped))

        let buttonStack = UIStackView(arrangedSubviews: [editButton, deleteButton, playButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.alignment = .center
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Name and Description Stack
        let nameDescriptionStack = UIStackView(arrangedSubviews: [nameLabel, descriptionLabel])
        nameDescriptionStack.axis = .vertical
        nameDescriptionStack.spacing = 4
        nameDescriptionStack.translatesAutoresizingMaskIntoConstraints = false

        // Top Stack (Name, Description, Buttons)
        let topStack = UIStackView(arrangedSubviews: [nameDescriptionStack, buttonStack])
        topStack.axis = .horizontal
        topStack.spacing = 10
        topStack.alignment = .center
        topStack.translatesAutoresizingMaskIntoConstraints = false

        // Content Stack
        let contentStack = UIStackView(arrangedSubviews: [topStack, stepsLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(contentStack)
        contentView.addSubview(containerView)

        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            contentStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            buttonStack.widthAnchor.constraint(equalToConstant: 120)
        ])
    }

    private func setupButton(button: UIButton, systemName: String, action: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func editButtonTapped() {
        editAction?()
    }

    @objc private func deleteButtonTapped() {
        deleteAction?()
    }

    @objc private func playButtonTapped() {
        playAction?()
    }

    func configure(with procedure: Procedure, brandColor: UIColor) {
        nameLabel.text = procedure.name
        descriptionLabel.text = procedure.description
        stepsLabel.text = "\(procedure.steps.count) steps"
        editButton.tintColor = brandColor
        deleteButton.tintColor = brandColor
        playButton.tintColor = brandColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - ProcedureStepCell

protocol ARPinDelegate: AnyObject {
    func didPinStep(at position: SCNVector3, for stepIndex: Int)
}

class ProcedureStepCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // MARK: - Properties

    let descriptionTextField = UITextField()
    let pinButton = UIButton(type: .system)
    let addMediaButton = UIButton(type: .system)

    // A simple horizontal collection to show multiple media
    let mediaCollectionView: UICollectionView
    var mediaItems: [ProcedureMedia] = []

    var descriptionChanged: ((String) -> Void)?
    var pinStepAction: (() -> Void)?
    var addMediaAction: (() -> Void)?
    var removeSpecificMedia: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        // Setup collection view layout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        mediaCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        mediaCollectionView.backgroundColor = .clear

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupCell()
    }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        // Description TextField
        descriptionTextField.backgroundColor = UIColor(red: 15.0/255.0, green: 12.0/255.0, blue: 50.0/255.0, alpha: 1.0)
        descriptionTextField.textColor = .white
        descriptionTextField.layer.cornerRadius = 10
        descriptionTextField.layer.borderWidth = 1
        descriptionTextField.layer.borderColor = UIColor.white.cgColor
        descriptionTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        descriptionTextField.setLeftPaddingPoints(10)
        descriptionTextField.translatesAutoresizingMaskIntoConstraints = false
        descriptionTextField.returnKeyType = .done

        // Pin Button
        pinButton.setTitle("Pin Step", for: .normal)
        pinButton.setTitleColor(.white, for: .normal)
        pinButton.backgroundColor = UIColor.systemBlue
        pinButton.layer.cornerRadius = 10
        pinButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        pinButton.addTarget(self, action: #selector(pinButtonTapped), for: .touchUpInside)
        pinButton.translatesAutoresizingMaskIntoConstraints = false

        // Add Media Button
        addMediaButton.setTitle("Add Media", for: .normal)
        addMediaButton.setTitleColor(.white, for: .normal)
        addMediaButton.backgroundColor = UIColor.systemGreen
        addMediaButton.layer.cornerRadius = 10
        addMediaButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        addMediaButton.addTarget(self, action: #selector(addMediaButtonTapped), for: .touchUpInside)
        addMediaButton.translatesAutoresizingMaskIntoConstraints = false

        // Media Collection View
        mediaCollectionView.register(MediaCell.self, forCellWithReuseIdentifier: "MediaCell")
        mediaCollectionView.delegate = self
        mediaCollectionView.dataSource = self
        mediaCollectionView.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        contentView.addSubview(descriptionTextField)
        contentView.addSubview(pinButton)
        contentView.addSubview(addMediaButton)
        contentView.addSubview(mediaCollectionView)

        // Constraints
        NSLayoutConstraint.activate([
            // Description TextField Constraints
            descriptionTextField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            descriptionTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            descriptionTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            descriptionTextField.heightAnchor.constraint(equalToConstant: 50),

            // Pin Button Constraints
            pinButton.topAnchor.constraint(equalTo: descriptionTextField.bottomAnchor, constant: 10),
            pinButton.leadingAnchor.constraint(equalTo: descriptionTextField.leadingAnchor),
            pinButton.trailingAnchor.constraint(equalTo: descriptionTextField.trailingAnchor),
            pinButton.heightAnchor.constraint(equalToConstant: 40),

            // Add Media Button Constraints
            addMediaButton.topAnchor.constraint(equalTo: pinButton.bottomAnchor, constant: 10),
            addMediaButton.leadingAnchor.constraint(equalTo: descriptionTextField.leadingAnchor),
            addMediaButton.trailingAnchor.constraint(equalTo: descriptionTextField.trailingAnchor),
            addMediaButton.heightAnchor.constraint(equalToConstant: 40),

            // Media Collection View
            mediaCollectionView.topAnchor.constraint(equalTo: addMediaButton.bottomAnchor, constant: 10),
            mediaCollectionView.leadingAnchor.constraint(equalTo: descriptionTextField.leadingAnchor),
            mediaCollectionView.trailingAnchor.constraint(equalTo: descriptionTextField.trailingAnchor),
            mediaCollectionView.heightAnchor.constraint(equalToConstant: 100),
            mediaCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    @objc private func textFieldChanged() {
        descriptionChanged?(descriptionTextField.text ?? "")
    }

    @objc private func pinButtonTapped() {
        pinStepAction?()
    }

    @objc private func addMediaButtonTapped() {
        addMediaAction?()
    }

    func configure(with step: ProcedureStep, stepNumber: Int, brandColor: UIColor) {
        descriptionTextField.text = step.description
        descriptionTextField.placeholder = "Step \(stepNumber)"
        pinButton.backgroundColor = brandColor
        addMediaButton.backgroundColor = brandColor

        if step.position != nil {
            pinButton.setTitle("Pinned ✔︎", for: .normal)
        } else {
            pinButton.setTitle("Pin Step", for: .normal)
        }

        // Update local array
        mediaItems = step.media
        mediaCollectionView.reloadData()
    }

    // MARK: - UICollectionView Delegate / DataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mediaItems.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaCell", for: indexPath) as! MediaCell
        let media = mediaItems[indexPath.item]
        cell.configure(with: media)
        cell.removeAction = { [weak self] in
            self?.removeSpecificMedia?(indexPath.item)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 120, height: 100)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - MediaCell

class MediaCell: UICollectionViewCell {
    let thumbnailImageView = UIImageView()
    let removeButton = UIButton(type: .system)

    var removeAction: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false

        removeButton.setTitle("✕", for: .normal)
        removeButton.setTitleColor(.white, for: .normal)
        removeButton.backgroundColor = .red
        removeButton.layer.cornerRadius = 12
        removeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        removeButton.addTarget(self, action: #selector(handleRemove), for: .touchUpInside)
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(removeButton)

        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            removeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            removeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            removeButton.widthAnchor.constraint(equalToConstant: 24),
            removeButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @objc private func handleRemove() {
        removeAction?()
    }

    func configure(with media: ProcedureMedia) {
        // If local URL exists, load thumbnail from local file
        if let localURL = media.localURL {
            if media.type == "image" {
                let image = UIImage(contentsOfFile: localURL.path)
                thumbnailImageView.image = image ?? UIImage(systemName: "photo")
                thumbnailImageView.contentMode = .scaleAspectFill
            } else {
                // For simplicity, use a generic video icon
                thumbnailImageView.image = UIImage(systemName: "film")
                thumbnailImageView.contentMode = .scaleAspectFit
            }
        } else if let remoteURL = media.remoteURL {
            // Load from remote
            // Check type
            if media.type == "image" {
                thumbnailImageView.loadImage(from: remoteURL)
            } else {
                // For simplicity, use a generic video icon
                thumbnailImageView.image = UIImage(systemName: "film")
                thumbnailImageView.contentMode = .scaleAspectFit
            }
        } else {
            thumbnailImageView.image = UIImage(systemName: "paperclip")
            thumbnailImageView.contentMode = .scaleAspectFit
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - ARPinViewController

class ARPinViewController: UIViewController, ARSCNViewDelegate {

    // MARK: - Properties

    weak var delegate: ARPinDelegate?
    var stepIndex: Int!
    var stepDescription: String!
    var imageItem: ImageItem!

    private var sceneView: ARSCNView!
    private var imageAnchorNode: SCNNode?
    private var isImageDetected = false
    private var detectionOverlayView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupNavigationBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupARSession()
    }

    private func setupNavigationBar() {
        title = "Pin Step"
        navigationController?.navigationBar.tintColor = .white
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(handleBack)
        )
    }

    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }

    private func setupARView() {
        sceneView = ARSCNView(frame: self.view.bounds)
        sceneView.delegate = self
        self.view.addSubview(sceneView)

        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }

    private func setupARSession() {
        guard let imageItem = imageItem else {
            print("No imageItem provided.")
            return
        }

        // Load the image from imageItem.imageURL
        DispatchQueue.global().async {
            if let imageData = try? Data(contentsOf: imageItem.imageURL),
               let uiImage = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    // Create ARReferenceImage from uiImage
                    guard let cgImage = uiImage.cgImage else {
                        print("Failed to get cgImage from uiImage.")
                        return
                    }

                    let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.2)
                    referenceImage.name = imageItem.name

                    let configuration = ARWorldTrackingConfiguration()
                    configuration.detectionImages = [referenceImage]

                    self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                }
            } else {
                print("Failed to load image data from imageURL.")
            }
        }
    }

    @objc private func handleTap(_ gestureRecognize: UITapGestureRecognizer) {
        guard isImageDetected, let imageAnchorNode = imageAnchorNode else {
            let alert = UIAlertController(title: "Image Not Detected", message: "Please detect the image before pinning the step.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let location = gestureRecognize.location(in: sceneView)
        let hitResults = sceneView.hitTest(location, types: [.existingPlaneUsingExtent, .featurePoint])
        if let result = hitResults.first {
            let worldTransform = result.worldTransform
            let worldPosition = SCNVector3(
                worldTransform.columns.3.x,
                worldTransform.columns.3.y,
                worldTransform.columns.3.z
            )

            // Convert world position to image anchor's local coordinate system
            let localPosition = imageAnchorNode.convertPosition(worldPosition, from: nil)

            delegate?.didPinStep(at: localPosition, for: stepIndex)

            // Show confirmation
            let alert = UIAlertController(title: "Step Pinned", message: "Step has been pinned at the selected location.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { _ in
                self.dismiss(animated: true, completion: nil)
            }))
            present(alert, animated: true, completion: nil)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor {
            DispatchQueue.main.async {
                self.imageAnchorNode = node
                self.isImageDetected = true
                self.showImageDetectedOverlay()
                print("Image detected: \(imageAnchor.referenceImage.name ?? "Unknown")")
            }
        }
    }

    private func showImageDetectedOverlay() {
        // Create an overlay view
        let overlayView = UIView(frame: self.view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.alpha = 0.0

        // Create a tick image view
        let tickImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        tickImageView.tintColor = UIColor.green
        tickImageView.contentMode = .scaleAspectFit
        tickImageView.translatesAutoresizingMaskIntoConstraints = false

        // Create a label
        let messageLabel = UILabel()
        messageLabel.text = "Image Detected"
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        overlayView.addSubview(tickImageView)
        overlayView.addSubview(messageLabel)

        // Add constraints
        NSLayoutConstraint.activate([
            tickImageView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            tickImageView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -20),
            tickImageView.widthAnchor.constraint(equalToConstant: 100),
            tickImageView.heightAnchor.constraint(equalToConstant: 100),

            messageLabel.topAnchor.constraint(equalTo: tickImageView.bottomAnchor, constant: 20),
            messageLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor)
        ])

        // Add overlay to the view
        self.view.addSubview(overlayView)
        self.detectionOverlayView = overlayView

        // Animate the overlay
        UIView.animate(withDuration: 0.5, animations: {
            overlayView.alpha = 1.0
        }) { _ in
            // Fade out after a delay
            UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
                overlayView.alpha = 0.0
            }, completion: { _ in
                overlayView.removeFromSuperview()
            })
        }
    }
}

// MARK: - ProcedureARViewController

class ProcedureARViewController: UIViewController, ARSCNViewDelegate {

    // MARK: - Properties

    var procedure: Procedure!
    var imageItem: ImageItem!

    private var sceneView: ARSCNView!
    private var imageAnchorNode: SCNNode?
    private var isImageDetected = false
    private var detectionOverlayView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupNavigationBar()

        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupARSession()
    }

    private func setupNavigationBar() {
        title = "Procedure"
        navigationController?.navigationBar.tintColor = .white
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(handleBack)
        )
    }

    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }

    private func setupARView() {
        sceneView = ARSCNView(frame: self.view.bounds)
        sceneView.delegate = self
        self.view.addSubview(sceneView)
    }

    private func setupARSession() {
        guard let imageItem = imageItem else {
            print("No imageItem provided.")
            return
        }

        // Load the image from imageItem.imageURL
        DispatchQueue.global().async {
            if let imageData = try? Data(contentsOf: imageItem.imageURL),
               let uiImage = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    // Create ARReferenceImage from uiImage
                    guard let cgImage = uiImage.cgImage else {
                        print("Failed to get cgImage from uiImage.")
                        return
                    }

                    let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.2)
                    referenceImage.name = imageItem.name

                    let configuration = ARWorldTrackingConfiguration()
                    configuration.detectionImages = [referenceImage]

                    self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                }
            } else {
                print("Failed to load image data from imageURL.")
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Display steps when the image is detected
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor {
            DispatchQueue.main.async {
                self.imageAnchorNode = node
                self.isImageDetected = true
                self.showImageDetectedOverlay()
                print("Image detected: \(imageAnchor.referenceImage.name ?? "Unknown")")
                self.displayProcedureSteps()
            }
        }
    }

    private func displayProcedureSteps() {
        guard let imageAnchorNode = imageAnchorNode else { return }

        for (index, step) in procedure.steps.enumerated() {
            if let position = step.position {
                addTextNode(stepIndex: index,
                            stepNumber: index + 1,
                            text: step.description,
                            at: position,
                            mediaItems: step.media)
            } else {
                print("Step \(step.description) does not have a pinned position.")
            }
        }
    }

    private enum MediaType {
        case image
        case video
        case unknown
    }

    private func addTextNode(stepIndex: Int,
                             stepNumber: Int,
                             text: String,
                             at position: SCNVector3,
                             mediaItems: [ProcedureMedia]) {
        // Step 1: Create and configure the step number label
        let stepLabel = UILabel()
        stepLabel.text = "\(stepNumber)"
        stepLabel.textColor = .white
        stepLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        stepLabel.textAlignment = .center

        // Create circular background for step number
        let circleSize: CGFloat = 36
        let circleView = UIView(frame: CGRect(x: 0, y: 0, width: circleSize, height: circleSize))
        circleView.backgroundColor = UIColor(red: 0.0/255.0, green: 146.0/255.0, blue: 155.0/255.0, alpha: 1.0)
        circleView.layer.cornerRadius = circleSize / 2
        circleView.layer.borderWidth = 2
        circleView.layer.borderColor = UIColor.white.cgColor

        stepLabel.frame = circleView.bounds
        circleView.addSubview(stepLabel)

        // Step 2: Create and configure the description label
        let descLabel = UILabel()
        descLabel.text = text
        descLabel.textColor = .white
        descLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        descLabel.numberOfLines = 0
        descLabel.textAlignment = .left

        // Step 3: Calculate sizes
        let maxLabelWidth: CGFloat = 200
        let labelSize = descLabel.sizeThatFits(CGSize(width: maxLabelWidth, height: CGFloat.greatestFiniteMagnitude))
        let padding: CGFloat = 12

        let containerWidth = labelSize.width + circleSize + (padding * 3)

        // Step 4: Create the container view
        let containerView = UIView()
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        containerView.layer.cornerRadius = 18
        containerView.layer.borderColor = UIColor.white.cgColor
        containerView.layer.borderWidth = 1.5
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.5
        containerView.layer.shadowOffset = CGSize(width: 2, height: 2)
        containerView.layer.shadowRadius = 4

        // Step 5: Position the circle and labels
        circleView.frame.origin = CGPoint(x: padding, y: padding)

        descLabel.frame = CGRect(
            x: circleView.frame.maxX + padding,
            y: padding,
            width: labelSize.width,
            height: labelSize.height
        )

        containerView.addSubview(circleView)
        containerView.addSubview(descLabel)

        var contentHeight = max(circleView.frame.maxY, descLabel.frame.maxY)

        // Step 6: Add a media indicator if there's at least one media item
        if !mediaItems.isEmpty {
            let iconName = "paperclip.circle.fill"
            let mediaIconImage = UIImage(systemName: iconName)
            let mediaIconImageView = UIImageView(image: mediaIconImage)
            mediaIconImageView.tintColor = .white
            mediaIconImageView.contentMode = .scaleAspectFit

            let mediaIconSize: CGFloat = 20
            mediaIconImageView.frame = CGRect(
                x: containerWidth - padding - mediaIconSize,
                y: contentHeight + padding,
                width: mediaIconSize,
                height: mediaIconSize
            )
            containerView.addSubview(mediaIconImageView)

            contentHeight = mediaIconImageView.frame.maxY
        }

        // Adjust containerHeight to contentHeight plus padding
        let containerHeight = contentHeight + padding

        containerView.frame = CGRect(origin: .zero, size: CGSize(width: containerWidth, height: containerHeight))

        // Step 7: Create the tail
        let tailPath = UIBezierPath()
        let tailWidth: CGFloat = 12
        let tailHeight: CGFloat = 12
        let tailX = containerWidth / 2

        tailPath.move(to: CGPoint(x: tailX - tailWidth/2, y: containerView.frame.height))
        tailPath.addLine(to: CGPoint(x: tailX, y: containerView.frame.height + tailHeight))
        tailPath.addLine(to: CGPoint(x: tailX + tailWidth/2, y: containerView.frame.height))
        tailPath.close()

        let tailLayer = CAShapeLayer()
        tailLayer.path = tailPath.cgPath
        tailLayer.fillColor = UIColor.black.withAlphaComponent(0.85).cgColor
        containerView.layer.addSublayer(tailLayer)

        // Step 8: Render to image
        let totalHeight = containerView.frame.height + tailHeight
        UIGraphicsBeginImageContextWithOptions(CGSize(width: containerView.frame.width, height: totalHeight), false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return
        }
        containerView.layer.render(in: context)
        guard let annotationImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return
        }
        UIGraphicsEndImageContext()

        // Step 9: Create and configure the SCNPlane
        let scalingFactor: CGFloat = 0.0015
        let planeWidth = containerWidth * scalingFactor
        let planeHeight = totalHeight * scalingFactor

        let plane = SCNPlane(width: planeWidth, height: planeHeight)
        plane.firstMaterial?.diffuse.contents = annotationImage
        plane.firstMaterial?.isDoubleSided = true

        let annotationNode = SCNNode(geometry: plane)
        annotationNode.position = position

        // Store the stepIndex in the node's name
        annotationNode.name = "step_\(stepIndex)"

        // Step 10: Add billboard constraint
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = .all
        annotationNode.constraints = [constraint]

        // Step 11: Add to scene
        imageAnchorNode?.addChildNode(annotationNode)
    }

    @objc private func handleTap(_ gestureRecognize: UITapGestureRecognizer) {
        let location = gestureRecognize.location(in: sceneView)
        let hitResults = sceneView.hitTest(location, options: nil)
        if let hitResult = hitResults.first {
            let node = hitResult.node
            if let nodeName = node.name, nodeName.starts(with: "step_") {
                // Extract the stepIndex from the node's name
                let stepIndexString = nodeName.replacingOccurrences(of: "step_", with: "")
                if let stepIndex = Int(stepIndexString) {
                    let step = procedure.steps[stepIndex]
                    let media = step.media
                    if media.isEmpty {
                        let alert = UIAlertController(title: "No Media", message: "This step does not have associated media.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        present(alert, animated: true)
                    } else if media.count == 1 {
                        // If only one media item, present immediately
                        presentMedia(for: media[0])
                    } else {
                        // If multiple media items, present a simple list
                        presentMediaList(media)
                    }
                }
            }
        }
    }

    private func presentMediaList(_ mediaList: [ProcedureMedia]) {
        let alert = UIAlertController(title: "Select Media", message: nil, preferredStyle: .actionSheet)
        for (index, mediaItem) in mediaList.enumerated() {
            // Use the media name if it exists, otherwise fallback
            let safeName = mediaItem.name.isEmpty
                ? ((mediaItem.type == "image") ? "Image \(index+1)" : "Video \(index+1)")
                : mediaItem.name
            
            alert.addAction(UIAlertAction(title: safeName, style: .default, handler: { _ in
                self.presentMedia(for: mediaItem)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func presentMedia(for mediaItem: ProcedureMedia) {
        guard let url = mediaItem.remoteURL ?? mediaItem.localURL else {
            // Unsupported media
            let alert = UIAlertController(title: "Media Error", message: "Cannot display the selected media.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        if mediaItem.type == "image" {
            // Present image
            let mediaVC = UIViewController()
            mediaVC.view.backgroundColor = .black
            let imageView = UIImageView(frame: mediaVC.view.bounds)
            imageView.contentMode = .scaleAspectFit
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            imageView.loadImage(from: url)
            mediaVC.view.addSubview(imageView)
            mediaVC.modalPresentationStyle = .overFullScreen
            mediaVC.modalTransitionStyle = .crossDissolve

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissMediaVC))
            mediaVC.view.addGestureRecognizer(tapGesture)

            present(mediaVC, animated: true)
        } else if mediaItem.type == "video" {
            // Present video
            let player = AVPlayer(url: url)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            present(playerViewController, animated: true) {
                player.play()
            }
        }
    }

    @objc private func dismissMediaVC(_ gesture: UITapGestureRecognizer) {
        dismiss(animated: true)
    }

    private func showImageDetectedOverlay() {
        // Create an overlay view
        let overlayView = UIView(frame: self.view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.alpha = 0.0

        // Create a tick image view
        let tickImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        tickImageView.tintColor = UIColor.green
        tickImageView.contentMode = .scaleAspectFit
        tickImageView.translatesAutoresizingMaskIntoConstraints = false

        // Create a label
        let messageLabel = UILabel()
        messageLabel.text = "Image Detected"
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        overlayView.addSubview(tickImageView)
        overlayView.addSubview(messageLabel)

        // Add constraints
        NSLayoutConstraint.activate([
            tickImageView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            tickImageView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -20),
            tickImageView.widthAnchor.constraint(equalToConstant: 100),
            tickImageView.heightAnchor.constraint(equalToConstant: 100),

            messageLabel.topAnchor.constraint(equalTo: tickImageView.bottomAnchor, constant: 20),
            messageLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor)
        ])

        // Add overlay to the view
        self.view.addSubview(overlayView)
        self.detectionOverlayView = overlayView

        // Animate the overlay
        UIView.animate(withDuration: 0.5, animations: {
            overlayView.alpha = 1.0
        }) { _ in
            // Fade out after a delay
            UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
                overlayView.alpha = 0.0
            }, completion: { _ in
                overlayView.removeFromSuperview()
            })
        }
    }
}

// MARK: - Models

/// Represents a single media file within a step.
/// ADDED: `name` field, so the user can name each image/video.
struct ProcedureMedia {
    var remoteURL: URL?
    var localURL: URL?
    var type: String // "image" or "video"
    var name: String  // e.g. "Left Wing View", "Cabin Overview", etc.
}

/// Represents an entire procedure with multiple steps.
struct Procedure {
    let id: String
    var name: String
    var description: String
    var steps: [ProcedureStep]
    var createdAt: Date

    static func fromFirestore(data: [String: Any], id: String) -> Procedure? {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let stepsData = data["steps"] as? [[String: Any]] else {
            return nil
        }

        var steps: [ProcedureStep] = []
        for stepData in stepsData {
            if let step = ProcedureStep.fromFirestore(data: stepData) {
                steps.append(step)
            }
        }

        return Procedure(
            id: id,
            name: name,
            description: description,
            steps: steps,
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}

/// Represents a single step in a procedure, which can have multiple media files.
struct ProcedureStep {
    var description: String
    var position: SCNVector3?
    var media: [ProcedureMedia]

    static func fromFirestore(data: [String: Any]) -> ProcedureStep? {
        guard let description = data["description"] as? String else { return nil }

        var position: SCNVector3? = nil
        if let positionData = data["position"] as? [String: Any],
           let x = positionData["x"] as? Float,
           let y = positionData["y"] as? Float,
           let z = positionData["z"] as? Float {
            position = SCNVector3(x, y, z)
        }

        // Parse media array
        var mediaList: [ProcedureMedia] = []
        if let mediaData = data["media"] as? [[String: Any]] {
            for m in mediaData {
                let urlString = m["url"] as? String
                let type = m["type"] as? String ?? "image"
                let name = m["name"] as? String ?? ""
                var remoteURL: URL?
                if let urlString = urlString {
                    remoteURL = URL(string: urlString)
                }
                let mediaItem = ProcedureMedia(
                    remoteURL: remoteURL,
                    localURL: nil,
                    type: type,
                    name: name
                )
                mediaList.append(mediaItem)
            }
        }

        return ProcedureStep(description: description, position: position, media: mediaList)
    }
}

// MARK: - UIImageView Extension

extension UIImageView {
    func loadImage(from url: URL) {
        DispatchQueue.global().async {
            var data: Data?
            if url.isFileURL {
                data = try? Data(contentsOf: url)
            } else {
                data = try? Data(contentsOf: url)
            }
            if let data = data,
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = image
                    self.contentMode = .scaleAspectFit
                }
            } else {
                // Handle error or set a placeholder image
                DispatchQueue.main.async {
                    self.image = UIImage(systemName: "photo") // Placeholder image
                    self.contentMode = .scaleAspectFit
                }
            }
        }
    }
}
