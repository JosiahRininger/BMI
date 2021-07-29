//
//  BMIButton.swift
//  BMI
//
//  Created by Josiah Rininger on 8/5/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import SwiftUI

struct BMIButton: View {
    let action: () -> Void
    
    var body: some View {
        ZStack {
            Button(action: { self.action() }) {
                Text("Calculate")
                    .modifier(TextStyle(fontSize: 28,
                                        fontWeight: .semibold,
                                        color: Color("secondary")))
            }
            .background(LinearGradient(gradient: Gradient(colors: [Color("blue"), Color("darkBlue")]),
                                       startPoint: .top,
                                       endPoint: .bottom)
                .frame(width: UIScreen.main.bounds.width * 0.6,
                       height: UIScreen.main.bounds.width * 0.15,
                       alignment: .center)
                .cornerRadius(9))
                .frame(width: UIScreen.main.bounds.width * 0.6,
                       height: UIScreen.main.bounds.width * 0.15,
                       alignment: .center)
                .cornerRadius(9)
        }
    }
}
