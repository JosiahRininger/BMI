//
//  BMIViewModel.swift
//  BMI
//
//  Created by Josiah Rininger on 4/12/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import Foundation

class BMIViewModel {
    
    public func calculateImperialBMI(with lbsString: String?, and insString: String?) -> String {
        var imperialHeight = insString ?? "0"
        let pounds: Int = Int(lbsString ?? "0") ?? 0
        var inches: Int = (Int(String(imperialHeight.first ?? "0")) ?? 0) * 12
        if imperialHeight.last == "\"" {
            imperialHeight.removeFirst()
            imperialHeight.removeFirst()
            imperialHeight.removeLast()
            inches += Int(imperialHeight) ?? 0
        }
        
        if pounds == 0 || inches == 0 {
            return Constants.Strings.emptyCalculation
        }
        
        return String(Double(Int(10.0 * (703.0 * Double(pounds) / Double(inches * inches)))) / 10.0)
    }
    
    public func calculateMetricBMI(with kgsString: String?, and cmsString: String?) -> String {
        let kilograms: Double = Double(kgsString ?? "0.0") ?? 0.0
        let centimeters: Double = (Double(cmsString ?? "0.0") ?? 0.0) / 100.0
        
        if kilograms == 0.0 || centimeters == 0.0 {
            return Constants.Strings.emptyCalculation
        }
        
        return String(Double(Int(10.0 * Double(kilograms) / Double(centimeters * centimeters))) / 10.0)
    }
    
    public func categorizeBMI(with bmi: Double) -> String {
        switch bmi {
        case 0.0...18.5:
            return Constants.Strings.underweight
        case 18.5...24.9:
            return Constants.Strings.normalWeight
        case 25.0...29.9:
            return Constants.Strings.overweight
        default:
            return Constants.Strings.obese
        }
    }
}
