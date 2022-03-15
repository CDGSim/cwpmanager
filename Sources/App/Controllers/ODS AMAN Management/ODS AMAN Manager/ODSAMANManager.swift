//
//  ODSAMANManager.swift
//  
//
//  Created by Axel Péju on 09/02/2022.
//

import Foundation
import Vapor

class ODSAMANManager {
    
    var clients = WebsocketClients()
    
    var networking: ODSAMANNetworking
    
    // A reference to the application is needed enable logging
    private var app: Application? = nil
    
    internal init(networking: ODSAMANNetworking = ODSAMANSSHInterface()) {
        self.networking = networking
        
        self.state = ManagerState(positionLayout:networking.fetchPositionsLayout())
    }
    
    /// Configures the manager with the application.
    func configure(_ app:Application) {
        self.app = app
        
        app.logger.notice(.init(stringLiteral: "Configure ODS Manager"))
    }
    
    actor ManagerState {
        internal init(count: Int = 0, positionLayout: CWPLayout) {
            self.changesInProgress = count
            self.positionLayout = positionLayout
            self.changedLayout = CWPLayout([])
        }
        
        private (set) var changesInProgress: Int = 0
        func increaseChangesInProgress() {
            changesInProgress += 1
        }
        func decreaseChangesInProgress() {
            changesInProgress -= 1
        }
        
        private (set) var positionLayout: CWPLayout
        func saveLayout(_ layout: CWPLayout) {
            self.positionLayout = layout
        }
        
        private (set) var changedLayout: CWPLayout
        func saveNewPosition(position: ControllerWorkingPosition) {
            if let existingIndex = self.changedLayout.controllerWorkingPositions.firstIndex(where: { $0.name == position.name }) {
                self.changedLayout.controllerWorkingPositions[existingIndex] = position
            } else {
                self.changedLayout.controllerWorkingPositions.append(position)
            }
        }
        
        func saveNewPositions(_ positions: [ControllerWorkingPosition]) {
            positions.forEach { cwp in
                self.saveNewPosition(position: cwp)
            }
        }
    }
    
    private (set) var state: ManagerState
    
    func didReceivePositionLayout(_ layout:CWPLayout) {
        app?.logger.notice(.init(stringLiteral: "Client sent new layout"))
        
        Task {
            await state.increaseChangesInProgress()
            let previousLayout = await state.positionLayout
            
            var changedPositions = [ControllerWorkingPosition]()
            
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
                    if inMemoryPosition.simulationBranchNumber != newPosition.simulationBranchNumber ||
                        inMemoryPosition.role != newPosition.role {
                        changedPositions.append(newPosition)
                    }
                }
            }
            
            await state.saveNewPositions(changedPositions)
            await state.decreaseChangesInProgress()
            
            guard await state.changesInProgress == 0 else {
                return
            }
            
            // Fetch all changed positions and merge them in current layout
            let currentLayout = await state.positionLayout
            let changedLayout = await state.changedLayout
            let newLayoutPositions = currentLayout.controllerWorkingPositions.map { cwp -> ControllerWorkingPosition in
                if let matchingChangedCWP = changedLayout.controllerWorkingPositions.first(where: { $0.name == cwp.name }) {
                    return matchingChangedCWP
                } else {
                    return cwp
                }
            }
            
            await state.saveLayout(CWPLayout(newLayoutPositions))
            
            // Send the new layout to all subscribers
            if let payload = try? await JSONEncoder().encode(state.positionLayout) {
                for socket in clients.websockets() {
                    let bytes = [UInt8](payload)
                    try? await socket.send(bytes)
                }
            }
        }
    }
    
    func restartAMANOnBranch(_ branchID:Int) {
        Task {
            // Check that each position in this branch has a different role.
            // If we send a command with 2 positions with the same role, we will
            // have an error.
            let branchPositions = await state.positionLayout.controllerWorkingPositions.filter { position in
                position.simulationBranchNumber == branchID
            }
            let positionRoles = Set(branchPositions.map({ $0.role }))
            guard positionRoles.count == branchPositions.count else {
                let error = "Cannot restart AMAN: two positions have the same role."
                app?.logger.notice(.init(stringLiteral: "\(error)"))
                return
            }
            
            app?.logger.notice(.init(stringLiteral: "Will restart AMAN on branch \(branchID)"))
            let result = try? await self.networking.restartAMANOnBranch(branchID, withLayout: state.positionLayout)
            app?.logger.notice(.init(stringLiteral: "Result : \(result ?? "error")"))
        }
    }
    
    func stopAMANOnBranch(_ branchID:Int) {
        app?.logger.notice(.init(stringLiteral: "Will stop AMAN on branch \(branchID)"))
        let result = try? self.networking.stopAMANOnBranch(branchID)
        app?.logger.notice(.init(stringLiteral: "Result : \(result ?? "error")"))
    }
}
