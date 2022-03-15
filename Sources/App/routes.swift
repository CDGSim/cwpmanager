import Vapor
import Foundation

/// Configures the HTTP server's route.
func routes(_ app: Application) throws {
    // The use case for each route is described below.
    
    // Called when a GET request is sent on the / URL
    // This route can be used to display the internal representation
    // of the controller working positions layout in a web browser.
    app.get { req async -> String in
        var response = String()
        response += "Représentation interne des positions de contrôle :"
        response += "\n\n"
        response += "Position\t\tBranche\t\tRôle\n"
        response += "-------------------------------------------------\n"
        await response += odsAMANManager.state.positionLayout.controllerWorkingPositions.map { cwp in
            let branch = cwp.simulationBranchNumber != nil ? "\(cwp.simulationBranchNumber!)" : "Aucune"
            return cwp.name + "\t\t" + branch + "\t\t" + cwp.role.name + "\n"
        }.reduce("") { $0 + $1 }
        return response
    }

    // Websocket on /distribution URL
    // This route can be used by clients to read the distribution layout
    // and send updates to the server.
    app.webSocket("distribution") { req, ws async in
        app.logger.notice(.init(stringLiteral: "client connected"))
        
        // Add the client to the manager's clients list
        let client = WebSocketClient(ws)
        odsAMANManager.clients.add(client)
        
        // Send the newly connected client a representation of the positions layout
        Task {
            if let payload = try? await JSONEncoder().encode(odsAMANManager.state.positionLayout) {
                let bytes = [UInt8](payload)
                try? await ws.send(bytes)
            }
        }
        
        // When receiving data on this socket…
        ws.onBinary { ws, binary in
            do {
                // Decode the content
                let content = try JSONDecoder().decode(CWPLayout.self, from:binary)
                
                // Notify the manager
                odsAMANManager.didReceivePositionLayout(content)
            } catch {
                print("error decoding \(error)")
            }
        }
        
        // When a client disconnect…
        ws.onClose.whenComplete { result in
            odsAMANManager.clients.remove(client)
        }
    }
    
    // POST request on /restartAMAN/<branchID>
    // This route can be used by a client application, or SimControl after
    // launching an exercise via a post-launch script.
    app.post("restartAMAN", ":branchID") { req -> HTTPStatus in
        if let branchID = Int(req.parameters.get("branchID")!) {
            Task {
                odsAMANManager.restartAMANOnBranch(branchID)
            }
        }
        return HTTPStatus.ok
    }
    
    // POST request on /stopAMAN/<branchID>
    // This route can be used by a client application, or SimControl after
    // ending an exercise via a post-shutdown script.
    app.post("stopAMAN", ":branchID") { req -> HTTPStatus in
        if let branchID = Int(req.parameters.get("branchID")!) {
            Task {
                odsAMANManager.stopAMANOnBranch(branchID)
            }
        }
        return HTTPStatus.ok
    }
    
    // GET request on /didSetODS/<positionName/branch/<branchID>
    // Should be sent by ODS after setting itself to branchID
    app.get("didSetODS", ":positionName", "branch", ":branchID") { req async -> HTTPStatus in
        let positionName = req.parameters.get("positionName")!
        guard let branchID = Int(req.parameters.get("branchID")!) else {
            return HTTPStatus.badRequest
        }
        
        if let positionIndex = await odsAMANManager.state.positionLayout.controllerWorkingPositions.firstIndex(where:{ cwp in
            cwp.name == positionName
        }) {
            var layout = await odsAMANManager.state.positionLayout
            layout.controllerWorkingPositions[positionIndex].simulationBranchNumber = branchID
            
            // Trigger an update, the manager will notify all its clients
            odsAMANManager.didReceivePositionLayout(layout)
        }
        return HTTPStatus.ok
    }
}
