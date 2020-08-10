//
//  HeaderView.swift
//  BMI
//
//  Created by Josiah Rininger on 8/6/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import SwiftUI

struct HeaderView: View {
    @Binding var selection: Int
    
    var body: some View {
        HStack {
            
            Spacer()
                .frame(width: 28,
                       height: 28)
            
            Picker(selection: $selection, label: Text("")) {
                ForEach(0..<Options.allCases.count) {
                    Text(Options.allCases[$0].rawValue)
                        .modifier(TextStyle(fontSize: 24,
                                            fontWeight: .bold,
                                            color: Color("blue")))
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: UIScreen.main.bounds.width * 0.71, height: UIScreen.main.bounds.width * 0.3)
            
            Image("exclamationmark")
                .font(Font.body.weight(.bold))
                .background(LinearGradient(gradient: Gradient(colors: [Color("blue"), Color("darkBlue")]), startPoint: .top, endPoint: .bottom)
                    .frame(width: 28, height: 28).cornerRadius(28 / 2))
                .frame(width: 28,
                       height: 28)
                .cornerRadius(28 / 2)
            
        }
    }
}
