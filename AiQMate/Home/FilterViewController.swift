import UIKit

protocol FilterViewControllerDelegate: AnyObject {
    func didApplyFilters(site: String?, section: String?, subsection: String?)
    func didClearFilters()
}

class FilterViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: FilterViewControllerDelegate?
    
    // Dynamic data for pickers
    var sites: [String] = ["All Sites"]
    var sections: [String] = ["All Sections"]
    var subsections: [String] = ["All Subsections"]
    
    // Selected filters
    var selectedSite: String?
    var selectedSection: String?
    var selectedSubsection: String?
    
    // UI Elements
    private let headerView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let siteTextField = CustomTextField()
    private let sectionTextField = CustomTextField()
    private let subsectionTextField = CustomTextField()
    private let applyButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        setupActions()
        setupPickers()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = headerView.bounds
    }
    
    // MARK: - Setup Methods
    
    private func setupView() {
        view.backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
        
        // Header View Setup
        gradientLayer.colors = [
            UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        headerView.layer.addSublayer(gradientLayer)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.text = "Filter Images"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        view.addSubview(headerView)
        
        // ScrollView and ContentView Setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Customize TextFields
        configureTextField(siteTextField, placeholder: "Select Site", iconName: "building.2")
        configureTextField(sectionTextField, placeholder: "Select Section", iconName: "square.grid.2x2")
        configureTextField(subsectionTextField, placeholder: "Select Subsection", iconName: "square.grid.3x2")
        
        // Customize Buttons
        configureButton(applyButton, title: "Apply Filters", backgroundColor: UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0))
        configureButton(clearButton, title: "Clear Filters", backgroundColor: UIColor.systemRed)
        
        // Add subviews to contentView
        [siteTextField, sectionTextField, subsectionTextField, applyButton, clearButton].forEach {
            contentView.addSubview($0)
        }
        
        // Add Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(cancelButton)
        
        // Constraints for cancelButton and titleLabel
        NSLayoutConstraint.activate([
            cancelButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -15),
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // HeaderView Constraints
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),
            
            // ScrollView Constraints
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView Constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // SiteTextField Constraints
            siteTextField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            siteTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            siteTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            siteTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // SectionTextField Constraints
            sectionTextField.topAnchor.constraint(equalTo: siteTextField.bottomAnchor, constant: 20),
            sectionTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sectionTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            sectionTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // SubsectionTextField Constraints
            subsectionTextField.topAnchor.constraint(equalTo: sectionTextField.bottomAnchor, constant: 20),
            subsectionTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subsectionTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            subsectionTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // ApplyButton Constraints
            applyButton.topAnchor.constraint(equalTo: subsectionTextField.bottomAnchor, constant: 40),
            applyButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            applyButton.heightAnchor.constraint(equalToConstant: 50),
            
            // ClearButton Constraints
            clearButton.topAnchor.constraint(equalTo: applyButton.bottomAnchor, constant: 20),
            clearButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            clearButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            clearButton.heightAnchor.constraint(equalToConstant: 50),
            clearButton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
    }
    
    private func setupPickers() {
        // Create pickers for each text field
        let sitePicker = UIPickerView()
        sitePicker.tag = 1
        sitePicker.delegate = self
        sitePicker.dataSource = self
        siteTextField.inputView = sitePicker
        
        let sectionPicker = UIPickerView()
        sectionPicker.tag = 2
        sectionPicker.delegate = self
        sectionPicker.dataSource = self
        sectionTextField.inputView = sectionPicker
        
        let subsectionPicker = UIPickerView()
        subsectionPicker.tag = 3
        subsectionPicker.delegate = self
        subsectionPicker.dataSource = self
        subsectionTextField.inputView = subsectionPicker
        
        // Add toolbar with Done button for pickers
        [siteTextField, sectionTextField, subsectionTextField].forEach { textField in
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            toolbar.barStyle = .default
            toolbar.tintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
            toolbar.backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
            let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(donePicker))
            let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            toolbar.setItems([space, doneButton], animated: false)
            textField.inputAccessoryView = toolbar
        }
        
        // Set initial values
        siteTextField.text = selectedSite ?? "All Sites"
        sectionTextField.text = selectedSection ?? "All Sections"
        subsectionTextField.text = selectedSubsection ?? "All Subsections"
    }
    
    private func configureTextField(_ textField: CustomTextField, placeholder: String, iconName: String) {
        textField.placeholder = placeholder
        textField.setIcon(UIImage(systemName: iconName))
    }
    
    private func configureButton(_ button: UIButton, title: String, backgroundColor: UIColor) {
        button.setTitle(title, for: .normal)
        button.backgroundColor = backgroundColor
        button.tintColor = .white
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 5
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add touch animation
        button.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchDragExit, .touchCancel])
    }
    
    // MARK: - Action Methods
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func applyButtonTapped() {
        let site = siteTextField.text == "All Sites" ? nil : siteTextField.text
        let section = sectionTextField.text == "All Sections" ? nil : sectionTextField.text
        let subsection = subsectionTextField.text == "All Subsections" ? nil : subsectionTextField.text
        delegate?.didApplyFilters(site: site, section: section, subsection: subsection)
        dismiss(animated: true)
    }
    
    @objc private func clearButtonTapped() {
        selectedSite = nil
        selectedSection = nil
        selectedSubsection = nil
        siteTextField.text = "All Sites"
        sectionTextField.text = "All Sections"
        subsectionTextField.text = "All Subsections"
        delegate?.didClearFilters()
        dismiss(animated: true)
    }
    
    @objc private func donePicker() {
        view.endEditing(true)
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.alpha = 0.7
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.alpha = 1.0
        }
    }
}

// MARK: - UIPickerViewDelegate & UIPickerViewDataSource

extension FilterViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView.tag {
        case 1:
            return sites.count
        case 2:
            return sections.count
        case 3:
            return subsections.count
        default:
            return 0
        }
    }
    
    // Customize picker view appearance for dark background
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 30
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title: String
        switch pickerView.tag {
        case 1:
            title = sites[row]
        case 2:
            title = sections[row]
        case 3:
            title = subsections[row]
        default:
            title = ""
        }
        return NSAttributedString(string: title, attributes: [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 16, weight: .regular)
        ])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView.tag {
        case 1:
            let site = sites[row]
            selectedSite = site == "All Sites" ? nil : site
            siteTextField.text = site
        case 2:
            let section = sections[row]
            selectedSection = section == "All Sections" ? nil : section
            sectionTextField.text = section
        case 3:
            let subsection = subsections[row]
            selectedSubsection = subsection == "All Subsections" ? nil : subsection
            subsectionTextField.text = subsection
        default:
            break
        }
    }
}

// MARK: - CustomTextField

class CustomTextField: UITextField {
    private let padding = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 10)
    private let iconView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func configure() {
        textColor = .white
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layer.cornerRadius = 10
        clipsToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        font = UIFont.systemFont(ofSize: 16)
        translatesAutoresizingMaskIntoConstraints = false
        
        // Placeholder color
        attributedPlaceholder = NSAttributedString(string: placeholder ?? "", attributes: [
            .foregroundColor: UIColor.white.withAlphaComponent(0.7)
        ])
        
        // Icon View
        iconView.tintColor = UIColor.white.withAlphaComponent(0.7)
        addSubview(iconView)
        
        // Constraints for Icon View
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func setIcon(_ image: UIImage?) {
        iconView.image = image
    }
    
    // Text Rects
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
}
