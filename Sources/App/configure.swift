import Vapor

var odsAMANManager = ODSAMANManager()
//let odsAMANManager = ODSAMANManager(networking: TestNetworking())

// configures your application
public func configure(_ app: Application) throws {
    if app.environment == .testing {
        odsAMANManager  = ODSAMANManager(networking: TestNetworking())
    }
    
    // Configure the ODS & AMAN Manager
    odsAMANManager.configure(app)
    
    // Register routes
    try routes(app)
}
