import UIKit

class TabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the tint color for the selected tab (button color)
        tabBar.tintColor = UIColor(red: 0/255, green: 146/255, blue: 155/255, alpha: 1.0)

        // Create instance of each view controller
        let homeVC = HomeViewController()
        let summarizeVC = SummarizeViewController()
        let botVC = BotViewController()
        let systemAuditVC = SystemAuditViewController()
        let arWorldVC = ARWorldViewController() // NEW ARWorld tab
        let profileVC = ProfileViewController()

        // Set titles and icons
        homeVC.title = "Home"
        summarizeVC.title = "Summarize"
        botVC.title = "Bot"
        systemAuditVC.title = "System Audit"
        arWorldVC.title = "ARWorld" // NEW
        profileVC.title = "Profile"

        // Create a UINavigationController for each tab
        let homeNav = UINavigationController(rootViewController: homeVC)
        let summarizeNav = UINavigationController(rootViewController: summarizeVC)
        let botNav = UINavigationController(rootViewController: botVC)
        let systemAuditNav = UINavigationController(rootViewController: systemAuditVC)
        let arWorldNav = UINavigationController(rootViewController: arWorldVC) // NEW
        let profileNav = UINavigationController(rootViewController: profileVC)

        // Assign tab icons
        homeNav.tabBarItem.image = UIImage(systemName: "house.fill")
        summarizeNav.tabBarItem.image = UIImage(systemName: "text.book.closed.fill")
        botNav.tabBarItem.image = UIImage(systemName: "message.circle.fill")
        systemAuditNav.tabBarItem.image = UIImage(systemName: "magnifyingglass.circle.fill")
        arWorldNav.tabBarItem.image = UIImage(systemName: "arkit") // NEW - ARKit icon
        profileNav.tabBarItem.image = UIImage(systemName: "person.circle.fill")

        // Add view controllers to the tab bar - ARWorld positioned before Profile
        viewControllers = [homeNav, summarizeNav, botNav, systemAuditNav, arWorldNav, profileNav]
    }
}
