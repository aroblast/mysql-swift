import Foundation

public extension MySQL {
	
	class ConnectionPool {
		
		// Connection with its state
		struct PoolItem {
			var connection : MySQL.Connection
			var connected : Bool
		}
		
		// Parameters
		let count : Int
		var connections : [PoolItem]
		let poolConnection : MySQL.Connection
		
		let dispatchQueue = DispatchQueue(label: "conpoolqueue", attributes: [])
		
		public init(count : Int, connection : MySQL.Connection) throws {
			self.count = count
			self.poolConnection = connection
			
			self.connections = [PoolItem]()
			
			// Init all connections
			for _ in 0..<count {
				let current : Connection = try MySQL.Connection(
					host: poolConnection.host,
					user: poolConnection.user,
					password: poolConnection.password,
					database: poolConnection.database
				)
				
				// Try opening and add the conneciton to the pool
				try current.open()
				connections.append(PoolItem(connection: current, connected: false))
			}
		}
		
		open func getConnection() -> MySQL.Connection? {
			var result : MySQL.Connection? = nil
			
			dispatchQueue.sync {
				// Switch to the first free connection
				for i in 0..<count {
					if !connections[i].connected {
						connections[i].connected = true
						result = connections[i].connection
						break
					}
				}
				
				// If all connections used create a new one
				if (result == nil) {
					let connection = try? MySQL.Connection(
						host: poolConnection.host,
						user: poolConnection.user,
						password: poolConnection.password,
						database: poolConnection.database
					)
					
					// Open
					try? connection?.open()
					
					// Add it the pool
					let item = PoolItem(connection: connection!, connected: false)
					self.connections.append(item)
					
					result = item.connection
				}
			}
			
			return result
		}
		
		open func free(_ connection: MySQL.Connection) {
			// Free connection from id
			dispatchQueue.sync {
				for i in 0..<count {
					if connections[i].connection.id == connection.id {
						connections[i].connected = false
						break
					}
				}
			}
		}
	}
}
