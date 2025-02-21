import UIKit

class ImageDetailsViewController: UIViewController {
    
    // MARK: - Properties
    
    private let saveHandler: (String, String, String, String, String) -> Void
    private let image: UIImage
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    
    // MARK: - UI Components
    
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
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter anchor name"
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.textColor = .white
        textField.layer.cornerRadius = 10
        textField.clipsToBounds = true
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let siteTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter site"
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.textColor = .white
        textField.layer.cornerRadius = 10
        textField.clipsToBounds = true
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let sectionTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter section"
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.textColor = .white
        textField.layer.cornerRadius = 10
        textField.clipsToBounds = true
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let subsectionTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter subsection"
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.textColor = .white
        textField.layer.cornerRadius = 10
        textField.clipsToBounds = true
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let typeSegmentedControl: UISegmentedControl = {
        let items = ["Troubleshooting", "Guide", "Daily Routine"]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        segmentedControl.selectedSegmentTintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        return segmentedControl
    }()
    
    // MARK: - Initializers
    
    init(image: UIImage, saveHandler: @escaping (String, String, String, String, String) -> Void) {
        self.image = image
        self.saveHandler = saveHandler
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        setupNavigationBar()
        setupKeyboardHandling()
    }
    
    // MARK: - Setup Methods
    
    private func setupView() {
        view.backgroundColor = backgroundColor
        imageView.image = image
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addArrangedSubview(imageView)
        contentView.addArrangedSubview(nameTextField)
        contentView.addArrangedSubview(siteTextField)
        contentView.addArrangedSubview(sectionTextField)
        contentView.addArrangedSubview(subsectionTextField)
        contentView.addArrangedSubview(typeSegmentedControl)
        
        // Add padding to the bottom of the stack view
        contentView.addArrangedSubview(UIView())
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3),
            
            nameTextField.heightAnchor.constraint(equalToConstant: 44),
            siteTextField.heightAnchor.constraint(equalToConstant: 44),
            sectionTextField.heightAnchor.constraint(equalToConstant: 44),
            subsectionTextField.heightAnchor.constraint(equalToConstant: 44),
            typeSegmentedControl.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupNavigationBar() {
        title = "Add New Image"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barStyle = .black
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
    }
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: - Keyboard Handling
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardSize.height, right: 0.0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func saveTapped() {
        guard let name = nameTextField.text, !name.isEmpty,
              let site = siteTextField.text, !site.isEmpty,
              let section = sectionTextField.text, !section.isEmpty,
              let subsection = subsectionTextField.text, !subsection.isEmpty else {
            showAlert(message: "Please fill in all fields.")
            return
        }
        
        let type = typeSegmentedControl.titleForSegment(at: typeSegmentedControl.selectedSegmentIndex) ?? "Troubleshooting"
        saveHandler(name, type, site, section, subsection)
        dismiss(animated: true, completion: nil)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
