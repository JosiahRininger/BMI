//
//  ResultsView.swift
//  BMI
//
//  Created by Josiah Rininger on 8/6/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import SwiftUI

struct ResultsView: View {
    @State var results: (String, String)
    
    var body: some View {
        VStack {
            Text(results.0)
                .font(.system(size: 58,
                              weight: .medium,
                              design: .rounded))
                .foregroundColor(Color("blue"))
            Text(results.1)
                .font(.system(size: 29,
                              weight: .medium,
                              design: .rounded))
                .foregroundColor(Color("blue"))
                .padding(.top)
        }
    }
}
