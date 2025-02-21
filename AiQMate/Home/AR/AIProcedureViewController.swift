import UIKit
import FirebaseFirestore
import FirebaseStorage
import ARKit
import SceneKit
import AVKit
import Speech  // For transcription

// MARK: - AIProcedureViewController

class AIProcedureViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AIProcedureFormDelegate {

    // MARK: - Properties

    var aiProcedures: [AIProcedure] = []
    var containerID: String!
    var imageItem: ImageItem!

    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)

    private let tableView = UITableView()
    private let createButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create AI Procedure", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
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

    private var listener: ListenerRegistration?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupCreateButton()
        setupTableView()
        fetchAIProcedures()

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
        listener?.remove()
    }

    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Setup

    private func setupView() {
        view.backgroundColor = backgroundColor
        title = "AI Procedures"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
    }

    private func setupCreateButton() {
        createButton.addTarget(self, action: #selector(handleCreateAIProcedure), for: .touchUpInside)
        view.addSubview(createButton)

        NSLayoutConstraint.activate([
            createButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            createButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupTableView() {
        tableView.register(AIProcedureCell.self, forCellReuseIdentifier: "AIProcedureCell")
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
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Action Methods

    @objc private func handleCreateAIProcedure() {
        let formVC = AIProcedureFormViewController()
        formVC.delegate = self
        formVC.containerID = self.containerID
        formVC.imageItem = self.imageItem
        let nav = UINavigationController(rootViewController: formVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - Fetch AI Procedures

    private func fetchAIProcedures() {
        let db = Firestore.firestore()
        listener = db.collection("aiProcedures")
            .whereField("containerID", isEqualTo: self.containerID)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, error in
                if let error = error {
                    print("Error listening for AI procedures: \(error)")
                    return
                }
                guard let self = self else { return }
                self.aiProcedures.removeAll()

                for doc in snap?.documents ?? [] {
                    let data = doc.data()
                    if let procedure = AIProcedure.fromFirestore(data: data, id: doc.documentID) {
                        self.aiProcedures.append(procedure)
                    }
                }
                self.tableView.reloadData()
            }
    }

    // MARK: - Table DataSource / Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return aiProcedures.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "AIProcedureCell", for: indexPath) as! AIProcedureCell
        let procedure = aiProcedures[indexPath.row]
        cell.configure(with: procedure, brandColor: brandColor)

        cell.editAction = { [weak self] in
            self?.handleEditAIProcedure(procedure)
        }
        cell.deleteAction = { [weak self] in
            self?.handleDeleteAIProcedure(procedure)
        }
        cell.playAction = { [weak self] in
            self?.handlePlayAIProcedure(procedure)
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - AIProcedureFormDelegate

    func didSaveAIProcedure() {
        fetchAIProcedures()
    }

    // MARK: - Edit, Delete, and Play

    private func handleEditAIProcedure(_ procedure: AIProcedure) {
        let formVC = AIProcedureFormViewController()
        formVC.delegate = self
        formVC.procedureToEdit = procedure
        formVC.containerID = self.containerID
        formVC.imageItem = self.imageItem
        let nav = UINavigationController(rootViewController: formVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func handleDeleteAIProcedure(_ procedure: AIProcedure) {
        let alert = UIAlertController(
            title: "Delete AI Procedure",
            message: "Are you sure you want to delete this AI procedure? This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.deleteFromFirestore(procedure)
        }))
        present(alert, animated: true)
    }

    private func deleteFromFirestore(_ procedure: AIProcedure) {
        let db = Firestore.firestore()
        db.collection("aiProcedures").document(procedure.id).delete { [weak self] error in
            if let error = error {
                print("Error removing AI procedure: \(error.localizedDescription)")
                let alert = UIAlertController(
                    title: "Error",
                    message: "Failed to delete AI procedure. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
                return
            }
            self?.aiProcedures.removeAll { $0.id == procedure.id }
            self?.tableView.reloadData()

            let successAlert = UIAlertController(
                title: "Success",
                message: "AI procedure deleted successfully",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(successAlert, animated: true)
        }
    }

    private func handlePlayAIProcedure(_ procedure: AIProcedure) {
        // This AR VC only shows the generated text in a container (no video).
        let arVC = AIProcedureARViewController()
        arVC.procedure = procedure
        arVC.imageItem = self.imageItem
        let nav = UINavigationController(rootViewController: arVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
}

// MARK: - AIProcedureFormViewController

protocol AIProcedureFormDelegate: AnyObject {
    func didSaveAIProcedure()
}

class AIProcedureFormViewController: UIViewController,
                                    UITextFieldDelegate,
                                    ARPinDelegate,
                                    UIImagePickerControllerDelegate,
                                    UINavigationControllerDelegate {

    weak var delegate: AIProcedureFormDelegate?
    var procedureToEdit: AIProcedure?
    var containerID: String!
    var imageItem: ImageItem!

    let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)

    let nameTextField = UITextField()
    let descriptionTextField = UITextField()
    let addVideoButton = UIButton(type: .system)
    let videoStatusLabel = UILabel()
    let generateStepsButton = UIButton(type: .system)
    let stepsTextView = UITextView()
    let pinButton = UIButton(type: .system)

    let activityIndicator = UIActivityIndicatorView(style: .large)

    // Single-step approach
    var step = AIProcedureStep(description: "", position: nil, mediaURL: nil, mediaLocalURL: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavBar()
        setupForm()
        setupKeyboardDismissal()
    }

    private func setupView() {
        view.backgroundColor = backgroundColor
    }

    private func setupNavBar() {
        title = procedureToEdit == nil ? "Create AI Procedure" : "Edit AI Procedure"
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
        nameTextField.placeholder = "Procedure Name"
        nameTextField.backgroundColor = UIColor(red: 15/255, green: 12/255, blue: 50/255, alpha: 1.0)
        nameTextField.textColor = .white
        nameTextField.layer.cornerRadius = 10
        nameTextField.layer.borderWidth = 1
        nameTextField.layer.borderColor = UIColor.white.cgColor
        nameTextField.setLeftPaddingPoints(10)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.delegate = self
        nameTextField.returnKeyType = .done

        descriptionTextField.placeholder = "Procedure Description"
        descriptionTextField.backgroundColor = UIColor(red: 15/255, green: 12/255, blue: 50/255, alpha: 1.0)
        descriptionTextField.textColor = .white
        descriptionTextField.layer.cornerRadius = 10
        descriptionTextField.layer.borderWidth = 1
        descriptionTextField.layer.borderColor = UIColor.white.cgColor
        descriptionTextField.setLeftPaddingPoints(10)
        descriptionTextField.translatesAutoresizingMaskIntoConstraints = false
        descriptionTextField.delegate = self
        descriptionTextField.returnKeyType = .done

        addVideoButton.setTitle("Add Video", for: .normal)
        addVideoButton.setTitleColor(.white, for: .normal)
        addVideoButton.backgroundColor = brandColor
        addVideoButton.layer.cornerRadius = 10
        addVideoButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        addVideoButton.addTarget(self, action: #selector(handleAddVideo), for: .touchUpInside)
        addVideoButton.translatesAutoresizingMaskIntoConstraints = false

        videoStatusLabel.text = ""
        videoStatusLabel.textColor = .green
        videoStatusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        videoStatusLabel.textAlignment = .center
        videoStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        generateStepsButton.setTitle("Generate Steps (AI)", for: .normal)
        generateStepsButton.setTitleColor(.white, for: .normal)
        generateStepsButton.backgroundColor = brandColor
        generateStepsButton.layer.cornerRadius = 10
        generateStepsButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        generateStepsButton.addTarget(self, action: #selector(handleGenerateSteps), for: .touchUpInside)
        generateStepsButton.translatesAutoresizingMaskIntoConstraints = false

        stepsTextView.backgroundColor = UIColor(red: 15/255, green: 12/255, blue: 50/255, alpha: 1.0)
        stepsTextView.textColor = .white
        stepsTextView.font = UIFont.systemFont(ofSize: 16)
        stepsTextView.layer.cornerRadius = 10
        stepsTextView.layer.borderWidth = 1
        stepsTextView.layer.borderColor = UIColor.white.cgColor
        stepsTextView.translatesAutoresizingMaskIntoConstraints = false
        stepsTextView.isEditable = false

        pinButton.setTitle("Pin Steps", for: .normal)
        pinButton.setTitleColor(.white, for: .normal)
        pinButton.backgroundColor = brandColor
        pinButton.layer.cornerRadius = 10
        pinButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        pinButton.addTarget(self, action: #selector(handlePinStep), for: .touchUpInside)
        pinButton.translatesAutoresizingMaskIntoConstraints = false

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        view.addSubview(nameTextField)
        view.addSubview(descriptionTextField)
        view.addSubview(addVideoButton)
        view.addSubview(videoStatusLabel)
        view.addSubview(generateStepsButton)
        view.addSubview(stepsTextView)
        view.addSubview(pinButton)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nameTextField.heightAnchor.constraint(equalToConstant: 50),

            descriptionTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 10),
            descriptionTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            descriptionTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            descriptionTextField.heightAnchor.constraint(equalToConstant: 50),

            addVideoButton.topAnchor.constraint(equalTo: descriptionTextField.bottomAnchor, constant: 10),
            addVideoButton.leadingAnchor.constraint(equalTo: descriptionTextField.leadingAnchor),
            addVideoButton.trailingAnchor.constraint(equalTo: descriptionTextField.trailingAnchor),
            addVideoButton.heightAnchor.constraint(equalToConstant: 50),

            videoStatusLabel.topAnchor.constraint(equalTo: addVideoButton.bottomAnchor, constant: 5),
            videoStatusLabel.leadingAnchor.constraint(equalTo: addVideoButton.leadingAnchor),
            videoStatusLabel.trailingAnchor.constraint(equalTo: addVideoButton.trailingAnchor),
            videoStatusLabel.heightAnchor.constraint(equalToConstant: 20),

            generateStepsButton.topAnchor.constraint(equalTo: videoStatusLabel.bottomAnchor, constant: 10),
            generateStepsButton.leadingAnchor.constraint(equalTo: addVideoButton.leadingAnchor),
            generateStepsButton.trailingAnchor.constraint(equalTo: addVideoButton.trailingAnchor),
            generateStepsButton.heightAnchor.constraint(equalToConstant: 50),

            stepsTextView.topAnchor.constraint(equalTo: generateStepsButton.bottomAnchor, constant: 10),
            stepsTextView.leadingAnchor.constraint(equalTo: generateStepsButton.leadingAnchor),
            stepsTextView.trailingAnchor.constraint(equalTo: generateStepsButton.trailingAnchor),
            stepsTextView.heightAnchor.constraint(equalToConstant: 200),

            pinButton.topAnchor.constraint(equalTo: stepsTextView.bottomAnchor, constant: 10),
            pinButton.leadingAnchor.constraint(equalTo: stepsTextView.leadingAnchor),
            pinButton.trailingAnchor.constraint(equalTo: stepsTextView.trailingAnchor),
            pinButton.heightAnchor.constraint(equalToConstant: 50),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        if let p = procedureToEdit {
            nameTextField.text = p.name
            descriptionTextField.text = p.description
            if let existingStep = p.steps.first {
                step = existingStep
                if !step.description.isEmpty {
                    stepsTextView.text = step.description
                }
                if step.position != nil {
                    pinButton.setTitle("Pinned ✔︎", for: .normal)
                }
            }
        }
    }

    private func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func handleCancel() {
        dismiss(animated: true)
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
        guard !stepsTextView.text.isEmpty else {
            showAlert(message: "Please generate steps using AI before saving.")
            return
        }
        step.description = stepsTextView.text
        saveAIProcedure(name: name, description: description, step: step)
    }

    @objc private func handleAddVideo() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.mediaTypes = ["public.movie"]
        present(picker, animated: true)
    }

    @objc private func handleGenerateSteps() {
        guard let name = nameTextField.text, !name.isEmpty,
              let desc = descriptionTextField.text, !desc.isEmpty else {
            showAlert(message: "Enter procedure name & description before generating steps.")
            return
        }
        guard let localVideoURL = step.mediaLocalURL else {
            showAlert(message: "Please select a video before generating steps.")
            return
        }

        activityIndicator.startAnimating()
        SFSpeechRecognizer.requestAuthorization { authStatus in
            if authStatus == .authorized {
                self.convertVideoToAudio(videoURL: localVideoURL) { audioURL, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                            self.showAlert(message: "Audio extraction failed: \(error.localizedDescription)")
                        }
                        return
                    }
                    guard let audioURL = audioURL else {
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                            self.showAlert(message: "Unable to extract audio from video.")
                        }
                        return
                    }
                    self.transcribeAudioFile(audioURL: audioURL) { transcription, error in
                        if let error = error {
                            DispatchQueue.main.async {
                                self.activityIndicator.stopAnimating()
                                self.showAlert(message: "Audio transcription failed: \(error.localizedDescription)")
                            }
                            return
                        }
                        guard let transcription = transcription, !transcription.isEmpty else {
                            DispatchQueue.main.async {
                                self.activityIndicator.stopAnimating()
                                self.showAlert(message: "No transcription was returned.")
                            }
                            return
                        }
                        self.generateStepsUsingChatGPT(name: name, description: desc, transcription: transcription)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlert(message: "Speech recognition authorization denied.")
                }
            }
        }
    }

    @objc private func handlePinStep() {
        guard !stepsTextView.text.isEmpty else {
            showAlert(message: "Please generate steps before pinning.")
            return
        }
        let desc = stepsTextView.text!
        let arPinVC = ARPinViewController()
        arPinVC.delegate = self
        arPinVC.stepIndex = 0
        arPinVC.stepDescription = desc
        arPinVC.imageItem = self.imageItem
        let nav = UINavigationController(rootViewController: arPinVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "AI Procedure", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func convertVideoToAudio(videoURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        let asset = AVAsset(url: videoURL)
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".m4a")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            let err = NSError(domain: "AIProcedure", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session."])
            completion(nil, err)
            return
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(outputURL, nil)
            case .failed, .cancelled:
                completion(nil, exportSession.error)
            default:
                break
            }
        }
    }

    private func transcribeAudioFile(audioURL: URL, completion: @escaping (String?, Error?) -> Void) {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        let request = SFSpeechURLRecognitionRequest(url: audioURL)

        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let result = result, result.isFinal else { return }
            completion(result.bestTranscription.formattedString, nil)
        }
    }

    private func generateStepsUsingChatGPT(name: String, description: String, transcription: String) {
        let openAIKey = Config.openAIAPIKey
        let userMessage = """
        You are a helpful assistant. Given the following transcription from a video:
        "\(transcription)"
        Create a clear, step-by-step procedure for \(name), described as \(description).
        """

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.showAlert(message: "Invalid OpenAI Chat endpoint URL.")
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "user", "content": userMessage]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
            }
            if let error = error {
                DispatchQueue.main.async {
                    self.showAlert(message: "Failed to generate steps. Error: \(error.localizedDescription)")
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.showAlert(message: "No data from OpenAI.")
                }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    DispatchQueue.main.async {
                        self.stepsTextView.text = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showAlert(message: "Unexpected response from OpenAI.")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(message: "Error parsing OpenAI response.")
                }
            }
        }

        task.resume()
    }

    private func saveAIProcedure(name: String, description: String, step: AIProcedureStep) {
        let db = Firestore.firestore()

        var stepData: [String: Any] = ["description": step.description]
        if let position = step.position {
            stepData["position"] = ["x": position.x, "y": position.y, "z": position.z]
        }

        var stepsData: [[String: Any]] = []

        // If there's local video, upload
        if let localURL = step.mediaLocalURL {
            uploadMedia(localURL: localURL) { [weak self] url, error in
                guard let self = self else { return }
                if let error = error {
                    self.showAlert(message: "Failed to upload media. \(error.localizedDescription)")
                    return
                }
                if let url = url {
                    stepData["mediaURL"] = url.absoluteString
                }
                stepsData.append(stepData)
                self.finalizeSaving(db: db, name: name, description: description, stepsData: stepsData)
            }
        } else if let remoteURL = step.mediaURL {
            stepData["mediaURL"] = remoteURL.absoluteString
            stepsData.append(stepData)
            finalizeSaving(db: db, name: name, description: description, stepsData: stepsData)
        } else {
            stepsData.append(stepData)
            finalizeSaving(db: db, name: name, description: description, stepsData: stepsData)
        }
    }

    private func finalizeSaving(db: Firestore,
                                name: String,
                                description: String,
                                stepsData: [[String: Any]]) {
        let docData: [String: Any] = [
            "name": name,
            "description": description,
            "steps": stepsData,
            "createdAt": FieldValue.serverTimestamp(),
            "containerID": self.containerID ?? "Unknown"
        ]

        if let editingProc = procedureToEdit {
            db.collection("aiProcedures").document(editingProc.id).setData(docData) { error in
                if let error = error {
                    self.showAlert(message: "Failed to update procedure. \(error.localizedDescription)")
                    return
                }
                self.delegate?.didSaveAIProcedure()
                self.dismiss(animated: true)
            }
        } else {
            db.collection("aiProcedures").addDocument(data: docData) { error in
                if let error = error {
                    self.showAlert(message: "Failed to save procedure. \(error.localizedDescription)")
                    return
                }
                self.delegate?.didSaveAIProcedure()
                self.dismiss(animated: true)
            }
        }
    }

    private func uploadMedia(localURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        let storageRef = Storage.storage().reference()
        let mediaID = UUID().uuidString
        let fileExt = localURL.pathExtension.lowercased()
        let mediaRef = storageRef.child("aiProcedureMedia/\(mediaID).\(fileExt)")

        var contentType: String
        switch fileExt {
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

        mediaRef.putFile(from: localURL, metadata: metadata) { _, error in
            if let error = error {
                completion(nil, error)
                return
            }
            mediaRef.downloadURL { url, error in
                completion(url, error)
            }
        }
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedVideoURL = info[.mediaURL] as? URL {
            let tempDir = NSTemporaryDirectory()
            let tempName = UUID().uuidString + "." + pickedVideoURL.pathExtension
            let tempFileURL = URL(fileURLWithPath: tempDir).appendingPathComponent(tempName)
            do {
                try FileManager.default.copyItem(at: pickedVideoURL, to: tempFileURL)
                step.mediaLocalURL = tempFileURL
                step.mediaURL = nil
                videoStatusLabel.text = "Video selected successfully!"
            } catch {
                print("Error copying video: \(error.localizedDescription)")
                showAlert(message: "Failed to copy video.")
            }
        }
        picker.dismiss(animated: true)
    }

    // MARK: - ARPinDelegate

    func didPinStep(at position: SCNVector3, for stepIndex: Int) {
        step.position = position
        pinButton.setTitle("Pinned ✔︎", for: .normal)
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - AIProcedureCell

class AIProcedureCell: UITableViewCell {

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

        containerView.backgroundColor = UIColor(red: 15/255, green: 12/255, blue: 50/255, alpha: 1.0)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .lightGray
        descriptionLabel.numberOfLines = 2
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        stepsLabel.font = UIFont.systemFont(ofSize: 14)
        stepsLabel.textColor = .white
        stepsLabel.translatesAutoresizingMaskIntoConstraints = false

        setupButton(button: editButton, systemName: "pencil", action: #selector(editButtonTapped))
        setupButton(button: deleteButton, systemName: "trash", action: #selector(deleteButtonTapped))
        setupButton(button: playButton, systemName: "play.circle", action: #selector(playButtonTapped))

        let buttonStack = UIStackView(arrangedSubviews: [editButton, deleteButton, playButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.alignment = .center
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let nameDescriptionStack = UIStackView(arrangedSubviews: [nameLabel, descriptionLabel])
        nameDescriptionStack.axis = .vertical
        nameDescriptionStack.spacing = 4
        nameDescriptionStack.translatesAutoresizingMaskIntoConstraints = false

        let topStack = UIStackView(arrangedSubviews: [nameDescriptionStack, buttonStack])
        topStack.axis = .horizontal
        topStack.spacing = 10
        topStack.alignment = .center
        topStack.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView(arrangedSubviews: [topStack, stepsLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(contentStack)
        contentView.addSubview(containerView)

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

    func configure(with procedure: AIProcedure, brandColor: UIColor) {
        nameLabel.text = procedure.name
        descriptionLabel.text = procedure.description
        stepsLabel.text = "\(procedure.steps.count) steps"
        editButton.tintColor = brandColor
        deleteButton.tintColor = brandColor
        playButton.tintColor = brandColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}

// MARK: - AIARPinViewController

class AIARPinViewController: UIViewController, ARSCNViewDelegate {

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
        setupNavBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupARSession()
    }

    private func setupNavBar() {
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
        dismiss(animated: true)
    }

    private func setupARView() {
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        view.addSubview(sceneView)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }

    private func setupARSession() {
        guard let imageItem = imageItem else {
            print("No imageItem provided.")
            return
        }
        DispatchQueue.global().async {
            if let imgData = try? Data(contentsOf: imageItem.imageURL),
               let uiImg = UIImage(data: imgData),
               let cgImg = uiImg.cgImage {
                DispatchQueue.main.async {
                    let refImage = ARReferenceImage(cgImg, orientation: .up, physicalWidth: 0.2)
                    refImage.name = imageItem.name

                    let config = ARWorldTrackingConfiguration()
                    config.detectionImages = [refImage]
                    self.sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                }
            } else {
                print("Failed to load image data from \(imageItem.imageURL).")
            }
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isImageDetected, let anchorNode = imageAnchorNode else {
            let alert = UIAlertController(
                title: "Image Not Detected",
                message: "Please detect the image before pinning the step.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let loc = gesture.location(in: sceneView)
        let hits = sceneView.hitTest(loc, types: [.existingPlaneUsingExtent, .featurePoint])
        if let result = hits.first {
            let worldTransform = result.worldTransform
            let worldPosition = SCNVector3(
                x: worldTransform.columns.3.x,
                y: worldTransform.columns.3.y,
                z: worldTransform.columns.3.z
            )
            let localPosition = anchorNode.convertPosition(worldPosition, from: nil)
            delegate?.didPinStep(at: localPosition, for: stepIndex)

            let alert = UIAlertController(
                title: "Step Pinned",
                message: "Step pinned at the selected location.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { _ in
                self.dismiss(animated: true)
            }))
            present(alert, animated: true)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if anchor is ARImageAnchor {
            DispatchQueue.main.async {
                self.imageAnchorNode = node
                self.isImageDetected = true
                self.showDetectedOverlay()
            }
        }
    }

    private func showDetectedOverlay() {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlay.alpha = 0.0

        let checkImg = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkImg.tintColor = .green
        checkImg.contentMode = .scaleAspectFit
        checkImg.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text = "Image Detected"
        lbl.textColor = .white
        lbl.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        lbl.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(checkImg)
        overlay.addSubview(lbl)

        NSLayoutConstraint.activate([
            checkImg.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            checkImg.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),
            checkImg.widthAnchor.constraint(equalToConstant: 100),
            checkImg.heightAnchor.constraint(equalToConstant: 100),

            lbl.topAnchor.constraint(equalTo: checkImg.bottomAnchor, constant: 20),
            lbl.centerXAnchor.constraint(equalTo: overlay.centerXAnchor)
        ])

        view.addSubview(overlay)
        self.detectionOverlayView = overlay

        UIView.animate(withDuration: 0.5, animations: {
            overlay.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
                overlay.alpha = 0.0
            }, completion: { _ in
                overlay.removeFromSuperview()
            })
        }
    }
}

// MARK: - AIProcedureARViewController

/**
 Displays a container with text steps in AR—no video.
 The container is a "billboard" label with the generated procedure text.
 */
class AIProcedureARViewController: UIViewController, ARSCNViewDelegate {

    var procedure: AIProcedure!
    var imageItem: ImageItem!

    private var sceneView: ARSCNView!
    private var imageAnchorNode: SCNNode?
    private var isImageDetected = false
    private var detectionOverlayView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupNavBar()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupARSession()
    }

    private func setupNavBar() {
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
        dismiss(animated: true)
    }

    private func setupARView() {
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        view.addSubview(sceneView)
    }

    private func setupARSession() {
        guard let item = imageItem else {
            print("No imageItem provided.")
            return
        }

        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: item.imageURL),
               let uiImage = UIImage(data: data),
               let cgImage = uiImage.cgImage {
                DispatchQueue.main.async {
                    let refImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.2)
                    refImage.name = item.name

                    let config = ARWorldTrackingConfiguration()
                    config.detectionImages = [refImage]
                    self.sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                }
            } else {
                print("Failed to load image data from \(item.imageURL).")
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // We show the steps once the image is detected
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imgAnchor = anchor as? ARImageAnchor else { return }
        DispatchQueue.main.async {
            self.imageAnchorNode = node
            self.isImageDetected = true
            self.showDetectedOverlay()
            print("Image detected: \(imgAnchor.referenceImage.name ?? "Unknown")")
            self.displayProcedureSteps()
        }
    }

    /// For each step, create a container in AR with the step text
    private func displayProcedureSteps() {
        guard let anchorNode = imageAnchorNode else { return }

        for (index, step) in procedure.steps.enumerated() {
            if let position = step.position {
                // create an SCNPlane using a rendered container image
                let containerImage = self.createStepsContainerImage(stepIndex: index, text: step.description)
                // Adjust plane size & scale factor to your preference
                let planeWidth: CGFloat = 0.2  // in meters
                // We'll guess the aspect from the container image
                let aspect = containerImage.size.height / containerImage.size.width
                let planeHeight = planeWidth * aspect

                let plane = SCNPlane(width: CGFloat(planeWidth), height: CGFloat(planeHeight))
                plane.firstMaterial?.diffuse.contents = containerImage
                plane.firstMaterial?.isDoubleSided = true

                let stepNode = SCNNode(geometry: plane)
                stepNode.position = position

                // Make it face the camera
                let constraint = SCNBillboardConstraint()
                constraint.freeAxes = .all
                stepNode.constraints = [constraint]

                anchorNode.addChildNode(stepNode)
            }
        }
    }

    /**
     Creates a UIImage that looks like a container with the step text, which we can apply to an SCNPlane.
     */
    private func createStepsContainerImage(stepIndex: Int, text: String) -> UIImage {
        // Container view
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 150))
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.cgColor

        // Step number label (optional)
        let stepNumberLabel = UILabel()
        stepNumberLabel.text = "Step \(stepIndex + 1)"
        stepNumberLabel.textColor = .white
        stepNumberLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        stepNumberLabel.textAlignment = .center
        stepNumberLabel.frame = CGRect(x: 0, y: 10, width: containerView.frame.width, height: 22)

        // Text label
        let descriptionLabel = UILabel()
        descriptionLabel.text = text
        descriptionLabel.textColor = .white
        descriptionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .left
        
        // Estimate size
        let padding: CGFloat = 16
        let maxLabelWidth = containerView.frame.width - (padding * 2)
        let neededSize = descriptionLabel.sizeThatFits(CGSize(width: maxLabelWidth, height: CGFloat.greatestFiniteMagnitude))
        // We'll adjust container height if needed
        let totalHeight = stepNumberLabel.frame.maxY + 10 + neededSize.height + padding
        containerView.frame.size.height = max(totalHeight, 80) // min height fallback

        descriptionLabel.frame = CGRect(
            x: padding,
            y: stepNumberLabel.frame.maxY + 10,
            width: maxLabelWidth,
            height: neededSize.height
        )

        containerView.addSubview(stepNumberLabel)
        containerView.addSubview(descriptionLabel)

        // Optionally add a drop shadow or tail, etc.
        containerView.layoutIfNeeded()

        // Render the containerView to UIImage
        UIGraphicsBeginImageContextWithOptions(containerView.bounds.size, false, UIScreen.main.scale)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }
        containerView.layer.render(in: ctx)
        let renderedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return renderedImage ?? UIImage()
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // Not doing anything special on tap, no video playback
    }

    private func showDetectedOverlay() {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlay.alpha = 0.0

        let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        check.tintColor = .green
        check.contentMode = .scaleAspectFit
        check.translatesAutoresizingMaskIntoConstraints = false

        let msg = UILabel()
        msg.text = "Image Detected"
        msg.textColor = .white
        msg.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        msg.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(check)
        overlay.addSubview(msg)

        NSLayoutConstraint.activate([
            check.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),
            check.widthAnchor.constraint(equalToConstant: 100),
            check.heightAnchor.constraint(equalToConstant: 100),

            msg.topAnchor.constraint(equalTo: check.bottomAnchor, constant: 20),
            msg.centerXAnchor.constraint(equalTo: overlay.centerXAnchor)
        ])

        view.addSubview(overlay)
        detectionOverlayView = overlay

        UIView.animate(withDuration: 0.5, animations: {
            overlay.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
                overlay.alpha = 0.0
            }, completion: { _ in
                overlay.removeFromSuperview()
            })
        }
    }
}

// MARK: - Models

struct AIProcedure {
    let id: String
    var name: String
    var description: String
    var steps: [AIProcedureStep]
    var createdAt: Date

    static func fromFirestore(data: [String: Any], id: String) -> AIProcedure? {
        guard
            let name = data["name"] as? String,
            let desc = data["description"] as? String,
            let createdAtTimestamp = data["createdAt"] as? Timestamp,
            let stepsData = data["steps"] as? [[String: Any]]
        else { return nil }

        var parsedSteps: [AIProcedureStep] = []
        for stepDict in stepsData {
            if let s = AIProcedureStep.fromFirestore(data: stepDict) {
                parsedSteps.append(s)
            }
        }
        return AIProcedure(
            id: id,
            name: name,
            description: desc,
            steps: parsedSteps,
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}

struct AIProcedureStep {
    var description: String
    var position: SCNVector3?
    var mediaURL: URL?
    var mediaLocalURL: URL?

    static func fromFirestore(data: [String: Any]) -> AIProcedureStep? {
        guard let desc = data["description"] as? String else { return nil }

        var pos: SCNVector3? = nil
        if let posDict = data["position"] as? [String: Any],
           let x = posDict["x"] as? Float,
           let y = posDict["y"] as? Float,
           let z = posDict["z"] as? Float {
            pos = SCNVector3(x, y, z)
        }

        var remoteURL: URL? = nil
        if let urlStr = data["mediaURL"] as? String {
            remoteURL = URL(string: urlStr)
        }

        return AIProcedureStep(description: desc, position: pos, mediaURL: remoteURL, mediaLocalURL: nil)
    }
}
