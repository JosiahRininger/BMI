//
//  BMIView.swift
//  BMI
//
//  Created by Josiah Rininger on 8/5/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import SwiftUI
import UIKit
import GoogleMobileAds

struct BMIView: View {
    @State var selection: Options = .Imperial
    @State var results = ("0.0", "Overweight")
    @State var imperialMetrics: [Imperial] = [
        .weight(0),
        .height(0)
    ]
    @State var metricMetrics: [Metric] = [
        .weight(0),
        .height(0)
    ]

    var body: some View {
        
        ZStack {
            
            Color("background")
            
            VStack {
                
                HeaderView(selection: $selection)
                
                ResultsView(results: $results)
                
                if selection == Options.Imperial {
                    VStack {
                        Spacer()

                        InputView(firstInput: self.imperialMetrics[0].value == 0 ? "" : "\(self.imperialMetrics[0].value)",
                            secondInput: "",
                            measurement: Measurements.weight,
                            abbreviation: ["lb"]) { value in
                                self.imperialMetrics[0] = Imperial.weight(Double(value) ?? 0.0)
                        }
                        
                        Spacer()
                        
                        InputView(firstInput: self.imperialMetrics[0].value == 0 ? "" : "\(Int(self.imperialMetrics[1].value / 12))",
                            secondInput: self.imperialMetrics[0].value == 0 ? "" : "\(Int(self.imperialMetrics[1].value) % 12)",
                            measurement: Measurements.height,
                            abbreviation: ["ft", "in"]) { value in
                                self.imperialMetrics[1] = Imperial.height(Double(value) ?? 0.0)
                        }
                        
                        Spacer()
                    }
                    
                } else {
                    VStack {
                        Spacer()
                        
                        InputView(firstInput: self.metricMetrics[0].value == 0 ? "" : "\(self.metricMetrics[0].value)",
                            secondInput: "",
                            measurement: Measurements.weight,
                            abbreviation: ["kg"]) { value in
                                self.metricMetrics[0] = Metric.weight(Double(value) ?? 0.0)
                        }
                        
                        Spacer()
                        
                        InputView(firstInput: self.metricMetrics[0].value == 0 ? "" : "\(self.metricMetrics[1].value)",
                            secondInput: "",
                            measurement: Measurements.height,
                            abbreviation: ["cm"]) { value in
                                self.metricMetrics[1] = Metric.height(Double(value) ?? 0.0)
                        }
                        
                        Spacer()
                    }
                    
                }
                                
                BMIButton {
                    self.calculateBMI()
                }
                
                Spacer()
                
                AdView()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 300)
                    .frame(width: kGADAdSizeBanner.size.width, height: kGADAdSizeBanner.size.height)
                
            }
            .frame(width: UIScreen.main.bounds.width * 0.85)
        }
        .onAppear {
            let toolBar = UIElementsManager.createToolBar(with: UIBarButtonItem(title: "Done",
                                                                                style: .plain,
                                                                                target: self,
                                                                                action: #selector(NewGameController.dismissKeyboard)))
            newGameView.usernameTextField.inputAccessoryView = toolBar
            newGameView.timeLimitTextField.inputAccessoryView = toolBar
            let dismissKeyboardTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            dismissKeyboardTapGestureRecognizer.cancelsTouchesInView = false
            view.addGestureRecognizer(dismissKeyboardTapGestureRecognizer)
        }
    }
    
    @objc
    private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func calculateBMI() {
        switch selection {
        case .Imperial: results = Measurements.calculateBMI(weight: imperialMetrics[0].value,
                                                            height: Int(imperialMetrics[1].value))
        case .Metric: results = Measurements.calculateBMI(weight: metricMetrics[0].value,
                                                          height: metricMetrics[1].value)
        }
    }
}

#if DEBUG
struct BMIView_Previews: PreviewProvider {
    static var previews: some View {
        Text("")
    }
}
#endif
