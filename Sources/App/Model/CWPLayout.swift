//
//  CWPLayout.swift
//  
//
//  Created by Axel Péju on 09/02/2022.
//

import Foundation
import Vapor

/// A representation of the layout of a simulator room.
struct CWPLayout: Content {
    internal init(_ controllerWorkingPositions: [ControllerWorkingPosition]) {
        self.controllerWorkingPositions = controllerWorkingPositions
    }
    
    var controllerWorkingPositions: [ControllerWorkingPosition]
}
