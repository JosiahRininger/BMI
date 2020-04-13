//
//  UIElementSizes.swift
//  BMI
//
//  Created by Josiah Rininger on 6/6/19.
//  Copyright © 2019 Josiah Rininger. All rights reserved.
//

import UIKit
import GoogleMobileAds

struct UIElementsManager {
    static var windowWidth: CGFloat = UIScreen.main.bounds.width
    static var windowHeight: CGFloat = UIScreen.main.bounds.height

    static var buttonAndSegmentedControlWidth: CGFloat = UIScreen.main.bounds.width / 1.5
    static var buttonAndSegmentedControlHeight: CGFloat = UIScreen.main.bounds.height / 22
    
    static public func createHeaderView() -> UIView {
        let view = UIView()
        view.backgroundColor = .secondaryBlue
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }
    
    static public func createCategoryView() -> UIView {
        let view = UIView()
        view.backgroundColor = .backgroundColor
        view.layer.borderColor = UIColor.textColor.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }
    
    static public func createLabel(textColor: UIColor = .textColor, text: String, fontName: String = Constants.Strings.avenirNextRegular, fontSize: CGFloat, textAlignment: NSTextAlignment = .center) -> UILabel {
        let label = UILabel()
        label.textColor = textColor
        label.text = text
        label.font = UIFont(name: fontName, size: fontSize)
        label.textAlignment = textAlignment
        label.numberOfLines = 0
        label.layer.masksToBounds = false
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }
    
    static public func createTextField(text: String) -> UITextField {
        let textField = UITextField()
        textField.text = text
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
        textField.font = UIFont(name: Constants.Strings.avenirNextRegular, size: 30)
        textField.returnKeyType = .done
        textField.borderStyle = .none
        textField.layer.masksToBounds = false
        textField.adjustsFontSizeToFitWidth = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        return textField
    }
    
    static public func createSegmentedControl() -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: [Constants.Strings.imperial, Constants.Strings.metric])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.layer.cornerRadius = 5.0
        segmentedControl.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: Constants.Strings.avenirNextRegular, size: 25) as Any], for: .normal)
        segmentedControl.backgroundColor = .backgroundColor
        segmentedControl.tintColor = .secondaryBlue
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        return segmentedControl
    }
    
    static public func createButton() -> UIButton {
        let button = UIButton()
        button.backgroundColor = .secondaryBlue
        button.layer.cornerRadius = 7
        button.titleLabel?.numberOfLines = 0
        button.contentVerticalAlignment = .center
        button.setTitle(Constants.Strings.calculate, for: .normal)
        button.setTitleColor(.backgroundColor, for: .normal)
        button.titleLabel!.font = UIFont(name: Constants.Strings.avenirNextRegular, size: 45)
        button.titleLabel!.adjustsFontSizeToFitWidth = true
        button.titleLabel!.textAlignment = .center
        button.layer.shadowRadius = 3
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowOpacity = 0.2
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }
    
    static public func createBannerView() -> GADBannerView {
        let bannerView = GADBannerView(adSize: kGADAdSizeBanner)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        return bannerView
    }
}
