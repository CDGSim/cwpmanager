//
//  ODSAMANNetworking.swift
//  
//
//  Created by Axel Péju on 10/02/2022.
//

import Foundation

/// Protocol that entities able to connect to ODS and AMAN via the network should conform to.
protocol ODSAMANNetworking {
    var positions: [ODSPosition] { get }
    
    /// Remotely fetch how the ODS machines are associated with an exercise branch
    func fetchPositionsLayout() -> CWPLayout
    
    /// Remotely configure an ODS position to listen to a specific branch
    func setODS(position:ODSPosition, toExercise exerciseNumber:Int) throws -> String
    
    /// Restart AMAN on the specified branch
    func restartAMANOnBranch(_ branchID:Int, withLayout:CWPLayout) throws -> String
    
    /// Stop AMAN on the specified branch
    func stopAMANOnBranch(_ branchID:Int) throws -> String
}
