//
//  ControllerWorkingPosition.swift
//  
//
//  Created by Axel Péju on 09/02/2022.
//

import Foundation

struct ControllerWorkingPosition: Codable {
    let name: String
    var role: AMANPositionRole
    var simulationBranchNumber: Int?
}
