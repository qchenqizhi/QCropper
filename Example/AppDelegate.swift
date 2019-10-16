//
//  AppDelegate.swift
//
//  Created by Chen Qizhi on 2019/10/15.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)
        guard let window = window else {
            return false
        }

        window.rootViewController = ViewController()
        window.makeKeyAndVisible()

        return true
    }
}
