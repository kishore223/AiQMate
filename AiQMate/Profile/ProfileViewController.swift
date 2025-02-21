import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
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
        label.text = "Profile"
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
    
    private let profileImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "person.crop.circle.fill"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 60
        imageView.layer.borderWidth = 4
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    private let cameraIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "camera.circle.fill"))
        imageView.tintColor = .white
        imageView.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 0.8)
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let nameTitleLabel = ProfileFieldTitleLabel(iconName: "person.fill", text: "Name")
    private let emailTitleLabel = ProfileFieldTitleLabel(iconName: "envelope.fill", text: "Email")
    private let phoneTitleLabel = ProfileFieldTitleLabel(iconName: "phone.fill", text: "Phone")
    
    private lazy var nameTextField: UITextField = self.createTextField(fontSize: 20, weight: .regular, placeholder: "Full Name")
    private lazy var emailTextField: UITextField = self.createTextField(fontSize: 18, weight: .regular, placeholder: "Email")
    private lazy var phoneTextField: UITextField = self.createTextField(fontSize: 18, weight: .regular, placeholder: "Phone Number")
    
    private let infoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 0.7)
        view.layer.cornerRadius = 15
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 0.3).cgColor
        return view
    }()
    
    private let editButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "pencil.circle.fill"), for: .normal)
        button.tintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        return button
    }()
    
    private let logoutButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Logout", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        button.layer.cornerRadius = 25
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        return button
    }()
    
    private var isEditMode = false {
        didSet {
            updateEditMode()
        }
    }
    
    // MARK: - Lifecycle Methods
    
    // In the viewDidLoad or setup function of ProfileViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupLayout()
        fetchUserData()
        setupActions()
        
        // Hide the navigation title
        self.navigationItem.title = ""
        self.navigationController?.navigationBar.isHidden = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = headerView.bounds
        logoutButton.layer.cornerRadius = logoutButton.frame.height / 2
    }
    
    // MARK: - Setup Methods
    
    private func setupViews() {
        view.backgroundColor = backgroundColor
        headerView.layer.addSublayer(gradientLayer) // Add gradient
        view.addSubview(headerView)
        
        // Add the title label to the header
        headerView.addSubview(titleLabel)
        headerView.addSubview(profileImageView)
        headerView.addSubview(cameraIconView)
        
        // Rest of the views
        view.addSubview(infoContainerView)
        infoContainerView.addSubview(editButton)
        
        [nameTitleLabel, nameTextField,
         emailTitleLabel, emailTextField,
         phoneTitleLabel, phoneTextField,
         logoutButton].forEach {
            infoContainerView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }


    private func setupLayout() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        cameraIconView.translatesAutoresizingMaskIntoConstraints = false
        infoContainerView.translatesAutoresizingMaskIntoConstraints = false
        editButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false // Add this

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 220),

            // Position titleLabel
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 80), // Adjust as needed
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -20),

            profileImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: headerView.bottomAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 150),
            profileImageView.heightAnchor.constraint(equalToConstant: 150),

            cameraIconView.trailingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: -5),
            cameraIconView.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: -5),
            cameraIconView.widthAnchor.constraint(equalToConstant: 40),
            cameraIconView.heightAnchor.constraint(equalToConstant: 40),

            infoContainerView.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 30),
            infoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            infoContainerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            editButton.topAnchor.constraint(equalTo: infoContainerView.topAnchor, constant: 15),
            editButton.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor, constant: -15),
            editButton.widthAnchor.constraint(equalToConstant: 35),
            editButton.heightAnchor.constraint(equalToConstant: 35),

            nameTitleLabel.topAnchor.constraint(equalTo: infoContainerView.topAnchor, constant: 60),
            nameTitleLabel.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor, constant: 20),
            nameTitleLabel.heightAnchor.constraint(equalToConstant: 25),

            nameTextField.topAnchor.constraint(equalTo: nameTitleLabel.bottomAnchor, constant: 5),
            nameTextField.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 30),

            emailTitleLabel.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 25),
            emailTitleLabel.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor, constant: 20),
            emailTitleLabel.heightAnchor.constraint(equalToConstant: 25),

            emailTextField.topAnchor.constraint(equalTo: emailTitleLabel.bottomAnchor, constant: 5),
            emailTextField.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor, constant: 20),
            emailTextField.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor, constant: -20),
            emailTextField.heightAnchor.constraint(equalToConstant: 30),

            phoneTitleLabel.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 25),
            phoneTitleLabel.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor, constant: 20),
            phoneTitleLabel.heightAnchor.constraint(equalToConstant: 25),

            phoneTextField.topAnchor.constraint(equalTo: phoneTitleLabel.bottomAnchor, constant: 5),
            phoneTextField.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor, constant: 20),
            phoneTextField.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor, constant: -20),
            phoneTextField.heightAnchor.constraint(equalToConstant: 30),

            logoutButton.topAnchor.constraint(equalTo: phoneTextField.bottomAnchor, constant: 40),
            logoutButton.centerXAnchor.constraint(equalTo: infoContainerView.centerXAnchor),
            logoutButton.widthAnchor.constraint(equalToConstant: 180),
            logoutButton.heightAnchor.constraint(equalToConstant: 50),
            logoutButton.bottomAnchor.constraint(lessThanOrEqualTo: infoContainerView.bottomAnchor, constant: -30)
        ])
    }

    
    private func createTextField(fontSize: CGFloat, weight: UIFont.Weight, placeholder: String) -> UITextField {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        textField.textColor = .white
        textField.borderStyle = .none
        textField.isUserInteractionEnabled = false
        textField.placeholder = placeholder
        textField.autocorrectionType = .no
        
        let bottomLine = CALayer()
        bottomLine.frame = CGRect(x: 0.0, y: 30 - 1, width: UIScreen.main.bounds.width - 80, height: 1.0)
        bottomLine.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 0.5).cgColor
        textField.layer.addSublayer(bottomLine)
        
        return textField
    }
    
    private func setupActions() {
        logoutButton.addTarget(self, action: #selector(handleLogout), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(toggleEditMode), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleProfileImageTap))
        profileImageView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Data Fetching and Updating
    
    private func fetchUserData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "User not logged in")
            return
        }
        
        Firestore.firestore().collection("users").document(userId).getDocument { [weak self] (document, error) in
            if let error = error {
                self?.showAlert(title: "Error", message: "Failed to fetch user data: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                self?.showAlert(title: "Error", message: "User data not found")
                return
            }
            
            self?.updateUI(with: data)
        }
        
        let storageRef = Storage.storage().reference().child("profile_images/\(userId)")
        storageRef.getData(maxSize: 5 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                print("Error downloading profile image: \(error.localizedDescription)")
            } else if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.profileImageView.image = image
                }
            }
        }
    }
    
    private func updateUI(with data: [String: Any]) {
        if let firstName = data["firstName"] as? String,
           let lastName = data["lastName"] as? String {
            nameTextField.text = "\(firstName) \(lastName)"
        }
        
        if let email = data["email"] as? String {
            emailTextField.text = email
        }
        
        if let phone = data["phone"] as? String {
            phoneTextField.text = phone
        }
    }
    
    // MARK: - Edit Mode Handling
    
    private func updateEditMode() {
            editButton.tintColor = isEditMode ? .systemGreen : brandColor
            nameTextField.isUserInteractionEnabled = isEditMode
            phoneTextField.isUserInteractionEnabled = isEditMode
            
            let placeholderColor = isEditMode ? UIColor.lightGray : UIColor.clear
            nameTextField.attributedPlaceholder = NSAttributedString(string: "Full Name", attributes: [NSAttributedString.Key.foregroundColor: placeholderColor])
            phoneTextField.attributedPlaceholder = NSAttributedString(string: "Phone Number", attributes: [NSAttributedString.Key.foregroundColor: placeholderColor])
            
            if isEditMode {
                nameTextField.becomeFirstResponder()
            } else {
                view.endEditing(true)
                saveChanges()
            }
        }
        
        @objc private func toggleEditMode() {
            isEditMode.toggle()
            let imageName = isEditMode ? "checkmark.circle.fill" : "pencil.circle.fill"
            editButton.setImage(UIImage(systemName: imageName), for: .normal)
        }
        
        private func saveChanges() {
            guard let userId = Auth.auth().currentUser?.uid else {
                showAlert(title: "Error", message: "User not logged in")
                return
            }
            
            let nameComponents = nameTextField.text?.split(separator: " ").map(String.init) ?? []
            let firstName = nameComponents.first ?? ""
            let lastName = nameComponents.dropFirst().joined(separator: " ")
            
            let userData: [String: Any] = [
                "firstName": firstName,
                "lastName": lastName,
                "phone": phoneTextField.text ?? ""
            ]
            
            Firestore.firestore().collection("users").document(userId).updateData(userData) { [weak self] error in
                if let error = error {
                    self?.showAlert(title: "Error", message: "Failed to update profile: \(error.localizedDescription)")
                } else {
                    self?.showAlert(title: "Success", message: "Profile updated successfully")
                }
            }
        }
        
        // MARK: - Profile Image Handling
        
        @objc private func handleProfileImageTap() {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.allowsEditing = true
            present(imagePicker, animated: true)
        }
        
        private func uploadProfileImage(_ image: UIImage) {
            guard let userId = Auth.auth().currentUser?.uid,
                  let imageData = image.jpegData(compressionQuality: 0.75) else {
                return
            }
            
            let storageRef = Storage.storage().reference().child("profile_images/\(userId)")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            storageRef.putData(imageData, metadata: metadata) { [weak self] _, error in
                if let error = error {
                    self?.showAlert(title: "Error", message: "Failed to upload image: \(error.localizedDescription)")
                } else {
                    self?.showAlert(title: "Success", message: "Profile image updated successfully")
                }
            }
        }
        
        // UIImagePickerController Delegate Methods
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            
            guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else {
                return
            }
            
            profileImageView.image = image
            uploadProfileImage(image)
        }
        
        // MARK: - Logout Handling
        
        @objc private func handleLogout() {
            let alert = UIAlertController(title: "Logout", message: "Are you sure you want to logout?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
                do {
                    try Auth.auth().signOut()
                    self?.navigateToLogin()
                } catch {
                    self?.showAlert(title: "Error", message: "Failed to logout: \(error.localizedDescription)")
                }
            })
            present(alert, animated: true)
        }
        
        private func navigateToLogin() {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let loginVC = LoginViewController()
                let navController = UINavigationController(rootViewController: loginVC)
                window.rootViewController = navController
                window.makeKeyAndVisible()
            }
        }
        
        // MARK: - Helper Methods
        
        @objc private func dismissKeyboard() {
            view.endEditing(true)
        }
        
        private func showAlert(title: String, message: String) {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default))
            present(alertController, animated: true)
        }
    }

    // MARK: - ProfileFieldTitleLabel

    class ProfileFieldTitleLabel: UIView {
        private let iconImageView = UIImageView()
        private let textLabel = UILabel()
        
        init(iconName: String, text: String) {
            super.init(frame: .zero)
            setupViews(iconName: iconName, text: text)
            setupLayout()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupViews(iconName: String, text: String) {
            iconImageView.image = UIImage(systemName: iconName)
            iconImageView.tintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            
            textLabel.text = text
            textLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            textLabel.textColor = .white
            textLabel.translatesAutoresizingMaskIntoConstraints = false
            
            addSubview(iconImageView)
            addSubview(textLabel)
        }
        
        private func setupLayout() {
            NSLayoutConstraint.activate([
                iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconImageView.widthAnchor.constraint(equalToConstant: 20),
                iconImageView.heightAnchor.constraint(equalToConstant: 20),
                
                textLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
                textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                textLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
        }
    }
