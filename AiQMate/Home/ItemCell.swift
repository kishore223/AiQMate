// Updated ItemCell.swift with fixed favorite functionality

import UIKit
import SDWebImage

// MARK: - ItemCell

class ItemCell: UICollectionViewCell {
    // MARK: - UI Components

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let tintOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.customFont(ofSize: 14, weight: .bold)
        label.textColor = .customTextColor
        label.numberOfLines = 1
        return label
    }()

    private let siteLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .lightGray
        label.numberOfLines = 1
        return label
    }()

    private let sectionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .lightGray
        label.numberOfLines = 1
        return label
    }()

    private let subsectionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .lightGray
        label.numberOfLines = 1
        return label
    }()

    private let favoriteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "heart"), for: .normal)
        button.tintColor = .customTextColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Properties

    private var imageItem: ImageItem?
    var favoriteToggleHandler: ((ImageItem) -> Void)?
    
    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup Methods

    private func setupViews() {
        contentView.addSubview(imageView)
        contentView.addSubview(tintOverlay)
        contentView.addSubview(stackView)
        contentView.addSubview(favoriteButton)

        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(siteLabel)
        stackView.addArrangedSubview(sectionLabel)
        stackView.addArrangedSubview(subsectionLabel)

        NSLayoutConstraint.activate([
            // ImageView Constraints
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // TintOverlay Constraints
            tintOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            tintOverlay.heightAnchor.constraint(equalToConstant: 80),

            // StackView Constraints
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            // FavoriteButton Constraints
            favoriteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            favoriteButton.widthAnchor.constraint(equalToConstant: 24),
            favoriteButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        favoriteButton.addTarget(self, action: #selector(favoriteButtonTapped), for: .touchUpInside)

        // Add border to contentView
        contentView.layer.borderColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0).cgColor
        contentView.layer.borderWidth = 0.5
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }

    // MARK: - Configuration

    func configure(with imageItem: ImageItem) {
        self.imageItem = imageItem
        nameLabel.text = imageItem.name
        siteLabel.text = imageItem.site
        sectionLabel.text = imageItem.section
        subsectionLabel.text = imageItem.subsection

        // Load image using SDWebImage
        imageView.sd_setImage(with: imageItem.imageURL, placeholderImage: UIImage(systemName: "photo"), options: [], completed: nil)

        // Update favorite button
        updateFavoriteButton(isFavorite: imageItem.isFavorite)
    }

    private func updateFavoriteButton(isFavorite: Bool) {
        let heartImageName = isFavorite ? "heart.fill" : "heart"
        favoriteButton.setImage(UIImage(systemName: heartImageName), for: .normal)
        favoriteButton.tintColor = isFavorite ? .systemRed : .customTextColor
        
        // Add a subtle animation when favoriting
        if isFavorite {
            favoriteButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            UIView.animate(withDuration: 0.2,
                          delay: 0,
                          usingSpringWithDamping: 0.5,
                          initialSpringVelocity: 0.5,
                          options: .allowUserInteraction,
                          animations: {
                self.favoriteButton.transform = CGAffineTransform.identity
            }, completion: nil)
        }
    }

    // MARK: - Actions

    @objc private func favoriteButtonTapped() {
        guard let imageItem = imageItem else { return }
        
        // Create a new ImageItem with toggled favorite status
        let updatedItem = ImageItem(
            id: imageItem.id,
            name: imageItem.name,
            imageURL: imageItem.imageURL,
            site: imageItem.site,
            section: imageItem.section,
            subsection: imageItem.subsection,
            type: imageItem.type,
            isFavorite: !imageItem.isFavorite
        )
        
        // Update the local imageItem
        self.imageItem = updatedItem
        
        // Update the UI immediately for responsive feel
        updateFavoriteButton(isFavorite: updatedItem.isFavorite)
        
        // Call the handler to update the parent's data and Firebase
        favoriteToggleHandler?(updatedItem)
    }

    // MARK: - Prepare for Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
        favoriteButton.transform = CGAffineTransform.identity
    }
}
