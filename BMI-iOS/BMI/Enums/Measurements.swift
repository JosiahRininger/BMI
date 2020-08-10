//
//  Measurements.swift
//  BMI
//
//  Created by Josiah Rininger on 8/6/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import Foundation

enum Measurements {
    case weight, height

    var title: String {
        switch self {
        case .weight: return "Weight"
        case .height: return "Height"
        }
    }
    
    static func calculateBMI(weight: Double, height: Int) -> (String, String) {
        return ("0.0", "0.0")
    }

}
