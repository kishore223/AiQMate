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
        let profileVC = ProfileViewController()

        // Set titles and icons (optional)
        homeVC.title = "Home"
        summarizeVC.title = "Summarize"
        botVC.title = "Bot"
        profileVC.title = "Profile"

        // Create a UINavigationController for each tab (optional)
        let homeNav = UINavigationController(rootViewController: homeVC)
        let summarizeNav = UINavigationController(rootViewController: summarizeVC)
        let botNav = UINavigationController(rootViewController: botVC)
        let profileNav = UINavigationController(rootViewController: profileVC)

        // Assign tab icons
        homeNav.tabBarItem.image = UIImage(systemName: "house.fill")
        summarizeNav.tabBarItem.image = UIImage(systemName: "text.book.closed.fill")
        botNav.tabBarItem.image = UIImage(systemName: "message.circle.fill")
        profileNav.tabBarItem.image = UIImage(systemName: "person.circle.fill")

        // Add view controllers to the tab bar
        viewControllers = [homeNav, summarizeNav, botNav, profileNav]
    }
}
