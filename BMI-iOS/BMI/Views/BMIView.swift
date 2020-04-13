//
//  BMIView.swift
//  BMI
//
//  Created by Josiah Rininger on 6/6/19.
//  Copyright © 2019 Josiah Rininger. All rights reserved.
//

import UIKit
import GoogleMobileAds

class BMIView: UIView {
    
    let heightInFeetAndInches: [String] = ["4'5\"","4'6\"","4'7\"","4'8\"","4'9\"","4'10\"","4'11\"","5'","5'1\"","5'2\"","5'3\"","5'4\"","5'5\"","5'6\"","5'7\"","5'8\"","5'9\"","5'10\"","5'11\"","6'","6'1\"","6'2\"","6'3\"","6'4\"","6'5\"","6'6\"","6'7\"","6'8\"","6'9\"","6'10\"","6'11\"","7'"]
    let heightInCm: [Double] = {
        var arr = Array(stride(from: 134.0, through: 214.0, by: 0.1))
        for i in 0 ..< arr.count {
            arr[i] = Double(round(10*arr[i])/10)
        }
        
        return arr
    }()
    let weightInPounds: [Int] = {
        var arr = [Int]()
        arr += 80...350
        
        return arr
    }()
    let weightInKg: [Double] = {
        var arr = Array(stride(from: 35.0, through: 160.0, by: 0.1))
        for i in 0 ..< arr.count {
            arr[i] = Double(round(10*arr[i])/10)
        }
        
        return arr
    }()
    
    var headerView: UIView = UIElementsManager.createHeaderView()
    
    var bmiLabel: UILabel = UIElementsManager.createLabel(textColor: .backgroundColor, text: Constants.Strings.bmi, fontSize: 35)
    var calculationLabel: UILabel = UIElementsManager.createLabel(textColor: .backgroundColor, text: Constants.Strings.emptyCalculation, fontSize: 126)
    var categoryLabel: UILabel = UIElementsManager.createLabel(textColor: .backgroundColor, text: Constants.Strings.inputData, fontSize: 30)
    
    var segmentedControl: UISegmentedControl = UIElementsManager.createSegmentedControl()
    
    var weightLabel: UILabel = UIElementsManager.createLabel(text: Constants.Strings.weightTitle, fontSize: 45, textAlignment: .right)
    var weightTextField: UITextField = UIElementsManager.createTextField(text: Constants.Strings.defaultPounds)
    var poundsLabel: UILabel = UIElementsManager.createLabel(text: Constants.Strings.pounds, fontSize: 45)
    
    var heightLabel: UILabel = UIElementsManager.createLabel(text: Constants.Strings.heightTitle, fontSize: 45, textAlignment: .right)
    var heightTextField: UITextField = UIElementsManager.createTextField(text: Constants.Strings.defaultFeetAndInches)
    var feetAndInchesLabel: UILabel = UIElementsManager.createLabel(text: Constants.Strings.inches, fontSize: 45)
    
    var calculateButton: UIButton = UIElementsManager.createButton()
    var categoryView: UIView = UIElementsManager.createCategoryView()
    
    var bmiCategoriesLabel: UILabel = UIElementsManager.createLabel(text: Constants.Strings.bmiCalculatorTitle, fontName: Constants.Strings.avenirNextDemibold, fontSize: 35, textAlignment: .left)
    var categoryListLabel: UILabel = UIElementsManager.createLabel(text: Constants.Strings.categoryList, fontSize: 35, textAlignment: .left)
    var disclaimerLabel: UILabel = UIElementsManager.createLabel(text: Constants.Strings.disclaimer, fontSize: 16)
    
    var bannerView: GADBannerView = UIElementsManager.createBannerView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
        
    fileprivate func setupView() {
        frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backgroundColor = .backgroundColor
        
        addSubview(headerView)
        headerView.addSubviews(bmiLabel, calculationLabel, categoryLabel)
        addSubviews(segmentedControl,
                    weightLabel,
                    weightTextField,
                    poundsLabel,
                    heightLabel,
                    heightTextField,
                    feetAndInchesLabel,
                    calculateButton,
                    categoryView,
                    bannerView)
        categoryView.addSubviews(bmiCategoriesLabel, categoryListLabel, disclaimerLabel)
        
        setupConstraints()
    }
    
