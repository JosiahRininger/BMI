//
//  UIColor.swift
//  BMI
//
//  Created by Josiah Rininger on 6/6/19.
//  Copyright © 2019 Josiah Rininger. All rights reserved.
//

import UIKit

extension UIColor {
    
    // Theme Colors Used
    static let backgroundColor: UIColor = {
        if #available(iOS 11.0, *) {
            return UIColor(named: "Background") ?? .hexToColor(hexString: "#F0F1F5")
        } else {
            return .hexToColor(hexString: "#F0F1F5")
        }
    }()
    
    static let secondaryBlue: UIColor = {
        if #available(iOS 11.0, *) {
            return UIColor(named: "Blue") ?? .hexToColor(hexString: "#19BEF4")
        } else {
            return .hexToColor(hexString: "#19BEF4")
        }
    }()
    
    static let textColor: UIColor = {
        if #available(iOS 11.0, *) {
            return UIColor(named: "Text") ?? .hexToColor(hexString: "#2F2F2F")
        } else {
            return .hexToColor(hexString: "#2F2F2F")
        }
    }()
    
    static func intFromHexString(hexStr: String) -> UInt32 {
        var hexInt: UInt32 = 0
        // Create scanner
        let scanner: Scanner = Scanner(string: hexStr)
        // Tell scanner to skip the # character
        scanner.charactersToBeSkipped = NSCharacterSet(charactersIn: "#") as CharacterSet
        // Scan hex value
        scanner.scanHexInt32(&hexInt)
        return hexInt
    }
    
    static func hexToColor(hexString: String, alpha: CGFloat? = 1.0) -> UIColor {
        // Convert hex string to an integer
        let hexint = Int(UIColor.intFromHexString(hexStr: hexString))
        let red = CGFloat((hexint & 0xff0000) >> 16) / 255.0
        let green = CGFloat((hexint & 0xff00) >> 8) / 255.0
        let blue = CGFloat((hexint & 0xff) >> 0) / 255.0
        let alpha = alpha!
        // Create color object, specifying alpha as well
        let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
        return color
    }
    
}
