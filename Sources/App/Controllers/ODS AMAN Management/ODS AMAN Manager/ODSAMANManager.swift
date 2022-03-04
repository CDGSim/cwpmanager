//
//  File.swift
//  
//
//  Created by Axel Péju on 09/02/2022.
//

import Foundation
import Vapor

class ODSAMANManager {
    
    var clients = WebsocketClients()
    var positionLayout: CWPLayout
    
    var networking: ODSAMANNetworking
    
    // A reference to the application is needed enable logging
    private var app: Application? = nil
    
    internal init(networking: ODSAMANNetworking = ODSAMANSSHInterface()) {
        self.networking = networking
        
        self.positionLayout = networking.fetchPositionsLayout()
    }
    
    /// Configures the manager with the application.
    func configure(_ app:Application) {
        self.app = app
        
        app.logger.notice(.init(stringLiteral: "Configure ODS Manager"))
    }
    
    actor ODSChanges {
        var count: Int = 0
        func increase() {
            count += 1
        }
        func decrease() {
            count -= 1
        }
    }
    private var changesInProgress = ODSChanges()
    
    func didReceivePositionLayout(_ layout:CWPLayout) {
        app?.logger.notice(.init(stringLiteral: "Client sent new layout"))
        
        let previousLayout = self.positionLayout
        
        // Save new layout
        self.positionLayout = layout
        Task {
            await changesInProgress.increase()
            layout.controllerWorkingPositions.forEach { newPosition in
                if let inMemoryPosition = previousLayout.controllerWorkingPositions.first(where: { $0.name == newPosition.name }) {
                    // Check if simulationBranchNumber is different
                    if inMemoryPosition.simulationBranchNumber != newPosition.simulationBranchNumber,
                       let newBranchNumber = newPosition.simulationBranchNumber {
                        if let position = networking.positions.first(where: { $0.name == newPosition.name}) {
                            app?.logger.notice(.init(stringLiteral: "should configure position \(position.name) to branch \(newBranchNumber)"))
                            do {
                                let commandResult = try self.networking.setODS(position: position, toExercise: newBranchNumber)
                                app?.logger.notice(.init(stringLiteral: commandResult))
                            } catch {
                                app?.logger.critical(.init(stringLiteral: "error setting ODS… \(error)"))
                            }
                        }
                    }
                }
            }
            await changesInProgress.decrease()
            
            guard await changesInProgress.count == 0 else {
                return
            }
            
            // Send the new layout to all subscribers
            for socket in clients.websockets() {
                if let payload = try? JSONEncoder().encode(layout) {
                    let bytes = [UInt8](payload)
                    try? await socket.send(bytes)
                }
            }
        }
    }
    
    func restartAMANOnBranch(_ branchID:Int) {
        // Check that each position in this branch has a different role.
        // If we send a command with 2 positions with the same role, we will
        // have an error.
        let branchPositions = positionLayout.controllerWorkingPositions.filter { position in
            position.simulationBranchNumber == branchID
        }
        let positionRoles = Set(branchPositions.map({ $0.role }))
        guard positionRoles.count == branchPositions.count else {
            let error = "Cannot restart AMAN: two positions have the same role."
            app?.logger.notice(.init(stringLiteral: "\(error)"))
            return
        }
        
        app?.logger.notice(.init(stringLiteral: "Will restart AMAN on branch \(branchID)"))
        let result = try? self.networking.restartAMANOnBranch(branchID, withLayout: positionLayout)
        app?.logger.notice(.init(stringLiteral: "Result : \(result ?? "error")"))
    }
    
    func stopAMANOnBranch(_ branchID:Int) {
        app?.logger.notice(.init(stringLiteral: "Will stop AMAN on branch \(branchID)"))
        let result = try? self.networking.stopAMANOnBranch(branchID)
        app?.logger.notice(.init(stringLiteral: "Result : \(result ?? "error")"))
    }
}
