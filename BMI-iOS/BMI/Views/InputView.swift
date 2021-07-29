//
//  InputView.swift
//  BMI
//
//  Created by Josiah Rininger on 8/6/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import SwiftUI

struct InputView: View {
    @State var firstInput: String
    @State var secondInput: String
    @State var measurement: Measurements
    @State var abbreviation: [String]
    var action: (String) -> Void
    
    var body: some View {
        HStack {
            Spacer()
            Text(measurement.title)
                .modifier(TextStyle(fontSize: 30,
                                    fontWeight: .bold,
                                    color: Color("blue")))
            TextField("0", text: $firstInput, onCommit: {
                self.action(self.firstInput)
            })
                .keyboardType(.numberPad)
                .background(Color("secondary"))
                .cornerRadius(9)
                .modifier(TextStyle(fontSize: 30,
                                    fontWeight: .bold,
                                    color: Color("blue")))
                .frame(width: UIScreen.main.bounds.width * 0.24 / CGFloat(abbreviation.count),
                       height: 30)
            Text(abbreviation[0])
                .modifier(TextStyle(fontSize: 30,
                                    fontWeight: .bold,
                                    color: Color("blue")))
            if abbreviation.count == 2 {
                TextField("0", text: $secondInput, onCommit: {
                    self.action(self.secondInput)
                })
                    .keyboardType(.numberPad)
                    .background(Color("secondary"))
                    .cornerRadius(9)
                    .modifier(TextStyle(fontSize: 30,
                                        fontWeight: .bold,
                                        color: Color("blue")))
                .frame(width: UIScreen.main.bounds.width * 0.12,
                       height: 30)
                Text(abbreviation[1])
                    .modifier(TextStyle(fontSize: 30,
                                        fontWeight: .bold,
                                        color: Color("blue")))
            }
            Spacer()
        }
    }
}

// extension for keyboard to dismiss
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
