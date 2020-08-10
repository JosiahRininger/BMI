//
//  SceneDelegate.swift
//  BMI
//
//  Created by Josiah Rininger on 8/5/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            setUserDefaults()
            window.rootViewController = UIHostingController(rootView: BMIView())
            self.window = window
            window.makeKeyAndVisible()
        }
    }
    
    private func setUserDefaults() {
        if UserDefaults.standard.integer(forKey: "timerOn") == 0 {
            UserDefaults.standard.set(5, forKey: "timerOn")
        }
        if UserDefaults.standard.integer(forKey: "timeOff") == 0 {
            UserDefaults.standard.set(1, forKey: "timeOff")
        }
        if UserDefaults.standard.integer(forKey: "rounds") == 0 {
            UserDefaults.standard.set(4, forKey: "rounds")
        }
    }
    
}
