// CategoryListViewController.swift
// Icons added to each tab-bar item

import UIKit

class CategoryListViewController: UIViewController {
    
    // MARK: - UI
    
    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "Search images..."
        sb.searchBarStyle = .minimal
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()
    
    private let filterButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        btn.tintColor = .white
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let brandColor      = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1)
    
    // MARK: - Data
    
    private let categoryName: String
    private var originalItems: [ImageItem]
    private var filteredItems: [ImageItem]
    
    private var selectedSite: String?
    private var selectedSection: String?
    private var selectedSubsection: String?
    
    // MARK: - CollectionView
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing      = 15
        layout.minimumInteritemSpacing = 15
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.contentInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    // MARK: - Init
    
    init(categoryName: String, imageItems: [ImageItem]) {
        self.categoryName  = categoryName
        self.originalItems = imageItems
        self.filteredItems = imageItems
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = backgroundColor
        
        setupTopBar()
        setupCollectionView()
        
        title = "\(categoryName) Anchor Images"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissSelf))
        navigationController?.navigationBar.tintColor = .white
    }
    
    // MARK: - UI Setup
    
    private func setupTopBar() {
        let top = UIView()
        top.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)
        top.addSubview(searchBar)
        top.addSubview(filterButton)
        customize(searchBar)
        
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            top.heightAnchor.constraint(equalToConstant: 50),
            
            searchBar.leadingAnchor.constraint(equalTo: top.leadingAnchor, constant: 10),
            searchBar.topAnchor.constraint(equalTo: top.topAnchor),
            searchBar.bottomAnchor.constraint(equalTo: top.bottomAnchor),
            
            filterButton.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            filterButton.leadingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: 10),
            filterButton.trailingAnchor.constraint(equalTo: top.trailingAnchor, constant: -10),
            filterButton.widthAnchor.constraint(equalToConstant: 25),
            filterButton.heightAnchor.constraint(equalToConstant: 25)
        ])
        
        searchBar.delegate = self
        filterButton.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
    }
    
    private func customize(_ sb: UISearchBar) {
        sb.barTintColor = backgroundColor
        sb.tintColor    = brandColor
        sb.backgroundImage = UIImage()
        if let tf = sb.searchTextField as? UITextField {
            tf.textColor = .white
            tf.layer.cornerRadius = 8
            if let iv = tf.leftView as? UIImageView { iv.tintColor = .white }
        }
    }
    
    private func setupCollectionView() {
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        collectionView.register(ItemCell.self, forCellWithReuseIdentifier: "ItemCell")
        collectionView.delegate   = self
        collectionView.dataSource = self
    }
    
    // MARK: - Actions
    
    @objc private func dismissSelf() { dismiss(animated: true) }
    
    @objc private func filterButtonTapped() {
        let fvc = FilterViewController()
        fvc.delegate = self
        let nav = UINavigationController(rootViewController: fvc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
    
    private func applyFiltersAndSearch() {
        var results = originalItems
        
        if let s = selectedSite, !s.isEmpty       { results = results.filter { $0.site       == s } }
        if let s = selectedSection, !s.isEmpty    { results = results.filter { $0.section    == s } }
        if let s = selectedSubsection, !s.isEmpty { results = results.filter { $0.subsection == s } }
        
        if let txt = searchBar.text?.lowercased(), !txt.isEmpty {
            results = results.filter { item in
                item.name.lowercased().contains(txt) ||
                item.site.lowercased().contains(txt) ||
                item.section.lowercased().contains(txt) ||
                item.subsection.lowercased().contains(txt) ||
                item.type.lowercased().contains(txt)
            }
        }
        filteredItems = results
        collectionView.reloadData()
    }
}

// MARK: - CollectionView

extension CategoryListViewController: UICollectionViewDataSource,
                                      UICollectionViewDelegate,
                                      UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredItems.count
    }
    
    func collectionView(_ cv: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "ItemCell", for: indexPath) as! ItemCell
        cell.configure(with: filteredItems[indexPath.item])
        return cell
    }
    
    func collectionView(_ cv: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let item = filteredItems[indexPath.item]
        
        // 1. Build view-controllers
        let pinVC  = ObjectDetectionVC();  pinVC.imageItem = item;  pinVC.title = "Pin"
        let procVC = ProcedureViewController()
        procVC.imageItem = item;  procVC.containerID = item.id;  procVC.title = "Procedure"
        let aiVC   = AIProcedureViewController()
        aiVC.imageItem = item;  aiVC.containerID = item.id;  aiVC.title = "AI Procedure"
        
        // 2. Embed each in a nav-controller
        let pinNav  = UINavigationController(rootViewController: pinVC)
        let procNav = UINavigationController(rootViewController: procVC)
        let aiNav   = UINavigationController(rootViewController: aiVC)
        
        // 3. **Set icons + titles**
        pinNav.tabBarItem  = UITabBarItem(title: "Pin",
                                          image: UIImage(systemName: "pin.fill"),
                                          selectedImage: UIImage(systemName: "pin.fill"))
        procNav.tabBarItem = UITabBarItem(title: "Procedure",
                                          image: UIImage(systemName: "list.bullet"),
                                          selectedImage: UIImage(systemName: "list.bullet"))
        aiNav.tabBarItem   = UITabBarItem(title: "AI Procedure",
                                          image: UIImage(systemName: "brain.head.profile"),
                                          selectedImage: UIImage(systemName: "brain.head.profile"))
        
        // 4. Configure tab-bar controller
        let tab = UITabBarController()
        tab.viewControllers = [pinNav, procNav, aiNav]
        
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor
        tab.tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) { tab.tabBar.scrollEdgeAppearance = appearance }
        tab.tabBar.tintColor              = brandColor
        tab.tabBar.unselectedItemTintColor = .gray
        tab.modalPresentationStyle        = .fullScreen
        
        present(tab, animated: true)
    }
    
    func collectionView(_ cv: UICollectionView,
                        layout _: UICollectionViewLayout,
                        sizeForItemAt _: IndexPath) -> CGSize {
        let padding: CGFloat = 45
        let w = (cv.bounds.width - padding) / 2
        return CGSize(width: w, height: w * 1.5)
    }
}

// MARK: - Search & Filter Delegates

extension CategoryListViewController: UISearchBarDelegate {
    func searchBar(_ sb: UISearchBar, textDidChange _: String) { applyFiltersAndSearch() }
    func searchBarCancelButtonClicked(_: UISearchBar) {
        searchBar.text = ""; applyFiltersAndSearch()
    }
}

extension CategoryListViewController: FilterViewControllerDelegate {
    func didApplyFilters(site: String?, section: String?, subsection: String?) {
        selectedSite = site; selectedSection = section; selectedSubsection = subsection
        applyFiltersAndSearch()
    }
    func didClearFilters() {
        selectedSite = nil; selectedSection = nil; selectedSubsection = nil
        applyFiltersAndSearch()
    }
}
