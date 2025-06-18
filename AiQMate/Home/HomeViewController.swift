//
//  HomeViewController.swift
//  Dashboard counts live – **collection-view strip removed**
//

import UIKit
import AVFoundation
import FirebaseStorage
import FirebaseFirestore
import SDWebImage
import ARKit

// MARK: - Helper models

/// Four live counters for a category
struct CategoryStat {
    var anchors      = 0   // images
    var annotations  = 0
    var procedures   = 0
    var aiProc       = 0
}

// MARK: - Circle-ring view

final class CircleRingView: UIView {
    private let countLbl     = UILabel()
    private let progress     = CAShapeLayer()
    private let bg           = CAShapeLayer()
    
    init(metricName: String, color: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let size: CGFloat = 60
        let thickness: CGFloat = 6
        
        widthAnchor .constraint(equalToConstant: size).isActive = true
        heightAnchor.constraint(equalToConstant: size + 25).isActive = true
        
        // path
        let center = CGPoint(x: size/2, y: size/2)
        let path = UIBezierPath(arcCenter: center,
                                radius: (size - thickness)/2,
                                startAngle: -.pi/2,
                                endAngle: .pi*3/2,
                                clockwise: true)
        bg.path = path.cgPath
        bg.strokeColor = UIColor.darkGray.withAlphaComponent(0.3).cgColor
        bg.fillColor   = UIColor.clear.cgColor
        bg.lineWidth   = thickness
        
        progress.path = path.cgPath
        progress.strokeColor = color.cgColor
        progress.fillColor   = UIColor.clear.cgColor
        progress.lineWidth   = thickness
        progress.strokeEnd   = 0
        
        let ring = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.layer.addSublayer(bg)
        ring.layer.addSublayer(progress)
        addSubview(ring)
        
        countLbl.font = .systemFont(ofSize: 12, weight: .bold)
        countLbl.textColor = .white
        countLbl.textAlignment = .center
        countLbl.translatesAutoresizingMaskIntoConstraints = false
        ring.addSubview(countLbl)
        
        let metricLbl = UILabel()
        metricLbl.font = .systemFont(ofSize: 8)
        metricLbl.textColor = .lightGray
        metricLbl.textAlignment = .center
        metricLbl.text = metricName
        metricLbl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metricLbl)
        
        NSLayoutConstraint.activate([
            ring.topAnchor.constraint(equalTo: topAnchor),
            ring.centerXAnchor.constraint(equalTo: centerXAnchor),
            ring.widthAnchor.constraint(equalToConstant: size),
            ring.heightAnchor.constraint(equalToConstant: size),
            
            countLbl.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            countLbl.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            
            metricLbl.topAnchor.constraint(equalTo: ring.bottomAnchor, constant: 2),
            metricLbl.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    
    func update(value: Int, max: Int) {
        countLbl.text = "\(value)"
        progress.strokeEnd = max == 0 ? 0 : CGFloat(value) / CGFloat(max)
    }
}

// MARK: - Gradient title

final class GradientLabel: UILabel {
    private let gradient = CAGradientLayer()
    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }
    private func setup() {
        gradient.colors      = [UIColor(red: 0, green: 0.8, blue: 0.8,  alpha: 1).cgColor,
                                UIColor(red: 0, green: 0.57, blue: 0.61, alpha: 1).cgColor]
        gradient.startPoint  = .init(x: 0, y: 0.5)
        gradient.endPoint    = .init(x: 1, y: 0.5)
        layer.addSublayer(gradient)
        layer.mask = maskLayer()
    }
    private func maskLayer() -> CALayer {
        let t = CATextLayer()
        t.string         = text
        t.font           = font
        t.fontSize       = font.pointSize
        t.alignmentMode  = .center
        t.contentsScale  = UIScreen.main.scale
        t.frame          = bounds
        return t
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        layer.mask = maskLayer()
    }
    func animate() {
        let a = CABasicAnimation(keyPath: "locations")
        a.fromValue = [0, 0.5, 1]
        a.toValue   = [0.5, 1, 1.5]
        a.duration  = 4; a.repeatCount = .infinity
        gradient.add(a, forKey: "grad")
    }
}

// MARK: - HomeViewController

final class HomeViewController: UIViewController {
    
    // MARK: Constants
    private let brandColor      = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255,  blue: 27/255,  alpha: 1)
    private let categories      = ["Troubleshooting", "Guide", "Daily Routine"]
    
