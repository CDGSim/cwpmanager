@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    
    func testTooManyRestartRequestsForODSOnBranchOne() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        
        try app.test(.POST, "restartODS/1", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
        try app.test(.POST, "restartODS/1", afterResponse: { res in
            XCTAssertEqual(res.status, .tooManyRequests)
        })
    }
    
    func testNotTooManyRestartRequestsForODSOnBranchOne() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        
        try app.test(.POST, "restartODS/1", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
        sleep(16)
        try app.test(.POST, "restartODS/1", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }
    
    func testTooManyIdenticalLayoutReceived() async throws {
        let odsAMANManager = ODSAMANManager(networking: TestNetworking())
        let position = ODSPosition(name: "Test", associatedODSHost: "", associatedAMANHost: "")
        try await odsAMANManager.setODS(position: position, toExercise: 2)
        
        do {
            try await odsAMANManager.setODS(position: position, toExercise: 2)
            XCTFail("Expected to throw, but succeeded.")
        } catch {
            XCTAssertEqual(error as? ODSAMANManager.ODSAMANManagerError, .tooManyRestartRequests)
        }
    }
    
    func testNotTooManyIdenticalLayoutReceived() async throws {
        let odsAMANManager = ODSAMANManager(networking: TestNetworking())
        let position = ODSPosition(name: "Test", associatedODSHost: "", associatedAMANHost: "")
        try await odsAMANManager.setODS(position: position, toExercise: 2)
        
        sleep(16)
        do {
            try await odsAMANManager.setODS(position: position, toExercise: 2)
        } catch {
            XCTFail("Expected not to fail, but error was thrown.")
        }
    }
}
