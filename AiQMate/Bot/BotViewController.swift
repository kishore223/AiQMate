import UIKit
import FirebaseFirestore
import Speech
import AVFoundation

class BotViewController: UIViewController, SFSpeechRecognizerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Properties
    
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private let gradientLayer: CAGradientLayer = {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 0.6).cgColor,
            UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 0.3).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        return gradientLayer
    }()
    private let titleLabel: GradientLabel = {
        let label = GradientLabel()
        label.text = "AiQ Bot"
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
    private let chatTableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        return tableView
    }()
    
    private let inputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 0.7)
        view.layer.cornerRadius = 25
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 0.3).cgColor
        view.layer.masksToBounds = true
        return view
    }()
    
    private let inputTextField: UITextField = {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.textColor = .white
        textField.attributedPlaceholder = NSAttributedString(string: "Type a message...", attributes: [NSAttributedString.Key.foregroundColor: UIColor.systemGray])
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.autocorrectionType = .no
        return textField
    }()
    
    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        let sendIcon = UIImage(systemName: "arrow.up.circle.fill") // Change to a more appropriate send icon
        button.setImage(sendIcon, for: .normal)
        button.tintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private let micButton: UIButton = {
        let button = UIButton(type: .system)
        let micIcon = UIImage(systemName: "mic.fill")
        button.setImage(micIcon, for: .normal)
        button.tintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private let modeSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.onTintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        return switchControl
    }()
    
    private let modeSwitchLabel: UILabel = {
        let label = UILabel()
        label.text = "Ticketing Mode"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    // MARK: - Constraint Properties
    
    private var inputContainerViewBottomConstraint: NSLayoutConstraint?
    
    // MARK: - State
    
    private var isTicketingMode = false
    private var messages: [(text: String, isBot: Bool)] = []
    private var isLoading = false
    private var ticketInfo: [String: Any]?
    private var lastUserQuestion: String? // Store the last user question
    
    // MARK: - Speech Recognition
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Database
    private let db = Firestore.firestore()
    
    // MARK: - OpenAI API Key
    let openAIAPIKey = Config.openAIAPIKey // Ensure this is securely stored
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide the default tab bar title
        self.navigationItem.title = "" // Clear title to avoid conflict
        self.navigationController?.navigationBar.isHidden = true // Hide the navigation bar if needed

        setupViews()
        setupLayout()
        setupActions()
        setupSpeechRecognition()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)

        chatTableView.dataSource = self
        chatTableView.delegate = self
        chatTableView.register(UserMessageCell.self, forCellReuseIdentifier: "UserMessageCell")
        chatTableView.register(BotMessageCell.self, forCellReuseIdentifier: "BotMessageCell")
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = headerView.bounds
    }
    
    // MARK: - Setup Methods
    
    private func setupViews() {
        view.backgroundColor = backgroundColor
        headerView.layer.addSublayer(gradientLayer)
        view.addSubview(headerView)
        headerView.addSubview(titleLabel) // Add title label
        view.addSubview(chatTableView)
        view.addSubview(inputContainerView)
        inputContainerView.addSubview(inputTextField)
        inputContainerView.addSubview(sendButton)
        inputContainerView.addSubview(micButton)
        view.addSubview(modeSwitch)
        view.addSubview(modeSwitchLabel)
    }
    
    private func setupLayout() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        chatTableView.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.translatesAutoresizingMaskIntoConstraints = false
        modeSwitch.translatesAutoresizingMaskIntoConstraints = false
        modeSwitchLabel.translatesAutoresizingMaskIntoConstraints = false
        
        inputContainerViewBottomConstraint = inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        
        NSLayoutConstraint.activate([
                headerView.topAnchor.constraint(equalTo: view.topAnchor),
                headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                headerView.heightAnchor.constraint(equalToConstant: 90), // Adjusted height similar to SummarizeViewController

                titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
                titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 80), // Adjust positioning if needed
                titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: headerView.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -20),

                // Existing layout code...
                modeSwitch.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 40),
                modeSwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                modeSwitchLabel.centerYAnchor.constraint(equalTo: modeSwitch.centerYAnchor),
                modeSwitchLabel.trailingAnchor.constraint(equalTo: modeSwitch.leadingAnchor, constant: -10),

                chatTableView.topAnchor.constraint(equalTo: modeSwitch.bottomAnchor, constant: 10),
                chatTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                chatTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                chatTableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),

                inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
                inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
                inputContainerViewBottomConstraint!,
                inputContainerView.heightAnchor.constraint(equalToConstant: 50),

                micButton.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 10),
                micButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
                micButton.widthAnchor.constraint(equalToConstant: 30),
                micButton.heightAnchor.constraint(equalToConstant: 30),

                sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -10),
                sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
                sendButton.widthAnchor.constraint(equalToConstant: 30),
                sendButton.heightAnchor.constraint(equalToConstant: 30),

                inputTextField.leadingAnchor.constraint(equalTo: micButton.trailingAnchor, constant: 10),
                inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -10),
                inputTextField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
                inputTextField.heightAnchor.constraint(equalToConstant: 40)
            ])
    }
    
    private func setupActions() {
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        modeSwitch.addTarget(self, action: #selector(toggleMode), for: .valueChanged)
        micButton.addTarget(self, action: #selector(micButtonTapped), for: .touchUpInside)
    }
    
    private func setupSpeechRecognition() {
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.micButton.isEnabled = true
                default:
                    self.micButton.isEnabled = false
                }
            }
        }
    }
    
    // MARK: - Action Methods
    
    @objc private func toggleMode() {
        isTicketingMode = modeSwitch.isOn
        let modeMessage = isTicketingMode ? "Switched to Ticketing mode. Please provide your name, email, subject, priority, category, and description to create a ticket." : "Switched to General Assistance mode."
        addMessage(modeMessage, isBot: true)
    }
    
    @objc private func sendMessage() {
        guard let userMessage = inputTextField.text, !userMessage.isEmpty else { return }
        
        if audioEngine.isRunning {
            stopRecording()
        }
        
        dismissKeyboard()
        addMessage(userMessage, isBot: false)
        inputTextField.text = ""
        
        lastUserQuestion = userMessage // Store the user's question
        
        if isTicketingMode {
            extractTicketInfoWithOpenAI(from: userMessage)
        } else {
            processGeneralAssistance(message: userMessage)
        }
    }
    
    @objc private func micButtonTapped() {
        if audioEngine.isRunning {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.inputTextField.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopRecording()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("AudioEngine failed to start: \(error)")
        }
        
        micButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        micButton.tintColor = .systemRed
    }
    
    private func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.tintColor = brandColor
    }
    
    private func addMessage(_ text: String, isBot: Bool) {
        messages.append((text: text, isBot: isBot))
        chatTableView.reloadData()
        scrollToBottom()
    }
    
    // MARK: - General Assistance Mode Processing
    
    private func processGeneralAssistance(message: String) {
        isLoading = true
        updateSendButtonState()
        
        // Use OpenAI to extract search parameters from the user message
        extractSearchParametersWithOpenAI(from: message) { [weak self] extractedParams, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                self.updateSendButtonState()
                
                if let error = error {
                    print("Error extracting search parameters: \(error)")
                    self.addMessage("Sorry, I couldn't process your request. Please try again.", isBot: true)
                    return
                }
                
                guard let params = extractedParams else {
                    self.addMessage("I couldn't understand your request. Please provide more details related to the ticket system.", isBot: true)
                    return
                }
                
                self.queryTickets(with: params)
            }
        }
    }
    
    /// Extracts search parameters from the user's message using OpenAI.
    private func extractSearchParametersWithOpenAI(from message: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        // Ensure the API key is set
        guard !openAIAPIKey.isEmpty else {
            completion(nil, NSError(domain: "OpenAI API Key Missing", code: 401, userInfo: nil))
            return
        }
        
        // Define the prompt to extract search parameters
        let prompt = """
        Extract the following information from the user's message related to the ticket system:
        - Ticket ID
        - Status (e.g., Open, Closed, In Progress)
        - Priority (e.g., Low, Medium, High)
        - Category (e.g., Technical, Billing, General)
        - Customer Email
        
        Provide the extracted information in JSON format with the keys: ticket_id, status, priority, category, customer_email.
        If any field is missing or cannot be determined, set its value to an empty string.
        """
        
        // Prepare the JSON payload for OpenAI API
        let json: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are an assistant that extracts ticket-related search parameters from user messages."],
                ["role": "user", "content": "\(prompt)\n\nUser Message: \(message)"]
            ],
            "max_tokens": 150,
            "temperature": 0
        ]
        
        // Serialize the JSON payload
        guard let httpBody = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            completion(nil, NSError(domain: "Serialization Error", code: 500, userInfo: nil))
            return
        }
        
        // Create the URL request
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(nil, NSError(domain: "Invalid URL", code: 400, userInfo: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        // Perform the API request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "No Data Received", code: 204, userInfo: nil))
                return
            }
            
            do {
                // Parse the OpenAI response
                if let responseObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = responseObject["choices"] as? [[String: Any]],
                   let messageContent = choices.first?["message"] as? [String: Any],
                   let content = messageContent["content"] as? String {
                    
                    // Attempt to parse JSON from OpenAI's response
                    if let extractedInfoData = content.data(using: .utf8),
                       let extractedInfo = try? JSONSerialization.jsonObject(with: extractedInfoData, options: []) as? [String: Any] {
                        
                        completion(extractedInfo, nil)
                    } else {
                        completion(nil, NSError(domain: "JSON Parsing Error", code: 422, userInfo: nil))
                    }
                } else {
                    completion(nil, NSError(domain: "Invalid Response Structure", code: 400, userInfo: nil))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    /// Queries Firestore based on the extracted search parameters.
    private func queryTickets(with params: [String: Any]) {
        var query: Query = db.collection("tickets")
        var filtersApplied = 0
        
        if let ticketID = params["ticket_id"] as? String, !ticketID.isEmpty {
            query = query.whereField("id", isEqualTo: ticketID)
            filtersApplied += 1
        }
        
        if let status = params["status"] as? String, !status.isEmpty {
            query = query.whereField("status", isEqualTo: status)
            filtersApplied += 1
        }
        
        if let priority = params["priority"] as? String, !priority.isEmpty {
            query = query.whereField("priority", isEqualTo: priority)
            filtersApplied += 1
        }
        
        if let category = params["category"] as? String, !category.isEmpty {
            query = query.whereField("category", isEqualTo: category)
            filtersApplied += 1
        }
        
        if let customerEmail = params["customer_email"] as? String, !customerEmail.isEmpty {
            query = query.whereField("customerInfo.email", isEqualTo: customerEmail)
            filtersApplied += 1
        }
        
        // If no filters are applied, fetch all tickets (optional: limit to recent tickets)
        if filtersApplied == 0 {
            query = query.limit(to: 100) // Adjust the limit as needed
        }
        
        query.getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Firestore Query Error: \(error.localizedDescription)")
                self?.addMessage("Sorry, I couldn't retrieve the information from the database. Please try again later.", isBot: true)
                return
            }
            
            guard let snapshot = snapshot else {
                print("Firestore Query: No snapshot returned.")
                self?.addMessage("No tickets found matching your query.", isBot: true)
                return
            }
            
            if snapshot.isEmpty {
                self?.addMessage("No tickets found matching your query.", isBot: true)
                return
            }
            
            var results: [[String: Any]] = []
            for document in snapshot.documents {
                var data = document.data()
                data["id"] = document.documentID
                results.append(data)
            }
            
            // Pass the results and the last user question to handleDatabaseQueryResponse
            self?.handleDatabaseQueryResponse(results, userQuestion: self?.lastUserQuestion)
        }
    }
    
    private func handleDatabaseQueryResponse(_ tickets: [[String: Any]], userQuestion: String?) {
        guard let question = userQuestion else {
            addMessage("I couldn't determine your question. Please try again.", isBot: true)
            return
        }
        
        // Send the tickets' data and the user's question to OpenAI to generate a direct response
        frameResponseWithOpenAI(tickets: tickets, question: question) { [weak self] formattedResponse, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error framing response with OpenAI: \(error)")
                    self?.addMessage("Sorry, I couldn't process your request. Please try again.", isBot: true)
                    return
                }
                
                guard let response = formattedResponse else {
                    self?.addMessage("No response generated.", isBot: true)
                    return
                }
                
                self?.addMessage(response, isBot: true)
            }
        }
    }
    
    /// Frames the response based on tickets and the user's question using OpenAI.
    private func frameResponseWithOpenAI(tickets: [[String: Any]], question: String, completion: @escaping (String?, Error?) -> Void) {
        // Prepare the tickets' data in a readable format for OpenAI
        let ticketsDescription = tickets.map { ticket -> String in
            let id = ticket["id"] as? String ?? "N/A"
            let subject = ticket["subject"] as? String ?? "No Subject"
            let status = ticket["status"] as? String ?? "No Status"
            let priority = ticket["priority"] as? String ?? "No Priority"
            let category = ticket["category"] as? String ?? "No Category"
            let description = ticket["description"] as? String ?? "No Description"
            
            let customerInfo = ticket["customerInfo"] as? [String: Any]
            let customerName = customerInfo?["name"] as? String ?? "No Name"
            let customerEmail = customerInfo?["email"] as? String ?? "No Email"
            
            return """
            Ticket ID: \(id)
            Subject: \(subject)
            Status: \(status)
            Priority: \(priority)
            Category: \(category)
            Description: \(description)
            Customer Name: \(customerName)
            Customer Email: \(customerEmail)
            """
        }.joined(separator: "\n\n")
        
        // Define the prompt to instruct OpenAI to answer the specific question based on the ticket data
        let prompt = """
        You are a helpful assistant. Answer the user's question based on the following ticket details:

        Ticket Details:
        \(ticketsDescription)

        User Question: \(question)

        Provide a clear and direct answer to the user's question. If necessary, refer to the relevant ticket(s) by their Ticket ID.
        """
        
        // Prepare the JSON payload for OpenAI API
        let json: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.3
        ]
        
        // Serialize the JSON payload
        guard let httpBody = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            completion(nil, NSError(domain: "Serialization Error", code: 500, userInfo: nil))
            return
        }
        
        // Create the URL request
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(nil, NSError(domain: "Invalid URL", code: 400, userInfo: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        // Perform the API request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "No Data Received", code: 204, userInfo: nil))
                return
            }
            
            do {
                // Parse the OpenAI response
                if let responseObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = responseObject["choices"] as? [[String: Any]],
                   let messageContent = choices.first?["message"] as? [String: Any],
                   let content = messageContent["content"] as? String {
                    completion(content.trimmingCharacters(in: .whitespacesAndNewlines), nil)
                } else {
                    completion(nil, NSError(domain: "Invalid Response Structure", code: 400, userInfo: nil))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    // MARK: - Ticketing Mode Processing
    
    private func extractTicketInfoWithOpenAI(from message: String) {
        isLoading = true
        updateSendButtonState()
        
        // Ensure you have your OpenAI API key set
        guard !openAIAPIKey.isEmpty else {
            addMessage("API key is missing. Please configure the OpenAI API key.", isBot: true)
            isLoading = false
            updateSendButtonState()
            return
        }
        
        // Create a request to OpenAI's API for information extraction
        let apiURL = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: apiURL) else {
            addMessage("Invalid API URL.", isBot: true)
            isLoading = false
            updateSendButtonState()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Define the prompt for extracting ticket information
        let prompt = """
        Extract the following information from the user's message:
        - Name
        - Email
        - Subject
        - Priority (Low, Medium, High)
        - Category (e.g., Technical, Billing, General)
        - Description
        
        Provide the extracted information in JSON format with the keys: name, email, subject, priority, category, description.
        If any field is missing or cannot be determined, set its value to an empty string.
        """
        
        let json: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are an assistant that extracts ticket information from user messages."],
                ["role": "user", "content": "\(prompt)\n\nUser Message: \(message)"]
            ],
            "max_tokens": 300,
            "temperature": 0
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        } catch {
            addMessage("Failed to serialize request.", isBot: true)
            isLoading = false
            updateSendButtonState()
            return
        }
        
        // Perform the API request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                self.updateSendButtonState()
                
                if let error = error {
                    print("Error fetching response: \(error)")
                    self.addMessage("Sorry, I couldn't process your request. Please try again.", isBot: true)
                    return
                }
                
                guard let data = data else {
                    self.addMessage("No data received from the server.", isBot: true)
                    return
                }
                
                do {
                    if let responseObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = responseObject["choices"] as? [[String: Any]],
                       let messageContent = choices.first?["message"] as? [String: Any],
                       let content = messageContent["content"] as? String {
                        
                        // Attempt to parse JSON from OpenAI's response
                        if let extractedInfoData = content.data(using: .utf8),
                           let extractedInfo = try? JSONSerialization.jsonObject(with: extractedInfoData) as? [String: String] {
                            
                            self.ticketInfo = [
                                "customerInfo": [
                                    "name": extractedInfo["name"] ?? "",
                                    "email": extractedInfo["email"] ?? ""
                                ],
                                "subject": extractedInfo["subject"] ?? "",
                                "priority": extractedInfo["priority"] ?? "Low",
                                "description": extractedInfo["description"] ?? "",
                                "category": extractedInfo["category"] ?? "General"
                            ]
                            
                            self.showTicketConfirmation()
                        } else {
                            self.addMessage("Failed to extract ticket information. Please provide the details manually.", isBot: true)
                        }
                    } else {
                        self.addMessage("Sorry, I couldn't understand the response from the server.", isBot: true)
                    }
                } catch {
                    print("Error parsing response: \(error)")
                    self.addMessage("Error parsing response from the server.", isBot: true)
                }
            }
        }.resume()
    }
    
    private func showTicketConfirmation() {
        guard let ticketInfo = ticketInfo else { return }

        let alert = UIAlertController(title: "Confirm Ticket Details", message: nil, preferredStyle: .alert)

        // Customize the alert background with better layering
        if let firstSubview = alert.view.subviews.first,
           let alertContentView = firstSubview.subviews.first?.subviews.first {
            alertContentView.backgroundColor = backgroundColor
            alertContentView.layer.cornerRadius = 15
            alertContentView.layer.masksToBounds = true
            alertContentView.layer.shadowColor = UIColor.black.cgColor
            alertContentView.layer.shadowOffset = CGSize(width: 0, height: 2)
            alertContentView.layer.shadowOpacity = 0.4
            alertContentView.layer.shadowRadius = 5
        }
        alert.view.tintColor = brandColor

        let fields = [
            ("Name", (ticketInfo["customerInfo"] as? [String: String])?["name"] ?? ""),
            ("Email", (ticketInfo["customerInfo"] as? [String: String])?["email"] ?? ""),
            ("Subject", ticketInfo["subject"] as? String ?? ""),
            ("Priority", ticketInfo["priority"] as? String ?? "Low"),
            ("Category", ticketInfo["category"] as? String ?? "General"),
            ("Description", ticketInfo["description"] as? String ?? "")
        ]

        // Create an array to hold the text fields
        var textFields = [UITextField]()

        // Container stack view for proper alignment
        let containerStackView = UIStackView()
        containerStackView.axis = .vertical
        containerStackView.spacing = 10
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(containerStackView)

        // Add constraints for the stack view to align with the alert view
        NSLayoutConstraint.activate([
            containerStackView.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
            containerStackView.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20),
            containerStackView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 60),
            containerStackView.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -60)
        ])

        // Add the fields with labels outside the text fields using horizontal stack views
        for (title, text) in fields {
            let horizontalStackView = UIStackView()
            horizontalStackView.axis = .horizontal
            horizontalStackView.spacing = 10
            horizontalStackView.alignment = .fill

            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.textColor = .white
            titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            let textField = UITextField()
            textField.text = text
            textField.textColor = .white
            textField.backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 0.8)
            textField.layer.cornerRadius = 10
            textField.layer.masksToBounds = true
            textField.layer.borderWidth = 1
            textField.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            textField.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            textField.setLeftPaddingPoints(10)
            textField.heightAnchor.constraint(equalToConstant: 30).isActive = true

            // Set a max width constraint for the text field to avoid overflow
            textField.widthAnchor.constraint(lessThanOrEqualToConstant: 150).isActive = true

            // Add the label and text field to the horizontal stack view
            horizontalStackView.addArrangedSubview(titleLabel)
            horizontalStackView.addArrangedSubview(textField)

            // Add the horizontal stack view to the container stack view
            containerStackView.addArrangedSubview(horizontalStackView)

            // Keep a reference to the text field
            textFields.append(textField)
        }

        // Add actions with subtle style improvements
        alert.addAction(UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
            guard let self = self else { return }

            let updatedTicketInfo: [String: Any] = [
                "customerInfo": [
                    "name": textFields[0].text ?? "",
                    "email": textFields[1].text ?? ""
                ],
                "subject": textFields[2].text ?? "",
                "priority": textFields[3].text ?? "Low",
                "category": textFields[4].text ?? "General",
                "description": textFields[5].text ?? ""
            ]

            self.createTicket(with: updatedTicketInfo)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }



    private func createTicket(with ticketInfo: [String: Any]) {
        isLoading = true
        updateSendButtonState()
        
        var ticket = ticketInfo
        ticket["id"] = "TICKET-\(Int.random(in: 1000...9999))"
        ticket["status"] = "Open"
        ticket["createdAt"] = FieldValue.serverTimestamp()
        ticket["updatedAt"] = FieldValue.serverTimestamp()
        
        db.collection("tickets").addDocument(data: ticket) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.updateSendButtonState()
                
                if let error = error {
                    print("Error adding document: \(error)")
                    self.addMessage("Sorry, I couldn't create the ticket. Please try again.", isBot: true)
                } else {
                    let rawTicketID = ticket["id"] as? String ?? "N/A"
                    // Directly add a simple confirmation message without using OpenAI
                    self.addMessage("Ticket created successfully. Ticket ID: \(rawTicketID)", isBot: true)
                }
            }
        }
    }
    
    /// Frames the confirmation message using OpenAI for better readability.
    private func frameConfirmationMessage(ticketID: String, completion: @escaping (String?, Error?) -> Void) {
        // Define the prompt
        let prompt = """
        Write a friendly and professional confirmation message for a newly created support ticket.
        
        Ticket ID: \(ticketID)
        
        The ticket has been successfully created and is currently open.
        """
        
        // Prepare the JSON payload for OpenAI API
        let json: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a friendly and professional assistant."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 100,
            "temperature": 0.5
        ]
        
        // Serialize the JSON payload
        guard let httpBody = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            completion(nil, NSError(domain: "Serialization Error", code: 500, userInfo: nil))
            return
        }
        
        // Create the URL request
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(nil, NSError(domain: "Invalid URL", code: 400, userInfo: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        // Perform the API request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "No Data Received", code: 204, userInfo: nil))
                return
            }
            
            do {
                // Parse the OpenAI response
                if let responseObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = responseObject["choices"] as? [[String: Any]],
                   let messageContent = choices.first?["message"] as? [String: Any],
                   let content = messageContent["content"] as? String {
                    completion(content.trimmingCharacters(in: .whitespacesAndNewlines), nil)
                } else {
                    completion(nil, NSError(domain: "Invalid Response Structure", code: 400, userInfo: nil))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    private func updateSendButtonState() {
        sendButton.isEnabled = !isLoading
        sendButton.alpha = isLoading ? 0.5 : 1.0
    }
    
    // MARK: - Helper Methods
    
    private func scrollToBottom() {
        DispatchQueue.main.async {
            if self.messages.count > 0 {
                let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
                self.chatTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    // MARK: - Keyboard Handling
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        let keyboardFrame = keyboardFrameValue.cgRectValue
        let keyboardHeight = keyboardFrame.height
        
        // Adjust the bottom constraint
        inputContainerViewBottomConstraint?.constant = -keyboardHeight + 70
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
        
        // Optionally, scroll the table view to the bottom
        scrollToBottom()
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        // Reset the bottom constraint
        inputContainerViewBottomConstraint?.constant = -10
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension BotViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       return messages.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
       return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let message = messages[indexPath.row]
        if message.isBot {
            let cell = tableView.dequeueReusableCell(withIdentifier: "BotMessageCell", for: indexPath) as! BotMessageCell
            cell.configure(with: message.text)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserMessageCell", for: indexPath) as! UserMessageCell
            cell.configure(with: message.text)
            return cell
        }
    }
}

// MARK: - Custom UITableViewCell Classes

class UserMessageCell: UITableViewCell {
    private let messageLabel = UILabel()
    private let bubbleView = UIView()
    private let profileImageView = UIImageView(image: UIImage(systemName: "person.fill"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
       setupViews()
       setupLayout()
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear

        bubbleView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        bubbleView.layer.cornerRadius = 15
        bubbleView.layer.masksToBounds = true

        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 16)

        profileImageView.tintColor = .systemBlue
        profileImageView.contentMode = .scaleAspectFit

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        contentView.addSubview(profileImageView)
    }

    private func setupLayout() {
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            profileImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            profileImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 24),
            profileImageView.heightAnchor.constraint(equalToConstant: 24),

            bubbleView.trailingAnchor.constraint(equalTo: profileImageView.leadingAnchor, constant: -10),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10)
        ])
    }

    func configure(with text: String) {
        messageLabel.text = text
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class BotMessageCell: UITableViewCell {
    private let messageLabel = UILabel()
    private let bubbleView = UIView()
    private let profileImageView = UIImageView(image: UIImage(systemName: "brain.head.profile"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
       setupViews()
       setupLayout()
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear

        bubbleView.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.8)
        bubbleView.layer.cornerRadius = 15
        bubbleView.layer.masksToBounds = true

        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 16)

        profileImageView.tintColor = .systemTeal
        profileImageView.contentMode = .scaleAspectFit

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        contentView.addSubview(profileImageView)
    }

    private func setupLayout() {
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            profileImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 24),
            profileImageView.heightAnchor.constraint(equalToConstant: 24),

            bubbleView.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 10),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10)
        ])
    }

    func configure(with text: String) {
        messageLabel.text = text
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
