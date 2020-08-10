//
//  BMIView.swift
//  BMI
//
//  Created by Josiah Rininger on 8/5/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import SwiftUI
import GoogleMobileAds

struct BMIView: View {
    @State var option: Options = Options.Imperial
    @State var selection: Int = 0 {
        didSet {
            option = Options.allCases[selection]
        }
    }
    @State var imperialMetrics: [Imperial] = [
        .weight(0),
        .height(0)
    ]
    @State var metricMetrics: [Metric] = [
        .weight(0),
        .height(0)
    ]
    @State private var imperialType: Imperial? = nil
    @State private var metricType: Metric? = nil
    
    var body: some View {
        
        ZStack {
            
            Color("background")
            
            VStack {
                
                HeaderView(selection: $selection)
                
                ResultsView(results: ("0.0", "Overweight"))
                
                Spacer()
    
                if option == Options.Imperial {

                    InputView(firstInput: self.imperialMetrics[0].value == 0 ? "" : "\(self.imperialMetrics[0].value)",
                        secondInput: "",
                        measurement: Measurements.weight,
                        abbreviation: ["lb"])
                    
                    InputView(firstInput: self.imperialMetrics[0].value == 0 ? "" : "\(Int(imperialMetrics[1].value / 12))",
                        secondInput: self.imperialMetrics[0].value == 0 ? "" : "\(imperialMetrics[1].value % 12)",
                        measurement: Measurements.height,
                        abbreviation: ["ft", "in"])
                    
                } else {
                    
                    InputView(firstInput: self.metricMetrics[0].value == 0 ? "" : "\(self.metricMetrics[0].value)",
                        secondInput: "",
                        measurement: Measurements.weight,
                        abbreviation: ["kg"])
                    
                    InputView(firstInput: self.metricMetrics[0].value == 0 ? "" : "\(self.metricMetrics[1].value)",
                        secondInput: "",
                        measurement: Measurements.height,
                        abbreviation: ["cm"])
                    
                }
                
                Spacer()
                
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
    }
    
    private func calculateBMI() {
        
    }
}

#if DEBUG
struct BMIView_Previews: PreviewProvider {
    static var previews: some View {
        Text("")
    }
}
#endif
