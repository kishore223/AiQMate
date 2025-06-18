// ItemCell.swift – favorite UI completely removed

import UIKit
import SDWebImage

class ItemCell: UICollectionViewCell {
    
    // MARK: UI
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let tintOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 2
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let nameLabel     = ItemCell.makeInfoLabel(weight: .bold, size: 14)
    private let siteLabel     = ItemCell.makeInfoLabel()
    private let sectionLabel  = ItemCell.makeInfoLabel()
    private let subsectionLabel = ItemCell.makeInfoLabel()
    
    // MARK: Cell lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupViews() {
        contentView.addSubview(imageView)
        contentView.addSubview(tintOverlay)
        contentView.addSubview(stackView)
        
        [nameLabel, siteLabel, sectionLabel, subsectionLabel].forEach { stackView.addArrangedSubview($0) }
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            tintOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            tintOverlay.heightAnchor.constraint(equalToConstant: 80),
            
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        
        // subtle border
        contentView.layer.borderColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1).cgColor
        contentView.layer.borderWidth = 0.5
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
    }
    
    // MARK: Configure
    
    func configure(with item: ImageItem) {
        nameLabel.text       = item.name
        siteLabel.text       = item.site
        sectionLabel.text    = item.section
        subsectionLabel.text = item.subsection
        imageView.sd_setImage(
            with: item.imageURL,
            placeholderImage: UIImage(systemName: "photo"),
            options: [])
    }
    
    // MARK: Helpers
    
    private static func makeInfoLabel(weight: UIFont.Weight = .regular, size: CGFloat = 12) -> UILabel {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: size, weight: weight)
        lbl.textColor = weight == .bold ? .white : .lightGray
        lbl.numberOfLines = 1
        return lbl
    }
}