    // MARK: Data
    private var categoryStats: [String: CategoryStat]          = [:]   // live counters
    private var circleViews:   [String: [String: CircleRingView]] = [:]
    
    private var categoryData:  [String: [ImageItem]] = [:]            // still needed for Show All
    
    // MARK: UI
    private let titleLabel: GradientLabel = {
        let l = GradientLabel()
        l.text = "Home"
        l.font = UIFont(name: "AvenirNext-Bold", size: 24) ?? .boldSystemFont(ofSize: 24)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    private let contentStack: UIStackView = {
        let st = UIStackView()
        st.axis = .vertical
        st.spacing = 20
        st.translatesAutoresizingMaskIntoConstraints = false
        return st
    }()
    
    private let addButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = UIColor(red: 0, green: 0.57, blue: 0.61, alpha: 1)
        b.setImage(UIImage(systemName: "plus",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)),
                   for: .normal)
        b.tintColor = .white
        b.layer.cornerRadius = 30
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.3
        b.layer.shadowOffset = .init(width: 0, height: 3)
        b.layer.shadowRadius = 5
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    // MARK: Life-cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        drawBackground()
        layoutUI()
        addButton.addTarget(self, action: #selector(createAnchorTapped), for: .touchUpInside)
        fetchStats()
        fetchImages()            // keep images for Show All
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        titleLabel.animate()
    }
    
    // MARK: UI helpers
    private func drawBackground() {
        let g = CAGradientLayer()
        g.colors     = [backgroundColor.cgColor,
                        UIColor(red: 0, green: 40/255, blue: 50/255, alpha: 1).cgColor]
        g.startPoint = .init(x: 0, y: 0);  g.endPoint = .init(x: 1, y: 1)
        g.frame = view.bounds
        view.layer.insertSublayer(g, at: 0)
    }
    private func layoutUI() {
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        view.addSubview(addButton)
        scrollView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
            
            addButton.widthAnchor.constraint(equalToConstant: 60),
            addButton.heightAnchor.constraint(equalToConstant: 60),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        // category cards (no inner collection view)
        for cat in categories { contentStack.addArrangedSubview(makeCard(for: cat)) }
    }
    
    private func makeCard(for category: String) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(white: 1, alpha: 0.06)
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.3
        card.layer.shadowOffset = .init(width: 0, height: 2)
        card.layer.shadowRadius = 4
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let vStack = UIStackView(); vStack.axis = .vertical; vStack.spacing = 12; vStack.translatesAutoresizingMaskIntoConstraints = false
        
