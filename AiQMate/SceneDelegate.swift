//
//  SceneDelegate.swift
//  AiQMate
//
//  Created by Kishore Murugan on 10/5/24.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Ensure we have a valid UIWindowScene instance
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Create a new UIWindow using the windowScene constructor which takes in a window scene
        window = UIWindow(windowScene: windowScene)

        // Check if the user is logged in
        if isUserLoggedIn() {
            // If the user is logged in, show the TabBarController
            let tabBarController = TabBarController()
            window?.rootViewController = tabBarController
        } else {
            // If the user is not logged in, show the LoginViewController
            let loginVC = LoginViewController()
            let navController = UINavigationController(rootViewController: loginVC)
            window?.rootViewController = navController
        }

        // Make the window visible
        window?.makeKeyAndVisible()
    }

    func isUserLoggedIn() -> Bool {
        // Implement your logic here to check if the user is logged in
        // For example, check if a user token exists in UserDefaults or if Firebase Auth has a current user
        // return true if logged in, otherwise return false
        
        // Firebase Auth example:
        // return Auth.auth().currentUser != nil
        
        // Placeholder for example
        return false
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
}
