//
//  HeaderView.swift
//  BMI
//
//  Created by Josiah Rininger on 8/6/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import SwiftUI

struct HeaderView: View {
    @Binding var selection: Options
    
    var body: some View {
        HStack {
            
            Spacer()
                .frame(width: 28,
                       height: 28)

            Picker("", selection: $selection) {
                ForEach(Options.allCases, id: \.self) {
                    Text($0.rawValue)
                        .modifier(TextStyle(fontSize: 24,
                                            fontWeight: .bold,
                                            color: Color("blue")))
                        .tag($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: UIScreen.main.bounds.width * 0.71, height: UIScreen.main.bounds.width * 0.3)
            
            Image("exclamationmark")
                .font(Font.body.weight(.bold))
            .foregroundColor(Color("background"))
                .background(LinearGradient(gradient: Gradient(colors: [Color("blue"), Color("darkBlue")]), startPoint: .top, endPoint: .bottom)
                    .frame(width: 28, height: 28).cornerRadius(28 / 2))
                .frame(width: 28,
                       height: 28)
                .cornerRadius(28 / 2)
            
        }
    }
}
