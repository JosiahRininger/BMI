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
    let weightPicker = UIPickerView()
    let heightPicker = UIPickerView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bmiView.segmentedControl.addTarget(self, action: #selector(indexChanged(_:)), for: .valueChanged)
        bmiView.calculateButton.addTarget(self, action: #selector(calculateBMI), for: .touchUpInside)
        
        setupView()
        initializeBanner()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        bmiView.segmentedControl.addTarget(self, action: #selector(indexChanged(_:)), for: .valueChanged)
        bmiView.calculateButton.addTarget(self, action: #selector(calculateBMI), for: .touchUpInside)
        
        setupView()
        initializeBanner()
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return self.traitCollection.userInterfaceStyle == .dark ? .darkContent : .lightContent
        } else {
            return .lightContent
        }
    }
    
    func setupView() {
        bmiView.weightTextField.delegate = self
        bmiView.heightTextField.delegate = self
        
        let dismissKeyboardTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissKeyboardTapGestureRecognizer.cancelsTouchesInView = false
        bmiView.addGestureRecognizer(dismissKeyboardTapGestureRecognizer)
        
        createPicker()
        createPickerToolBar()
        
        view = bmiView
    }
    
    @objc fileprivate func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func initializeBanner() {
        print("Google Mobile Ads SDK version: \(GADRequest.sdkVersion())")
#if DEBUG
        bmiView.bannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716"
#else
        bmiView.bannerView.adUnitID = "ca-app-pub-6687613409331343/5598406572"
#endif
        bmiView.bannerView.rootViewController = self
        bmiView.bannerView.load(GADRequest())
        bmiView.bannerView.delegate = self
    }
    
    @objc func indexChanged(_ sender: UISegmentedControl) {
        viewWillAppear(true)
        super.viewDidLoad()
        
        switch sender.selectedSegmentIndex {
        case 0:
            bmiView.weightTextField.text = "215"
            bmiView.poundsLabel.text = "lbs"
            bmiView.heightTextField.text = "5'9\""
            bmiView.feetAndInchesLabel.text = "in"
            setupImperialPickerViews()
        case 1:
            bmiView.weightTextField.text = "97.5"
            bmiView.poundsLabel.text = "kg"
            bmiView.heightTextField.text = "174.0"
            bmiView.feetAndInchesLabel.text = "cm"
            setupMetricPickerViews()
        default:
            break
        }
    }
    
    @objc func calculateBMI() {
        if bmiView.segmentedControl.selectedSegmentIndex == 0 {
            let lString: String = bmiView.weightTextField.text ?? "0"
            var iString: String = bmiView.heightTextField.text ?? "0"
            let lbs: Int = Int(lString) ?? 0
            var ins: Int = (Int(String(iString.first ?? "0")) ?? 0) * 12
            if iString.last == "\"" {
                iString.removeFirst()
                iString.removeFirst()
                iString.removeLast()
                ins += Int(iString) ?? 0
            }
            bmiView.calculationLabel.text = (lbs == 0 || ins == 0) ? String("0.0") : String(Double(Int(10.0 * (703.0 * Double(lbs) / Double(ins * ins)))) / 10.0)
        } else {
            let kString: String = bmiView.weightTextField.text ?? "0.0"
            let cString: String = bmiView.heightTextField.text ?? "0.0"
            let kg: Double = Double(kString) ?? 0.0
            let m: Double = (Double(cString) ?? 0.0) / 100.0
            bmiView.calculationLabel.text = (kg == 0.0 || m == 0.0) ? String("0.0") : String(Double(Int(10.0 * Double(kg) / Double(m * m))) / 10.0)
        }
        let bmi: Double = Double(bmiView.calculationLabel.text ?? "0.0") ?? 0.0
        switch bmi {
        case 0.0...18.5:
            bmiView.categoryLabel.text = "Underweight"
        case 18.5...24.9:
            bmiView.categoryLabel.text = "Normal Weight"
        case 25.0...29.9:
            bmiView.categoryLabel.text = "Overweight"
        default:
            bmiView.categoryLabel.text = "Obese"
            
        }
    }
    
    private func createPicker() {
        weightPicker.delegate = self
        weightPicker.dataSource = self
        weightPicker.selectRow(bmiView.weightInPounds.firstIndex(of: 215) ?? 0, inComponent: 0, animated: true)
        weightPicker.backgroundColor = .backgroundColor
        bmiView.weightTextField.inputView = weightPicker
        
        heightPicker.delegate = self
        heightPicker.dataSource = self
        heightPicker.selectRow(bmiView.heightInFeetAndInches.firstIndex(of: "5'9\"") ?? 0, inComponent: 0, animated: true)
        heightPicker.backgroundColor = .backgroundColor
        bmiView.heightTextField.inputView = heightPicker
    }
    
    func setupImperialPickerViews() {
        weightPicker.selectRow(bmiView.weightInPounds.firstIndex(of: 215) ?? 0, inComponent: 0, animated: true)
        heightPicker.selectRow(bmiView.heightInFeetAndInches.firstIndex(of: "5'9\"") ?? 0, inComponent: 0, animated: true)
    }
    
    func setupMetricPickerViews() {
        weightPicker.selectRow(bmiView.weightInKg.firstIndex(of: 97.5) ?? 0, inComponent: 0, animated: true)
        heightPicker.selectRow(bmiView.heightInCm.firstIndex(of: 174.0) ?? 0, inComponent: 0, animated: true)
    }
    
    func createPickerToolBar() {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismissKeyboard))
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
