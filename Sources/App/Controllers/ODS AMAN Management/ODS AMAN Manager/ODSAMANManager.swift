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
    
    enum ODSAMANManagerError: Error {
        case tooManyRestartRequests
    }
    
    internal init(networking: ODSAMANNetworking = ODSAMANSSHInterface()) {
        self.networking = networking
        
        self.state = ManagerState(positionLayout:networking.fetchPositionsLayout())
    }
    
    /// Configures the manager with the application.
    func configure(_ app:Application) {
        self.app = app
        
        app.logger.notice(.init(stringLiteral: "Configure ODS Manager"))
    }
    
    // MARK: - Manager state
    
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
        
        private (set) var lastODSPositionRelaunchTimes = [ODSPosition:Date]()
        func saveLastRelaunchDate(for position:ODSPosition) {
            lastODSPositionRelaunchTimes[position] = Date()
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
    
    // MARK: - Layout change
    
    func didReceivePositionLayout(_ layout:CWPLayout) async {
        app?.logger.info("Client sent new layout…")
        
        await state.increaseChangesInProgress()
        let previousLayout = await state.positionLayout
        
        var changedPositions = [ControllerWorkingPosition]()
        
        for newPosition in layout.controllerWorkingPositions {
            if let inMemoryPosition = previousLayout.controllerWorkingPositions.first(where: { $0.name == newPosition.name }) {
                // Check if simulationBranchNumber is different
                if inMemoryPosition.simulationBranchNumber != newPosition.simulationBranchNumber,
                   let newBranchNumber = newPosition.simulationBranchNumber {
                    if let position = networking.positions.first(where: { $0.name == newPosition.name}) {
                        do {
                            try await setODS(position: position, toExercise: newBranchNumber)
                            changedPositions.append(newPosition)
                        } catch ODSAMANManagerError.tooManyRestartRequests {
                            app?.logger.notice("Will not set to branch \(newBranchNumber), did already change the branch less than 10 seconds ago.")
                        } catch {
                            
                        }
                    }
                }
                if inMemoryPosition.role != newPosition.role {
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
    
    func setODS(position: ODSPosition, toExercise branchNumber: Int) async throws {
        // Make sure this ODS position has not been set to this branch during the last 10 seconds
        let lastRelaunchTime = await state.lastODSPositionRelaunchTimes[position]
        
        guard lastRelaunchTime == nil || Date().timeIntervalSince(lastRelaunchTime!) > 10 else {
            throw ODSAMANManagerError.tooManyRestartRequests
        }
        
        // Log that we will configure the ODS position to the new branch
        app?.logger.info("Should configure position \(position.name) to branch \(branchNumber)…")
        
        // Save the relaunch date
        await state.saveLastRelaunchDate(for: position)
        
        // Send the network command to ODS
        Task {
            let _ = try self.networking.setODS(position: position, toExercise: branchNumber)
            
            // Log the result
            app?.logger.info("Succesfully set ODS \(position.name) to branch \(branchNumber).")
        }
    }
    
    // MARK: - AMAN Branch control
    private var lastAMANRelaunchTimes = [Int: Date]()
    
    func restartAMANOnBranch(_ branchID:Int) {
        // Make sure this branch has not been requested for a restart during the last 5 seconds
        if let lastRelaunchTime = lastAMANRelaunchTimes[branchID] {
            guard Date().timeIntervalSince(lastRelaunchTime) > 5 else {
                app?.logger.notice("Too many AMAN restart requests on branch \(branchID) during the last 5 seconds.")
                return
            }
        }
        lastAMANRelaunchTimes[branchID] = Date()
        
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
                app?.logger.error("\(error)")
                return
            }
            
            app?.logger.info("Will restart AMAN on branch \(branchID)…")
            let result = try? await self.networking.restartAMANOnBranch(branchID, withLayout: state.positionLayout)
            app?.logger.notice("Result : \(result ?? "error")")
        }
    }
    
    func stopAMANOnBranch(_ branchID:Int) {
        app?.logger.notice(.init(stringLiteral: "Will stop AMAN on branch \(branchID)"))
        let result = try? self.networking.stopAMANOnBranch(branchID)
        app?.logger.notice("Result : \(result ?? "error")")
    }
    
    // MARK: - ODS Branch control
    
    private var lastODSRelaunchTimes = [Int: Date]()
    
    func restartODSOnBranch(_ branchID:Int) async -> HTTPStatus {
        // Make sure this branch has not been requested for a restart during the last 15 seconds
        if let lastRelaunchTime = lastODSRelaunchTimes[branchID] {
            guard Date().timeIntervalSince(lastRelaunchTime) > 10 else {
                app?.logger.notice("Too many ODS restart requests on branch \(branchID) during the last 10 seconds.")
                return .tooManyRequests
            }
        }
        lastODSRelaunchTimes[branchID] = Date()
        
        app?.logger.info("Will restart all ODS on branch \(branchID)")
        Task {
            let result = try? await self.networking.restartODSOnBranch(branchID, withLayout: state.positionLayout)
            app?.logger.info("Result : \(result ?? "error")")
        }
        
        return .ok
    }
}
