//
//  ODSAMANSSHInterface.swift
//  
//
//  Created by Axel Péju on 10/02/2022.
//

import Foundation
import Vapor

struct ODSPosition: Decodable {
    let name: String
    let associatedODSHost: String
    let associatedAMANHost: String
}

struct ConfigurationEnvironmentVariable: Decodable {
    let gatewayIP: String
    let gatewayLogin: String
    let gatewayPassword: String
    let positions: [ODSPosition]
}

/// An interface able to connect to AMAN and ODS machines via SSH
struct ODSAMANSSHInterface {
    var positions: [ODSPosition]
    
    /// The IP address of the host we can directly connect to via SSH
    private var gatewayIP: String
    
    private var gatewayLogin: String
    private var gatewayPassword: String
    
    internal init() {
        guard let configurationJSON = Environment.get("CONFIG"), let data = configurationJSON.data(using: .utf8) else {
            fatalError("No configuration set in CONFIG environment variable")
        }
        do {
            let setupConfiguration = try JSONDecoder().decode(ConfigurationEnvironmentVariable.self, from:data)
            
            // Should find out the positions and the IP from the environment
            self.positions = setupConfiguration.positions
            self.gatewayIP = setupConfiguration.gatewayIP
            self.gatewayLogin = setupConfiguration.gatewayLogin
            self.gatewayPassword = setupConfiguration.gatewayPassword
        } catch {
            fatalError("Could not decode CONFIG environement variable")
        }
    }
}

extension ODSAMANSSHInterface: ODSAMANNetworking {
    
    func restartAMANOnBranch(_ branchID: Int, withLayout layout:CWPLayout) throws -> String {
        
        // Arguments to set a TX on a role, for instance:
        //      -p ITM_S=cdgmtx98
        //
        // For each position, create the appropriate argument only if
        // the corresponding position in the provided 'layout' is associated to 'branchID'
        let positionsOnThisBranch = layout.controllerWorkingPositions.filter { cwp in
            cwp.simulationBranchNumber == branchID          // Get only the positions set on 'branchID'
        }
        let arguments = self.positions.compactMap { position -> String? in
            guard let positionRole = positionsOnThisBranch.first(where: { cwp in
                cwp.name == position.name                       // Find the position from its name
            })?.role.name else { return nil }                   // Get the position role if found
            return "-p \(positionRole)=\(position.associatedAMANHost)"
        }
        
        let changeDirectoryCommand = ["cd", "/home/maestro/applicatif/MAESTRO_AMAN/current-version/etc/"]
        let stopCommand = ["./maestro_stop_instance.sh",
                               "-name",
                               "TST_UFA_\(branchID)",
                               "-clean"]
        let startCommand = ["./maestro_new_instance.sh",
                            "-itf Rdps=226.0.0.1:110\(branchID)6",
                            "Udp Client Cat_30_Electra Cat_252_Electra True 135 08",
                            "-itf Sigma=UFA\(branchID):220\(15+branchID)",
                            "-data LFPG",
                            "-name TST_UFA_\(branchID)",
                            "-sup cdgins99",
                            "-p SUP=cdgins99"] + arguments + ["-portisfree"]
        let command = changeDirectoryCommand + [";"] + stopCommand + [";"] + startCommand
        
        let logger = Logger(label: "sshcommand")
        logger.notice("Executing commands via SSH…")
        logger.notice("\(changeDirectoryCommand.joined(separator: " "))")
        logger.notice("\(stopCommand.joined(separator: " "))")
        logger.notice("\(startCommand.joined(separator: " "))")
        
        return try runSSHCommand(command, on: gatewayIP, login: gatewayLogin, password: gatewayPassword)
        
    }
    
    func stopAMANOnBranch(_ branchID: Int) throws -> String {
        let changeDirectoryCommand = ["cd", "/home/maestro/applicatif/MAESTRO_AMAN/current-version/etc/"]
        let stopCommand = ["./maestro_stop_instance.sh",
                               "-name",
                               "TST_UFA_\(branchID)",
                               "-clean"]
        let command = changeDirectoryCommand + [";"] + stopCommand
        return try runSSHCommand(command, on: gatewayIP, login: gatewayLogin, password: gatewayPassword)
    }
    
    func fetchPositionsLayout() -> CWPLayout {
        let controlWorkingPositions = positions.map { position -> ControllerWorkingPosition in
            // Fetch the content of the status file on the ODS machine
            let fileContent = try? statusFileContent(on: position)
            
            if let content = fileContent {
                // Parse the content, expected to be formatted as `exercice_N` where `N` is
                // the number of the simulation branch the ODS machine is configured to listen to.
                let simulationBranchNumberStr = content.components(separatedBy: "_").last
                
                if let branchStr = simulationBranchNumberStr {
                    // Convert to Int
                    if let branchNumber = Int(branchStr) {
                        return ControllerWorkingPosition(name: position.name, role: .seq, simulationBranchNumber: branchNumber)
                    }
                }
            }
            
            // We could not fetch or parse the branch number so return a position not assigned to a branch
            return ControllerWorkingPosition(name: position.name, role: .seq)
        }
        
        return CWPLayout(controlWorkingPositions)
    }
    
    func setODS(position:ODSPosition, toExercise exerciseNumber:Int) throws -> String {
        let command = ["rsh",
                       "-l root",
                       position.associatedODSHost,
                       "\"cd /phidias/courant/ParamLB; ./exercice0.sh; ./exercice\(exerciseNumber).sh\""]
        return try runSSHCommand(command, on: gatewayIP, login: gatewayLogin, password: gatewayPassword)
    }
}

extension ODSAMANSSHInterface {
    
    /// Fetches the status file content on a remote ODS machine, connecting via SSH.
    /// - Parameter position: the position to connect to
    /// - Returns: The content of the status file as a String. This file contains `exercice_N` where `N` is the number of the simulation branch the ODS machine is configured to listen to.
    private func statusFileContent(on position:ODSPosition) throws -> String {
        let command = ["rsh",
                       "-l root",
                       position.associatedODSHost,
                       "\"cat /phidias/courant/ParamLB/test.txt\""]
        return try runSSHCommand(command, on:gatewayIP, login: gatewayLogin, password: gatewayPassword)
    }
    
    /// Runs an SSH command on a remote host
    ///
    /// - Parameters:
    ///     - remoteCommand: the command to be run on the remote host as an array of String
    ///     - remoteHostIP: the ipv4 address of the remote host the command should be executed on
    ///     - login: the login to connect to the remote host
    ///     - password: the password to connect to the remote host
    /// - Returns:the output of the remote command
    private func runSSHCommand(_ remoteCommand: [String], on remoteHostIP:String, login:String, password:String) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sshpass")
        task.arguments = ["-p",
                          "\(password)",
                          "ssh",
                          "-o StrictHostKeyChecking=no",
                          "\(login)@\(remoteHostIP)"] + remoteCommand
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        try task.run()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        task.waitUntilExit()
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
