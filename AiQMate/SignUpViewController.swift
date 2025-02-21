import UIKit
import FirebaseAuth
import FirebaseFirestore

class SignUpViewController: UIViewController {
    
    // MARK: - Properties
    
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    
    // MARK: - UI Elements
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "AiQMateLogo")
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Create Account"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private lazy var firstNameTextField: UITextField = self.createTextField(placeholder: "First Name", icon: "person.fill")
    private lazy var lastNameTextField: UITextField = self.createTextField(placeholder: "Last Name", icon: "person.fill")
    private lazy var emailTextField: UITextField = self.createTextField(placeholder: "Email", icon: "envelope.fill")
    private lazy var phoneTextField: UITextField = self.createTextField(placeholder: "Phone Number", icon: "phone.fill")
    private lazy var passwordTextField: UITextField = self.createTextField(placeholder: "Password", icon: "lock.fill", isSecure: true)
    private lazy var confirmPasswordTextField: UITextField = self.createTextField(placeholder: "Confirm Password", icon: "lock.fill", isSecure: true)
    
    private let signUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("SIGN UP", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(handleSignUp), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupLayout()
        setupGestures()
    }
    
    // MARK: - Setup Methods
    
    private func setupViews() {
        view.backgroundColor = backgroundColor
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        [logoImageView, titleLabel, firstNameTextField, lastNameTextField, emailTextField, phoneTextField, passwordTextField, confirmPasswordTextField, signUpButton].forEach {
            contentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            logoImageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 250),
            logoImageView.heightAnchor.constraint(equalToConstant: 250),
            
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            firstNameTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            firstNameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            firstNameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            firstNameTextField.heightAnchor.constraint(equalToConstant: 50),
            
            lastNameTextField.topAnchor.constraint(equalTo: firstNameTextField.bottomAnchor, constant: 20),
            lastNameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            lastNameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            lastNameTextField.heightAnchor.constraint(equalToConstant: 50),
            
            emailTextField.topAnchor.constraint(equalTo: lastNameTextField.bottomAnchor, constant: 20),
            emailTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emailTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            phoneTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 20),
            phoneTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            phoneTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            phoneTextField.heightAnchor.constraint(equalToConstant: 50),
            
            passwordTextField.topAnchor.constraint(equalTo: phoneTextField.bottomAnchor, constant: 20),
            passwordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            passwordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            confirmPasswordTextField.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 20),
            confirmPasswordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            confirmPasswordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            confirmPasswordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            signUpButton.topAnchor.constraint(equalTo: confirmPasswordTextField.bottomAnchor, constant: 30),
            signUpButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            signUpButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            signUpButton.heightAnchor.constraint(equalToConstant: 50),
            signUpButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func createTextField(placeholder: String, icon: String, isSecure: Bool = false) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.textColor = .white
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        textField.borderStyle = .none
        textField.isSecureTextEntry = isSecure
        textField.layer.cornerRadius = 25
        textField.clipsToBounds = true
        
        let iconView = UIImageView(frame: CGRect(x: 10, y: 0, width: 20, height: 20))
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        
        let iconContainerView: UIView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        iconContainerView.addSubview(iconView)
        
        textField.leftView = iconContainerView
        textField.leftViewMode = .always
        
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [NSAttributedString.Key.foregroundColor: UIColor(white: 1.0, alpha: 0.7)]
        )
        
        return textField
    }
    
    // MARK: - Action Methods
    
    @objc private func handleSignUp() {
        guard let firstName = firstNameTextField.text, !firstName.isEmpty,
              let lastName = lastNameTextField.text, !lastName.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let phone = phoneTextField.text, !phone.isEmpty,
              let password = passwordTextField.text, !password.isEmpty,
              let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all fields")
            return
        }
        
        guard password == confirmPassword else {
            showAlert(title: "Error", message: "Passwords do not match")
            return
        }
        
        // Show loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = brandColor
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            // Hide loading indicator
            loadingIndicator.stopAnimating()
            loadingIndicator.removeFromSuperview()
            
            if let error = error {
                self?.showAlert(title: "Sign Up Failed", message: error.localizedDescription)
                return
            }
            
            guard let userId = authResult?.user.uid else {
                self?.showAlert(title: "Error", message: "Failed to get user ID")
                return
            }
            
            let userData: [String: Any] = [
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "phone": phone
            ]
            
            Firestore.firestore().collection("users").document(userId).setData(userData) { error in
                if let error = error {
                    self?.showAlert(title: "Error", message: "Failed to save user data: \(error.localizedDescription)")
                } else {
                    self?.showAlert(title: "Success", message: "Account created successfully") { _ in
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            }
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func showAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: completion))
        present(alertController, animated: true, completion: nil)
    }
}
