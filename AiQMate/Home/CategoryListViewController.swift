import UIKit

// MARK: - CategoryListViewController

class CategoryListViewController: UIViewController {
    
    // MARK: - UI Properties
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search images..."
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private let filterButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let brandColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)
    private let backgroundColor = UIColor(red: 5/255, green: 2/255, blue: 27/255, alpha: 1.0)
    
    // MARK: - Data / Filtering
    
    private var categoryName: String
    private var originalItems: [ImageItem]   // store the full unfiltered list
    private var filteredItems: [ImageItem]   // store the current filtered list
    
    // Example filter state. (In a real app, these might come from a FilterViewController.)
    private var selectedSite: String?
    private var selectedSection: String?
    private var selectedSubsection: String?
    
    // MARK: - Collection View
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection          = .vertical
        layout.minimumLineSpacing       = 15
        layout.minimumInteritemSpacing  = 15
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.contentInset    = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    // MARK: - Init
    
    init(categoryName: String, imageItems: [ImageItem]) {
        self.categoryName   = categoryName
        self.originalItems  = imageItems
        self.filteredItems  = imageItems
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = backgroundColor
        
        // Setup the top bar (search + filter).
        setupTopBar()
        setupCollectionView()
        
        title = "\(categoryName) Anchor Images"
        
        // Close button on the left
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )
        navigationController?.navigationBar.tintColor = .white
    }
    
    // MARK: - Setup
    
    private func setupTopBar() {
        // We'll place the search bar and filter button at the top in a container.
        let topContainer = UIView()
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topContainer)
        
        topContainer.addSubview(searchBar)
        topContainer.addSubview(filterButton)
        
        // Customize search bar appearance if desired:
        customizeSearchBarAppearance(searchBar)
        
        // Constraints for the container
        NSLayoutConstraint.activate([
            topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topContainer.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Constraints for the searchBar and filterButton inside topContainer
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor, constant: 10),
            searchBar.topAnchor.constraint(equalTo: topContainer.topAnchor),
            searchBar.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor),
            
            filterButton.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            filterButton.leadingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: 10),
            filterButton.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor, constant: -10),
            filterButton.widthAnchor.constraint(equalToConstant: 25),
            filterButton.heightAnchor.constraint(equalToConstant: 25)
        ])
        
        searchBar.delegate = self
        filterButton.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
    }
    
    private func customizeSearchBarAppearance(_ searchBar: UISearchBar) {
        searchBar.searchBarStyle = .minimal
        searchBar.barTintColor   = backgroundColor
        searchBar.tintColor      = brandColor
        
        // For iOS 13+, you can do:
        if let textField = searchBar.searchTextField as? UITextField {
            textField.textColor = .white
            textField.layer.cornerRadius = 8
            textField.clipsToBounds = true
            
            if let leftView = textField.leftView as? UIImageView {
                leftView.tintColor = .white
            }
        }
        
        // Remove background
        searchBar.backgroundImage = UIImage()
        searchBar.backgroundColor = .clear
    }
    
    private func setupCollectionView() {
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        collectionView.delegate   = self
        collectionView.dataSource = self
        collectionView.register(ItemCell.self, forCellWithReuseIdentifier: "ItemCell")
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
    
    // MARK: - Filter / Search
    
    @objc private func filterButtonTapped() {
        // Present your FilterViewController or your filter UI here.
        // For demonstration, let's do something minimal:
        let filterVC = FilterViewController()
        filterVC.delegate = self
        // If you track allSites/allSections/allSubsections, you could pass them in:
        // filterVC.sites = ...
        // filterVC.sections = ...
        // filterVC.subsections = ...
        
        // Or you can let user pick from a static list. The idea is the same.
        let nav = UINavigationController(rootViewController: filterVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
    
    private func applyFiltersAndSearch() {
        // 1) Start from the full list
        var results = originalItems
        
        // 2) If you have selectedSite, selectedSection, selectedSubsection, filter them
        if let site = selectedSite, !site.isEmpty, site != "All Sites" {
            results = results.filter { $0.site == site }
        }
        if let section = selectedSection, !section.isEmpty, section != "All Sections" {
            results = results.filter { $0.section == section }
        }
        if let subsection = selectedSubsection, !subsection.isEmpty, subsection != "All Subsections" {
            results = results.filter { $0.subsection == subsection }
        }
        
        // 3) Now filter by search text if needed
        if let searchText = searchBar.text, !searchText.isEmpty {
            let text = searchText.lowercased()
            results = results.filter { item in
                // Check name, site, section, subsection, type, etc.
                return item.name.lowercased().contains(text) ||
                       item.site.lowercased().contains(text) ||
                       item.section.lowercased().contains(text) ||
                       item.subsection.lowercased().contains(text) ||
                       item.type.lowercased().contains(text)
            }
        }
        
        // 4) Update filteredItems
        filteredItems = results
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate

extension CategoryListViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return filteredItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ItemCell",
                                                      for: indexPath) as! ItemCell
        let imageItem = filteredItems[indexPath.item]
        cell.configure(with: imageItem)
        
        // Add favorite toggle handler
        cell.favoriteToggleHandler = { [weak self] item in
            guard let self = self else { return }
            if let idx = self.originalItems.firstIndex(where: { $0.id == item.id }) {
                self.originalItems[idx].isFavorite.toggle()
            }
            // Also toggle in filteredItems if needed
            if let idx2 = self.filteredItems.firstIndex(where: { $0.id == item.id }) {
                self.filteredItems[idx2].isFavorite.toggle()
            }
            // Typically you'd also update Firebase here.
            cell.configure(with: self.filteredItems[indexPath.item])
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        
        let imageItem = filteredItems[indexPath.item]
        
        let objectDetectionVC = ObjectDetectionVC()
        objectDetectionVC.imageItem = imageItem
        objectDetectionVC.title     = "Pin"
        
        let procedureVC = ProcedureViewController()
        procedureVC.imageItem   = imageItem
        procedureVC.containerID = imageItem.id
        procedureVC.title       = "Procedure"
        
        let aiProcedureVC = AIProcedureViewController()
        aiProcedureVC.imageItem   = imageItem
        aiProcedureVC.containerID = imageItem.id
        aiProcedureVC.title       = "AI Procedure"
        
        let objectDetectionNav = UINavigationController(rootViewController: objectDetectionVC)
        let procedureNav       = UINavigationController(rootViewController: procedureVC)
        let aiProcedureNav     = UINavigationController(rootViewController: aiProcedureVC)
        
        objectDetectionNav.tabBarItem = UITabBarItem(
            title: "Pin",
            image: UIImage(systemName: "pin.fill"),
            selectedImage: UIImage(systemName: "pin.fill")
        )
        procedureNav.tabBarItem = UITabBarItem(
            title: "Procedure",
            image: UIImage(systemName: "list.bullet"),
            selectedImage: UIImage(systemName: "list.bullet")
        )
        aiProcedureNav.tabBarItem = UITabBarItem(
            title: "AI Procedure",
            image: UIImage(systemName: "brain.head.profile"),
            selectedImage: UIImage(systemName: "brain.head.profile")
        )
        
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [objectDetectionNav, procedureNav, aiProcedureNav]
        
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor
        
        tabBarController.tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBarController.tabBar.scrollEdgeAppearance = appearance
        }
        
        tabBarController.tabBar.tintColor             = brandColor
        tabBarController.tabBar.unselectedItemTintColor = .gray
        tabBarController.modalPresentationStyle       = .fullScreen
        
        present(tabBarController, animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CategoryListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let padding: CGFloat       = 45  // 15 left + 15 right + 15 between
        let availableWidth         = collectionView.bounds.width - padding
        let itemWidth              = availableWidth / 2
        return CGSize(width: itemWidth, height: itemWidth * 1.5)
    }
}

// MARK: - UISearchBarDelegate

extension CategoryListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFiltersAndSearch()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // If you had a 'Cancel' button, you can reset the text or something similar:
        searchBar.text = ""
        applyFiltersAndSearch()
    }
}

// MARK: - FilterViewControllerDelegate (Example)

extension CategoryListViewController: FilterViewControllerDelegate {
    func didApplyFilters(site: String?, section: String?, subsection: String?) {
        self.selectedSite       = site
        self.selectedSection    = section
        self.selectedSubsection = subsection
        applyFiltersAndSearch()
    }
    
    func didClearFilters() {
        self.selectedSite       = nil
        self.selectedSection    = nil
        self.selectedSubsection = nil
        applyFiltersAndSearch()
    }
}
