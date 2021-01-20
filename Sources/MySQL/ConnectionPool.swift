import Foundation

public extension MySQL {
	
	class ConnectionPool {
		
		// Parameters
		let template : Connection
		
		var connections : [Connection] = []
		let dispatchQueue = DispatchQueue(label: "mysql.connection.pool")
		
		public init(connection : MySQL.Connection) {
			self.template = connection
			
			// Init connection
			connections.append(connection)
		}
		
		open func getConnection() -> MySQL.Connection? {
			// Get the first free connection
			for i in 0..<connections.count {
				if (!connections[i].isConnected) {
					return connections[i]
				}
			}
			
			// If all connections are used create a new one
			let connection : Connection = template
			
			// Open
			do {
				try connection.open()
				
				// Add it the pool
				self.connections.append(connection)
				return connection
			}
			catch {
				print("Connection \(connection.id) couldn't be opened")
				return nil
			}
		}
		
		open func free(_ connection: MySQL.Connection) {
			dispatchQueue.sync {
				do {
					try connections.first { $0.id == connection.id }?.close()
				}
				catch {
					print("Connection \(connection.id) couldn't be closed")
				}
			}
		}
	}
}
