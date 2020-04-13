//
//  Strings.swift
//  BMI
//
//  Created by Josiah Rininger on 4/12/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import Foundation

extension Constants {
    /// Strings used throughout application
    struct Strings {
        
        // Imperial/Metric Measurements
        static let pounds = "lbs"
        static let inches = "in"
        static let kilograms = "kg"
        static let centimeters = "cm"
        static let defaultPounds = "215"
        static let defaultFeetAndInches = "5'9\""
        static let defaultKilograms = "97.5"
        static let defaultCentimeters = "174.0"
        static let emptyCalculation = "0.0"
        
        // Category Labels
        static let underweight = "Underweight"
        static let normalWeight = "Normal Weight"
        static let overweight = "Overweight"
        static let obese = "Obese"
        
        // UI Element Labels
        static let bmi = "BMI"
        static let inputData = "Input Data for Calculation"
        static let weightTitle = "Weight:"
        static let heightTitle = "Height:"
        static let bmiCalculatorTitle = "BMI Categories:"
        static let categoryList = "Underweight = <18.5\nNormal weight = 18.5–24.9\nOverweight = 25–29.9\nObese = >30.0"
        static let disclaimer = "Disclaimer: does not account for muscle mass"
        static let metric = "Metric"
        static let imperial = "Imperial"
        static let calculate = "Calculate"
        static let done = "Done"
        
        // Font Names
        static let avenirNextDemibold = "AvenirNext-Demibold"
        static let avenirNextRegular = "AvenirNext-Regular"
        
        // Ad Unit IDs for Test Ads and Prodution Ads
        #if DEBUG
        static let adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        static let adUnitID = "ca-app-pub-6687613409331343/5598406572"
        #endif
    }
}
