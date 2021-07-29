//
//  EvaluteMetricsProtocol.swift
//  BMI
//
//  Created by Josiah Rininger on 8/5/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import Foundation

protocol EvaluteMetricsProtocol {
    var key: String { get }
    var value: Double { get }
    var formattedTitle: String { get }
}
