import UIKit
import FirebaseAuth

class LoginViewController: UIViewController {
    
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
    
    private let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome back!"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private lazy var emailTextField: UITextField = self.createTextField(placeholder: "Email", icon: "envelope.fill")
    private lazy var passwordTextField: UITextField = self.createTextField(placeholder: "Password", icon: "lock.fill", isSecure: true)
    
    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("LOG IN", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.backgroundColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(handleLogin), for: .touchUpInside)
        return button
    }()
    
    private let forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Forgot Password?", for: .normal)
        button.setTitleColor(UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        return button
    }()
    
    private let signUpStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 5
        return stackView
    }()
    
    private let signUpLabel: UILabel = {
        let label = UILabel()
        label.text = "Don't have an account?"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor(white: 1.0, alpha: 0.7)
        return label
    }()
    
    private let signUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Sign Up", for: .normal)
        button.setTitleColor(UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
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
        
        [logoImageView, welcomeLabel, emailTextField, passwordTextField, loginButton, forgotPasswordButton, signUpStackView].forEach {
            contentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        signUpStackView.addArrangedSubview(signUpLabel)
        signUpStackView.addArrangedSubview(signUpButton)
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
            
            welcomeLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor),
            welcomeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            welcomeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            emailTextField.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 30),
            emailTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emailTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 20),
            passwordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            passwordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 30),
            loginButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            loginButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            
            forgotPasswordButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 20),
            forgotPasswordButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            signUpStackView.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 20),
            signUpStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            signUpStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        forgotPasswordButton.addTarget(self, action: #selector(handleForgotPassword), for: .touchUpInside)
        signUpButton.addTarget(self, action: #selector(handleSignUp), for: .touchUpInside)
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
    
    @objc private func handleLogin() {
        guard let email = emailTextField.text, let password = passwordTextField.text else { return }
        
        // Show loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = brandColor
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            // Hide loading indicator
            loadingIndicator.stopAnimating()
            loadingIndicator.removeFromSuperview()
            
            if let error = error {
                self?.showAlert(title: "Login Failed", message: error.localizedDescription)
                return
            }
            self?.navigateToHome()
        }
    }
    
    @objc private func handleForgotPassword() {
        // Implement forgot password functionality
        print("Forgot password tapped")
    }
    
    @objc private func handleSignUp() {
        let signUpVC = SignUpViewController()
        self.navigationController?.pushViewController(signUpVC, animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func navigateToHome() {
        let tabBarController = TabBarController()
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UINavigationController(rootViewController: tabBarController)
            window.makeKeyAndVisible()
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
