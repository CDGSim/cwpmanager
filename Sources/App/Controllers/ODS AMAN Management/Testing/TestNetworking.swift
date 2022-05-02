//
//  TestNetworking.swift
//  
//
//  Created by Axel Péju on 10/02/2022.
//

import Foundation

struct TestNetworking: ODSAMANNetworking {
    
    var positions: [ODSPosition] = Array(1...10).map { number in
        ODSPosition(name: "Position \(number)", associatedODSHost: "", associatedAMANHost: "")
    }
    
    func fetchPositionsLayout() -> CWPLayout {
        CWPLayout(positions.map({ position in
            ControllerWorkingPosition(name: position.name, role: .seq, simulationBranchNumber: 1)
        }))
    }
    
    func setODS(position: ODSPosition, toExercise exerciseNumber: Int) throws -> String {
        sleep(2)
        return "Succesfully set ODS to exercise \(exerciseNumber)"
    }
    
    func restartAMANOnBranch(_ branchID: Int, withLayout:CWPLayout) throws -> String {
        sleep(10)
        return "Succesfully restarted branch \(branchID)"
    }
    
    func stopAMANOnBranch(_ branchID: Int) throws -> String {
        sleep(4)
        return "Succesfully stopped branch \(branchID)"
    }
    
    func restartODSOnBranch(_ branchID:Int, withLayout layout: CWPLayout) async throws -> String {
        sleep(10)
        return "Succesfully restarted ODS on branch \(branchID)"
    }
    
}
