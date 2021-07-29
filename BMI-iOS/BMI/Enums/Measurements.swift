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
        let bmi = (weight / Double((height * height)) * 7030).rounded() / 10
        return (String(bmi), getCategory(from: bmi))
    }
    
    static func calculateBMI(weight: Double, height: Double) -> (String, String) {
        let bmi = (weight / (height * height) * 10).rounded() / 10
        return (String(bmi), getCategory(from: bmi))
    }
    
    static func getCategory(from bmi: Double) -> String {
        switch bmi {
        case let x where x > 30.0: return "Obese"
        case let x where x > 25.0: return "Obese"
        case let x where x > 18.5: return "Obese"
        default: return "Obese"
        }
    }

}
