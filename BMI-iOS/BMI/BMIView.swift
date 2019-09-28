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
    
    var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondaryBlue
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    var bmiLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .backgroundColor
        label.text = "BMI"
        label.font = UIFont(name: "AvenirNext-Regular", size: 35)
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var calculationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .backgroundColor
        label.text = "0.0"
        label.font = UIFont(name: "AvenirNext-Regular", size: 126)
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var categoryLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .backgroundColor
        label.text = "Input Data for Calculation"
        label.font = UIFont(name: "AvenirNext-Regular", size: 30)
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var segmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: ["Imperial", "Metric"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.layer.cornerRadius = 5.0
        segmentedControl.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "AvenirNext-Regular", size: 25) as Any], for: .normal)
        segmentedControl.backgroundColor = .backgroundColor
        segmentedControl.tintColor = .secondaryBlue
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        return segmentedControl
    }()
    
    var weightLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .textColor
        label.text = "Weight:"
        label.font = UIFont(name: "AvenirNext-Regular", size: 45)
        label.textAlignment = .right
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var weightTextField: UITextField = {
        let textField = UITextField()
        textField.text = "215"
        textField.selectedTextRange = nil
        textField.tintColor = .clear
        textField.backgroundColor = .backgroundColor
        textField.layer.borderColor = UIColor.textColor.cgColor
        textField.layer.borderWidth = 1
        textField.layer.cornerRadius = 5
        textField.borderStyle = .line
        textField.contentVerticalAlignment = .center
        textField.textAlignment = .center
        textField.textColor = .textColor
        textField.font = UIFont(name: "AvenirNext-Regular", size: 30)
        textField.returnKeyType = .done
        textField.borderStyle = .none
        textField.layer.masksToBounds = false
        textField.adjustsFontSizeToFitWidth = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        return textField
    }()
    
    var poundsLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .textColor
        label.text = "lbs"
        label.font = UIFont(name: "AvenirNext-Regular", size: 45)
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var heightLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .textColor
        label.text = "Height:"
        label.font = UIFont(name: "AvenirNext-Regular", size: 45)
        label.textAlignment = .right
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var heightTextField: UITextField = {
        let textField = UITextField()
        textField.text = "5'9\""
        textField.selectedTextRange = nil
        textField.tintColor = .clear
        textField.backgroundColor = .backgroundColor
        textField.layer.borderColor = UIColor.textColor.cgColor
        textField.layer.borderWidth = 1
        textField.layer.cornerRadius = 5
        textField.borderStyle = .line
        textField.contentVerticalAlignment = .center
        textField.textAlignment = .center
        textField.textColor = .textColor
        textField.font = UIFont(name: "AvenirNext-Regular", size: 30)
        textField.returnKeyType = .done
        textField.borderStyle = .none
        textField.layer.masksToBounds = false
        textField.adjustsFontSizeToFitWidth = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        return textField
    }()
    
    var feetAndInchesLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .textColor
        label.text = "in"
        label.font = UIFont(name: "AvenirNext-Regular", size: 45)
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var calculateButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .secondaryBlue
        button.layer.cornerRadius = 7
        button.titleLabel?.numberOfLines = 0
        button.contentVerticalAlignment = .center
        button.setTitle("Calculate", for: .normal)
        button.setTitleColor(.backgroundColor, for: .normal)
        button.titleLabel!.font = UIFont(name: "AvenirNext-Regular", size: 45)
        button.titleLabel!.adjustsFontSizeToFitWidth = true
        button.titleLabel!.textAlignment = .center
        button.layer.shadowRadius = 3
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowOpacity = 0.2
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }()
    
    var categoryView: UIView = {
        let view = UIView()
        view.backgroundColor = .backgroundColor
        view.layer.borderColor = UIColor.textColor.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    var bmiCategoriesLabel: UILabel = {
        let label = UILabel()
        label.textColor = .textColor
        label.text = "BMI Categories:"
        label.font = UIFont(name: "AvenirNext-Demibold", size: 35)
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var categoryListLabel: UILabel = {
        let label = UILabel()
        label.textColor = .textColor
        label.text = "Underweight = <18.5\nNormal weight = 18.5–24.9\nOverweight = 25–29.9\nObese = >30.0"
        label.font = UIFont(name: "AvenirNext-Regular", size: 35)
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var disclaimerLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .textColor
        label.text = "Disclaimer: does not account for muscle mass"
        label.font = UIFont(name: "AvenirNext-Regular", size: 16)
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    var bannerView: GADBannerView = {
        let bannerView = GADBannerView(adSize: kGADAdSizeBanner)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        return bannerView
    }()
    
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
        headerView.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 4),
        
        calculationLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
        calculationLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: UIElementSizes.windowHeight / 64),
        calculationLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 10),
        calculationLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 4),
        
        bmiLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
        bmiLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 20),
        bmiLabel.bottomAnchor.constraint(equalTo: calculationLabel.topAnchor),
        
        categoryLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
        categoryLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 20),
        categoryLabel.topAnchor.constraint(equalTo: calculationLabel.bottomAnchor),
        
        segmentedControl.centerXAnchor.constraint(equalTo: centerXAnchor),
        segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
        segmentedControl.widthAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlWidth),
        segmentedControl.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight),
        
        weightLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 2.5),
        weightLabel.trailingAnchor.constraint(equalTo: centerXAnchor),
        weightLabel.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
        weightLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight * 1.5),
        
        weightTextField.leadingAnchor.constraint(equalTo: centerXAnchor),
        weightTextField.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight),
        weightTextField.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 5),
        weightTextField.centerYAnchor.constraint(equalTo: weightLabel.centerYAnchor),
        
        poundsLabel.leadingAnchor.constraint(equalTo: weightTextField.trailingAnchor, constant: 4),
        poundsLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 8.8),
        poundsLabel.centerYAnchor.constraint(equalTo: weightTextField.centerYAnchor),
        poundsLabel.heightAnchor.constraint(equalTo: weightLabel.heightAnchor),
        
        heightLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 2.5),
        heightLabel.trailingAnchor.constraint(equalTo: centerXAnchor),
        heightLabel.topAnchor.constraint(equalTo: weightLabel.bottomAnchor, constant: 10),
        heightLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight * 1.5),
        
        heightTextField.leadingAnchor.constraint(equalTo: centerXAnchor),
        heightTextField.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight),
        heightTextField.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 5),
        heightTextField.centerYAnchor.constraint(equalTo: heightLabel.centerYAnchor),
        
        feetAndInchesLabel.leadingAnchor.constraint(equalTo: heightTextField.trailingAnchor, constant: 4),
        feetAndInchesLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 8.8),
        feetAndInchesLabel.heightAnchor.constraint(equalTo: heightLabel.heightAnchor),
        feetAndInchesLabel.centerYAnchor.constraint(equalTo: heightTextField.centerYAnchor),
        
        calculateButton.widthAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlWidth),
        calculateButton.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight * 1.5),
        calculateButton.centerXAnchor.constraint(equalTo: centerXAnchor),
        calculateButton.topAnchor.constraint(equalTo: heightLabel.bottomAnchor, constant: 20),
        
        categoryView.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth),
        categoryView.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 4.2),
        categoryView.centerXAnchor.constraint(equalTo: centerXAnchor),
        categoryView.topAnchor.constraint(equalTo: calculateButton.bottomAnchor, constant: 20),
        
        categoryListLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UIElementSizes.windowWidth / 13),
        categoryListLabel.centerYAnchor.constraint(equalTo: categoryView.centerYAnchor),
        categoryListLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth - UIElementSizes.windowWidth / 13),
        categoryListLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 6),
        
        bmiCategoriesLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UIElementSizes.windowWidth / 20),
        bmiCategoriesLabel.topAnchor.constraint(equalTo: categoryView.topAnchor, constant: 4),
        bmiCategoriesLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 2),
        bmiCategoriesLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 26),
        
        disclaimerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        disclaimerLabel.bottomAnchor.constraint(equalTo: categoryView.bottomAnchor, constant: -4),
        disclaimerLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlWidth),
        disclaimerLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 30),
        
        bannerView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
        bannerView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        
        calculateButton.titleLabel?.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 3).isActive = true
    }
}
