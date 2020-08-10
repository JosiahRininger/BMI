//
//  Color+gradient.swift
//  BMI
//
//  Created by Josiah Rininger on 8/8/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import UIKit

extension UIColor {
    static func gradient(frame: CGRect, colors: [UIColor]) -> UIColor {
        
        // create the background layer that will hold the gradient
        let backgroundGradientLayer = CAGradientLayer()
        backgroundGradientLayer.frame = frame
         
        // we create an array of CG colors from out UIColor array
        let cgColors = colors.map({$0.cgColor})
        
        backgroundGradientLayer.colors = cgColors
        
        UIGraphicsBeginImageContext(backgroundGradientLayer.bounds.size)
        if let context = UIGraphicsGetCurrentContext() {
            backgroundGradientLayer.render(in: context)
            if let backgroundColorImage = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                return UIColor(patternImage: backgroundColorImage)
            }
        }
        return UIColor()
    }
}
