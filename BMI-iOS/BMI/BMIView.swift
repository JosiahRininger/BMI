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
        view.backgroundColor = .headerAndSegmentedControlBlue
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    var bmiLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .backgroundWhite
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
        label.textColor = .backgroundWhite
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
        label.textColor = .backgroundWhite
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
        segmentedControl.backgroundColor = .backgroundWhite
        segmentedControl.tintColor = .headerAndSegmentedControlBlue
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        return segmentedControl
    }()
    
    var weightLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .textBlack
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
        textField.backgroundColor = .backgroundWhite
        textField.layer.borderColor = UIColor.textBlack.cgColor
        textField.layer.borderWidth = 1
        textField.layer.cornerRadius = 5
        textField.borderStyle = .line
        textField.contentVerticalAlignment = .center
        textField.textAlignment = .center
        textField.textColor = .textBlack
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
        label.textColor = .textBlack
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
        label.textColor = .textBlack
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
        textField.backgroundColor = .backgroundWhite
        textField.layer.borderColor = UIColor.textBlack.cgColor
        textField.layer.borderWidth = 1
        textField.layer.cornerRadius = 5
        textField.borderStyle = .line
        textField.contentVerticalAlignment = .center
        textField.textAlignment = .center
        textField.textColor = .textBlack
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
        label.textColor = .textBlack
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
        button.backgroundColor = .headerAndSegmentedControlBlue
        button.layer.cornerRadius = 5
        button.titleLabel?.numberOfLines = 0
        button.contentVerticalAlignment = .center
        button.setTitle("Calculate", for: .normal)
        button.titleLabel?.textColor = .backgroundWhite
        button.titleLabel!.font = UIFont(name: "AvenirNext-Regular", size: 45)
        button.titleLabel!.adjustsFontSizeToFitWidth = true
        button.titleLabel!.textAlignment = .center
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()
    
    var categoryView: UIView = {
        let view = UIView()
        view.backgroundColor = .backgroundWhite
        view.layer.borderColor = UIColor.textBlack.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    var bmiCategoriesLabel: UILabel = {
        let label = UILabel()
        label.textColor = .textBlack
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
            label.textColor = .textBlack
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
        label.textColor = .textBlack
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
        backgroundColor = .backgroundWhite
        
        
        addSubview(headerView)
        headerView.addSubview(bmiLabel)
        headerView.addSubview(calculationLabel)
        headerView.addSubview(categoryLabel)
        addSubview(segmentedControl)
        addSubview(weightLabel)
        addSubview(weightTextField)
        addSubview(poundsLabel)
        addSubview(heightLabel)
        addSubview(heightTextField)
        addSubview(feetAndInchesLabel)
        addSubview(calculateButton)
        addSubview(categoryView)
        categoryView.addSubview(bmiCategoriesLabel)
        categoryView.addSubview(categoryListLabel)
        categoryView.addSubview(disclaimerLabel)
        addSubview(bannerView)

        setupConstraints()
    }
    
    fileprivate func setupConstraints() {
        headerView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        headerView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        headerView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        headerView.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 4).isActive = true

        calculationLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor).isActive = true
        calculationLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: UIElementSizes.windowHeight / 64).isActive = true
        calculationLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 10).isActive = true
        calculationLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 4).isActive = true
        
        bmiLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor).isActive = true
        bmiLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 20).isActive = true
        bmiLabel.bottomAnchor.constraint(equalTo: calculationLabel.topAnchor).isActive = true
        
        categoryLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor).isActive = true
        categoryLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 20).isActive = true
        categoryLabel.topAnchor.constraint(equalTo: calculationLabel.bottomAnchor).isActive = true
        
        segmentedControl.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10).isActive = true
        segmentedControl.widthAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlWidth).isActive = true
        segmentedControl.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight).isActive = true

        weightLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 2.5).isActive = true
        weightLabel.trailingAnchor.constraint(equalTo: centerXAnchor).isActive = true
        weightLabel.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10).isActive = true
        weightLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight * 1.5).isActive = true
        
        weightTextField.leadingAnchor.constraint(equalTo: centerXAnchor).isActive = true
        weightTextField.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight).isActive = true
        weightTextField.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 5).isActive = true
        weightTextField.centerYAnchor.constraint(equalTo: weightLabel.centerYAnchor).isActive = true
        
        poundsLabel.leadingAnchor.constraint(equalTo: weightTextField.trailingAnchor, constant: 4).isActive = true
        poundsLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 8.8).isActive = true
        poundsLabel.centerYAnchor.constraint(equalTo: weightTextField.centerYAnchor).isActive = true
        poundsLabel.heightAnchor.constraint(equalTo: weightLabel.heightAnchor).isActive = true
        
        heightLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 2.5).isActive = true
        heightLabel.trailingAnchor.constraint(equalTo: centerXAnchor).isActive = true
        heightLabel.topAnchor.constraint(equalTo: weightLabel.bottomAnchor, constant: 10).isActive = true
        heightLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight * 1.5).isActive = true
        
        heightTextField.leadingAnchor.constraint(equalTo: centerXAnchor).isActive = true
        heightTextField.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight).isActive = true
        heightTextField.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 5).isActive = true
        heightTextField.centerYAnchor.constraint(equalTo: heightLabel.centerYAnchor).isActive = true
        
        feetAndInchesLabel.leadingAnchor.constraint(equalTo: heightTextField.trailingAnchor, constant: 4).isActive = true
        feetAndInchesLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 8.8).isActive = true
        feetAndInchesLabel.heightAnchor.constraint(equalTo: heightLabel.heightAnchor).isActive = true
        feetAndInchesLabel.centerYAnchor.constraint(equalTo: heightTextField.centerYAnchor).isActive = true
        
        calculateButton.widthAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlWidth).isActive = true
        calculateButton.heightAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlHeight * 1.5).isActive = true
        calculateButton.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        calculateButton.topAnchor.constraint(equalTo: heightLabel.bottomAnchor, constant: 20).isActive = true
        calculateButton.titleLabel?.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 3).isActive = true
        
        categoryView.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth).isActive = true
        categoryView.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 4.2).isActive = true
        categoryView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        categoryView.topAnchor.constraint(equalTo: calculateButton.bottomAnchor, constant: 20).isActive = true
        
        categoryListLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UIElementSizes.windowWidth / 13).isActive = true
        categoryListLabel.centerYAnchor.constraint(equalTo: categoryView.centerYAnchor).isActive = true
        categoryListLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth - UIElementSizes.windowWidth / 13).isActive = true
        categoryListLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 6).isActive = true
        
        bmiCategoriesLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UIElementSizes.windowWidth / 20).isActive = true
        bmiCategoriesLabel.topAnchor.constraint(equalTo: categoryView.topAnchor, constant: 4).isActive = true
        bmiCategoriesLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.windowWidth / 2).isActive = true
        bmiCategoriesLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 26).isActive = true
        
        disclaimerLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        disclaimerLabel.bottomAnchor.constraint(equalTo: categoryView.bottomAnchor, constant: -4).isActive = true
        disclaimerLabel.widthAnchor.constraint(equalToConstant: UIElementSizes.buttonAndSegmentedControlWidth).isActive = true
        disclaimerLabel.heightAnchor.constraint(equalToConstant: UIElementSizes.windowHeight / 30).isActive = true
        
        bannerView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor).isActive = true
        bannerView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        
        }
}
