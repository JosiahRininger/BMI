//
//  Metric.swift
//  BMI
//
//  Created by Josiah Rininger on 8/5/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import Foundation

enum Metric: EvaluteMetricsProtocol {
    case weight(Double), height(Double)

    var title: String {
        switch self {
        case .weight: return "Change Weight"
        case .height: return "Change Height"
        }
    }

    var key: String {
        switch self {
        case .weight: return "metricWeight"
        case .height: return "metricHeight"
        }
    }
    
    var value: Double {
        switch self {
        case .weight(let num), .height(let num): return num
        }
    }
    
    var formattedTitle: String {
        switch self {
        case .weight(let value): return "\(value) kgs"
        case .height(let value): return "\(value) cms"
        }
    }

}
