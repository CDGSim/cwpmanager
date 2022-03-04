import Vapor

let odsAMANManager = ODSAMANManager()

// configures your application
public func configure(_ app: Application) throws {
    // Configure the ODS & AMAN Manager
    odsAMANManager.configure(app)
    
    // Register routes
    try routes(app)
}
