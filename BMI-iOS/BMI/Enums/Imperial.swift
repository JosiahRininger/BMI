//
//  Imperial.swift
//  BMI
//
//  Created by Josiah Rininger on 8/5/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import Foundation

enum Imperial: EvaluteMetricsProtocol {
    case weight(Double), height(Double)

    var header: String {
        switch self {
        case .weight: return "Change Weight"
        case .height: return "Change Height"
        }
    }

    var key: String {
        switch self {
        case .weight: return "imperialWeight"
        case .height: return "imperialHeight"
        }
    }
    
    var value: Double {
        switch self {
        case .weight(let num), .height(let num): return num
        }
    }
    
    var formattedTitle: String {
        switch self {
        case .weight(let value): return "\(value) lbs"
        case .height(let value): return "\(value) ft \(value) in"
        }
    }

}
