//
//  WebsocketClients.swift
//  
//
//  Created by Axel Péju on 12/02/2022.
//

import Foundation
import Vapor

open class WebSocketClient {
    open var id: UUID
    open var socket: WebSocket

    public init(id: UUID = UUID(), _ socket: WebSocket) {
        self.id = id
        self.socket = socket
    }
}

open class WebsocketClients {
    private var storage: [UUID: WebSocketClient]

    init(clients: [UUID: WebSocketClient] = [:]) {
        self.storage = clients
    }
    
    func add(_ client: WebSocketClient) {
        self.storage[client.id] = client
    }

    func remove(_ client: WebSocketClient) {
        self.storage.removeValue(forKey:client.id)
    }
    
    func find(_ uuid: UUID) -> WebSocketClient? {
        self.storage[uuid]
    }
    
    func websockets() -> [WebSocket] {
        return storage.map { pair in
            pair.value.socket
        }
    }
}
