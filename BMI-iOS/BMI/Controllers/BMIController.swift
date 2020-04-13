//
//  ViewController.swift
//  BMI
//
//  Created by Josiah Rininger on 6/6/19.
//  Copyright © 2019 Josiah Rininger. All rights reserved.
//

import UIKit
import GoogleMobileAds

class BMIController: UIViewController, UITextFieldDelegate, GADBannerViewDelegate {
    
    let bmiView = BMIView()
    let bmiViewModel = BMIViewModel()
    let weightPicker = UIPickerView()
    let heightPicker = UIPickerView()
    
    // MARK: - View Setup
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        bmiView.segmentedControl.addTarget(self, action: #selector(indexChanged(_:)), for: .valueChanged)
        bmiView.calculateButton.addTarget(self, action: #selector(calculateBMI), for: .touchUpInside)
        
        setupView()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return self.traitCollection.userInterfaceStyle == .dark ? .darkContent : .lightContent
        } else {
            return .lightContent
        }
    }
    
    func setupView() {
        initializeBanner()
        
        bmiView.weightTextField.delegate = self
        bmiView.heightTextField.delegate = self
        
        setupKeyboard()
        createPicker()
        createPickerToolBar()
        
        view = bmiView
    }
    
    func initializeBanner() {
        bmiView.bannerView.adUnitID = Constants.Strings.adUnitID
        bmiView.bannerView.rootViewController = self
        bmiView.bannerView.load(GADRequest())
        bmiView.bannerView.delegate = self
    }
    
    private func setupKeyboard() {
        let dismissKeyboardTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissKeyboardTapGestureRecognizer.cancelsTouchesInView = false
        bmiView.addGestureRecognizer(dismissKeyboardTapGestureRecognizer)
    }
    
    @objc fileprivate func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Helper Methods
    @objc func indexChanged(_ sender: UISegmentedControl) {
        viewWillAppear(true)
        super.viewDidLoad()
        
        switch sender.selectedSegmentIndex {
        case 0:
            bmiView.weightTextField.text = Constants.Strings.defaultPounds
            bmiView.poundsLabel.text = Constants.Strings.pounds
            bmiView.heightTextField.text = Constants.Strings.defaultFeetAndInches
            bmiView.feetAndInchesLabel.text = Constants.Strings.inches
            setupImperialPickerViews()
        case 1:
            bmiView.weightTextField.text = Constants.Strings.defaultKilograms
            bmiView.poundsLabel.text = Constants.Strings.kilograms
            bmiView.heightTextField.text = Constants.Strings.defaultCentimeters
            bmiView.feetAndInchesLabel.text = Constants.Strings.centimeters
            setupMetricPickerViews()
        default:
            break
        }
    }
    
    @objc func calculateBMI() {
        var bmi = String()
        if bmiView.segmentedControl.selectedSegmentIndex == 0 {
            bmi = bmiViewModel.calculateImperialBMI(with: bmiView.weightTextField.text,
                                                    and: bmiView.heightTextField.text)
        } else {
            bmi = bmiViewModel.calculateMetricBMI(with: bmiView.weightTextField.text,
            and: bmiView.heightTextField.text)
        }
        bmiView.calculationLabel.text = bmi
        bmiView.categoryLabel.text = bmiViewModel.categorizeBMI(with: Double(bmi) ?? 0.0)
    }
    
    // MARK: - UIPickerView Methods
    private func createPicker() {
        // Setup Weight Picker
        weightPicker.delegate = self
        weightPicker.dataSource = self
        weightPicker.selectRow(bmiView.weightInPounds.firstIndex(of: 215) ?? 0, inComponent: 0, animated: true)
        weightPicker.backgroundColor = .backgroundColor
        bmiView.weightTextField.inputView = weightPicker
        
        // Setup Height Picker
        heightPicker.delegate = self
        heightPicker.dataSource = self
        heightPicker.selectRow(bmiView.heightInFeetAndInches.firstIndex(of: Constants.Strings.defaultFeetAndInches) ?? 0, inComponent: 0, animated: true)
        heightPicker.backgroundColor = .backgroundColor
        bmiView.heightTextField.inputView = heightPicker
    }
    
    func setupImperialPickerViews() {
        weightPicker.selectRow(bmiView.weightInPounds.firstIndex(of: 215) ?? 0, inComponent: 0, animated: true)
        heightPicker.selectRow(bmiView.heightInFeetAndInches.firstIndex(of: Constants.Strings.defaultFeetAndInches) ?? 0, inComponent: 0, animated: true)
    }
    
    func setupMetricPickerViews() {
        weightPicker.selectRow(bmiView.weightInKg.firstIndex(of: 97.5) ?? 0, inComponent: 0, animated: true)
        heightPicker.selectRow(bmiView.heightInCm.firstIndex(of: 174.0) ?? 0, inComponent: 0, animated: true)
    }
    
    func createPickerToolBar() {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        let doneButton = UIBarButtonItem(title: Constants.Strings.done, style: .plain, target: self, action: #selector(dismissKeyboard))
        doneButton.tintColor = .secondaryBlue
        let flexibilitySpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([flexibilitySpace, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        bmiView.weightTextField.inputAccessoryView = toolBar
        bmiView.heightTextField.inputAccessoryView = toolBar
    }
    
}

extension BMIController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == weightPicker {
            return bmiView.segmentedControl.selectedSegmentIndex == 0 ? bmiView.weightInPounds.count : bmiView.weightInKg.count
        } else if pickerView == heightPicker {
        return bmiView.segmentedControl.selectedSegmentIndex == 0 ? bmiView.heightInFeetAndInches.count : bmiView.heightInCm.count
        }
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == weightPicker {
            return bmiView.segmentedControl.selectedSegmentIndex == 0 ? String(bmiView.weightInPounds[row]) : String(bmiView.weightInKg[row])
        } else if pickerView == heightPicker {
            return bmiView.segmentedControl.selectedSegmentIndex == 0 ? bmiView.heightInFeetAndInches[row] : String(bmiView.heightInCm[row])
        }
        return "0"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == weightPicker {
            bmiView.weightTextField.text =
                bmiView.segmentedControl.selectedSegmentIndex == 0 ? String(bmiView.weightInPounds[row]) : String(bmiView.weightInKg[row])
        } else {
            bmiView.heightTextField.text = bmiView.segmentedControl.selectedSegmentIndex == 0 ? bmiView.heightInFeetAndInches[row] : String(bmiView.heightInCm[row])
        }
    }
}