    fileprivate func setupConstraints() {
        NSLayoutConstraint.activate([
        headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
        headerView.topAnchor.constraint(equalTo: topAnchor),
        headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        headerView.heightAnchor.constraint(equalToConstant: UIElementsManager.windowHeight / 4),
        
        calculationLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
        calculationLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: UIElementsManager.windowHeight / 64),
        calculationLabel.heightAnchor.constraint(equalToConstant: UIElementsManager.windowHeight / 10),
        calculationLabel.widthAnchor.constraint(equalToConstant: UIElementsManager.windowHeight / 4),
        
        bmiLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
        bmiLabel.heightAnchor.constraint(equalToConstant: UIElementsManager.windowHeight / 20),
        bmiLabel.bottomAnchor.constraint(equalTo: calculationLabel.topAnchor),
        
        categoryLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
        categoryLabel.heightAnchor.constraint(equalToConstant: UIElementsManager.windowHeight / 20),
        categoryLabel.topAnchor.constraint(equalTo: calculationLabel.bottomAnchor),
        
        segmentedControl.centerXAnchor.constraint(equalTo: centerXAnchor),
        segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
        segmentedControl.widthAnchor.constraint(equalToConstant: UIElementsManager.buttonAndSegmentedControlWidth),
        segmentedControl.heightAnchor.constraint(equalToConstant: UIElementsManager.buttonAndSegmentedControlHeight),
        
        weightLabel.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth / 2.5),
        weightLabel.trailingAnchor.constraint(equalTo: centerXAnchor),
        weightLabel.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
        weightLabel.heightAnchor.constraint(equalToConstant: UIElementsManager.buttonAndSegmentedControlHeight * 1.5),
        
        weightTextField.leadingAnchor.constraint(equalTo: centerXAnchor),
        weightTextField.heightAnchor.constraint(equalToConstant: UIElementsManager.buttonAndSegmentedControlHeight),
        weightTextField.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth / 5),
        weightTextField.centerYAnchor.constraint(equalTo: weightLabel.centerYAnchor),
        
        poundsLabel.leadingAnchor.constraint(equalTo: weightTextField.trailingAnchor, constant: 4),
        poundsLabel.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth / 8.8),
        poundsLabel.centerYAnchor.constraint(equalTo: weightTextField.centerYAnchor),
        poundsLabel.heightAnchor.constraint(equalTo: weightLabel.heightAnchor),
        
        heightLabel.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth / 2.5),
        heightLabel.trailingAnchor.constraint(equalTo: centerXAnchor),
        heightLabel.topAnchor.constraint(equalTo: weightLabel.bottomAnchor, constant: 10),
        heightLabel.heightAnchor.constraint(equalToConstant: UIElementsManager.buttonAndSegmentedControlHeight * 1.5),
        
        heightTextField.leadingAnchor.constraint(equalTo: centerXAnchor),
        heightTextField.heightAnchor.constraint(equalToConstant: UIElementsManager.buttonAndSegmentedControlHeight),
        heightTextField.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth / 5),
        heightTextField.centerYAnchor.constraint(equalTo: heightLabel.centerYAnchor),
        
        feetAndInchesLabel.leadingAnchor.constraint(equalTo: heightTextField.trailingAnchor, constant: 4),
        feetAndInchesLabel.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth / 8.8),
        feetAndInchesLabel.heightAnchor.constraint(equalTo: heightLabel.heightAnchor),
        feetAndInchesLabel.centerYAnchor.constraint(equalTo: heightTextField.centerYAnchor),
        
        calculateButton.widthAnchor.constraint(equalToConstant: UIElementsManager.buttonAndSegmentedControlWidth),
        calculateButton.heightAnchor.constraint(equalToConstant: UIElementsManager.buttonAndSegmentedControlHeight * 1.5),
        calculateButton.centerXAnchor.constraint(equalTo: centerXAnchor),
        calculateButton.topAnchor.constraint(equalTo: heightLabel.bottomAnchor, constant: 20),
        
        categoryView.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth),
        categoryView.heightAnchor.constraint(equalToConstant: UIElementsManager.windowHeight / 4.2),
        categoryView.centerXAnchor.constraint(equalTo: centerXAnchor),
        categoryView.topAnchor.constraint(equalTo: calculateButton.bottomAnchor, constant: 20),
        
        categoryListLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UIElementsManager.windowWidth / 13),
        categoryListLabel.centerYAnchor.constraint(equalTo: categoryView.centerYAnchor),
        categoryListLabel.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth - UIElementsManager.windowWidth / 13),
        categoryListLabel.heightAnchor.constraint(equalToConstant: UIElementsManager.windowHeight / 6),
        
        bmiCategoriesLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UIElementsManager.windowWidth / 20),
        bmiCategoriesLabel.topAnchor.constraint(equalTo: categoryView.topAnchor, constant: 4),
        bmiCategoriesLabel.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth / 2),
        bmiCategoriesLabel.heightAnchor.constraint(equalToConstant: UIElementsManager.windowHeight / 26),
        
        disclaimerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        disclaimerLabel.bottomAnchor.constraint(equalTo: categoryView.bottomAnchor, constant: -4),
        disclaimerLabel.widthAnchor.constraint(equalToConstant: UIElementsManager.buttonAndSegmentedControlWidth),
        disclaimerLabel.heightAnchor.constraint(equalToConstant: UIElementsManager.windowHeight / 30),
        
        bannerView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
        bannerView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        
        calculateButton.titleLabel?.widthAnchor.constraint(equalToConstant: UIElementsManager.windowWidth / 3).isActive = true
    }
}
