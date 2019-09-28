//
//  UIView.swift
//  BMI
//
//  Created by Josiah Rininger on 9/28/19.
//  Copyright © 2019 Josiah Rininger. All rights reserved.
//

import UIKit

extension UIView {
    func addSubviews(_ views: UIView...) {
        for view in views {
            self.addSubview(view)
        }
    }
}