        // header row
        let header = UIStackView(); header.axis = .horizontal
        header.alignment = .center; header.distribution = .equalSpacing; header.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel(); title.text = category
        title.font = .boldSystemFont(ofSize: 20); title.textColor = .white
        let showAll = UIButton(type: .system)
        showAll.setTitle("Show All Anchor", for: .normal)
        showAll.setTitleColor(brandColor, for: .normal)
        showAll.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        if let idx = categories.firstIndex(of: category) { showAll.tag = idx }
        showAll.addTarget(self, action: #selector(showAllButtonTapped(_:)), for: .touchUpInside)
        header.addArrangedSubview(title); header.addArrangedSubview(showAll)
        
        // circle stats
        let circleRow = UIStackView(); circleRow.axis = .horizontal
        circleRow.alignment = .center; circleRow.distribution = .equalSpacing
        circleRow.spacing = 16; circleRow.translatesAutoresizingMaskIntoConstraints = false
        
        let metrics = ["Anchors", "Annotations", "Procedures", "AIProc"]
        var dict: [String: CircleRingView] = [:]
        for m in metrics {
            let ring = CircleRingView(metricName: m, color: brandColor)
            circleRow.addArrangedSubview(ring); dict[m] = ring
        }
        circleViews[category] = dict
        
        vStack.addArrangedSubview(header)
        vStack.addArrangedSubview(circleRow)
        card.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            circleRow.heightAnchor.constraint(equalToConstant: 100)
        ])
        return card
    }
    
    // MARK: Firestore – live counters
    private func fetchStats() {
        categories.forEach { categoryStats[$0] = CategoryStat() }
        let db = Firestore.firestore()
        let group = DispatchGroup()
        
        // Images
        group.enter()
        db.collection("images").getDocuments { [weak self] snap, _ in
            snap?.documents.forEach { d in
                if let cat = d["type"] as? String { self?.categoryStats[cat, default: .init()].anchors += 1 }
            }; group.leave()
        }
        // Annotations
        group.enter()
        db.collection("annotations").getDocuments { [weak self] snap, _ in
            snap?.documents.forEach { d in
                if let cat = d["categoryName"] as? String { self?.categoryStats[cat, default: .init()].annotations += 1 }
            }; group.leave()
        }
        // Procedures
        group.enter()
        db.collection("procedures").getDocuments { [weak self] snap, _ in
            snap?.documents.forEach { d in
                if let cat = d["categoryName"] as? String { self?.categoryStats[cat, default: .init()].procedures += 1 }
            }; group.leave()
        }
        // AI Procedures
        group.enter()
        db.collection("aiProcedures").getDocuments { [weak self] snap, _ in
            snap?.documents.forEach { d in
                if let cat = d["categoryName"] as? String { self?.categoryStats[cat, default: .init()].aiProc += 1 }
            }; group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in self?.refreshRings() }
    }
    private func refreshRings() {
        categoryStats.forEach { cat, stat in
            let maxVal = max(stat.anchors, stat.annotations, stat.procedures, stat.aiProc)
            guard let rings = circleViews[cat] else { return }
            rings["Anchors"]?.update(value: stat.anchors,     max: maxVal)
            rings["Annotations"]?.update(value: stat.annotations, max: maxVal)
            rings["Procedures"]?.update(value: stat.procedures,  max: maxVal)
            rings["AIProc"]?.update(value: stat.aiProc,       max: maxVal)
        }
    }
    
    // MARK: Firestore – images (for Show All list)
    private func fetchImages() {
        Firestore.firestore().collection("images").getDocuments { [weak self] snap, _ in
            snap?.documents.forEach { d in
                guard let name = d["name"] as? String,
                      let type = d["type"] as? String,
                      let site = d["site"] as? String,
                      let section = d["section"] as? String,
                      let sub = d["subsection"] as? String,
                      let urlStr = d["url"] as? String,
                      let url = URL(string: urlStr) else { return }
                let item = ImageItem(id: d.documentID,
                                     name: name,
                                     imageURL: url,
                                     site: site,
                                     section: section,
                                     subsection: sub,
                                     type: type)
                self?.categoryData[type, default: []].append(item)
            }
        }
    }
    
    // MARK: Actions
    @objc private func showAllButtonTapped(_ sender: UIButton) {
        let cat = categories[sender.tag]
        let vc  = CategoryListViewController(categoryName: cat, imageItems: categoryData[cat] ?? [])
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
    
    @objc private func createAnchorTapped() { checkCameraPermission() }
    
    // MARK: Camera helpers
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: presentCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] g in
                DispatchQueue.main.async { g ? self?.presentCamera() : self?.noCameraAlert() }
            }
        default: noCameraAlert()
        }
    }
    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera; picker.delegate = self
        present(picker, animated: true)
    }
    private func noCameraAlert() {
        let a = UIAlertController(title: "Camera Needed",
                                  message: "Enable camera in Settings to capture anchors.",
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        a.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
        })
        present(a, animated: true)
    }
}

// MARK: - Image picker
extension HomeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let img = info[.originalImage] as? UIImage else { return }
        let detail = ImageDetailsViewController(image: img) { [weak self]
            name, type, site, section, subsection in
            self?.upload(image: img, name: name, type: type, site: site,
                         section: section, subsection: subsection)
        }
        let nav = UINavigationController(rootViewController: detail)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
    
    private func upload(image: UIImage,
                        name: String, type: String,
                        site: String, section: String, subsection: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let ref = Storage.storage().reference().child("images/\(UUID().uuidString).jpg")
        ref.putData(data, metadata: nil) { [weak self] _, err in
            if err != nil { return }
            ref.downloadURL { url, _ in
                guard let url = url else { return }
                let db = Firestore.firestore()
                db.collection("images").document().setData([
                    "name": name, "type": type,
                    "site": site, "section": section, "subsection": subsection,
                    "url": url.absoluteString,
                    "timestamp": FieldValue.serverTimestamp()
                ]) { error in
                    guard error == nil else { return }
                    // Increment local counts & UI
                    self?.categoryStats[type, default: .init()].anchors += 1
                    self?.refreshRings()
                    // store item for list
                    let item = ImageItem(id: UUID().uuidString,
                                         name: name, imageURL: url,
                                         site: site, section: section,
                                         subsection: subsection, type: type)
                    self?.categoryData[type, default: []].append(item)
                }
            }
        }
    }
}
