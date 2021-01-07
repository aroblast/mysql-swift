import Foundation

public extension MySQL.Connection {
	
	class QueryResult {
		
		var rows : MySQL.ResultSet?
		var successClosure : ((_ rows : MySQL.ResultSet)->Void) = { _ in }
		var errorClosure : ((_ error : Error)->Void) = { _ in }
		
		init() {}
		init(
			result : MySQL.ResultSet,
			success : @escaping (_ rows : MySQL.ResultSet) -> Void = { _ in },
			error : @escaping (_ error : Error) -> Void = { _ in }
		) {
			rows = result
			
			// Set error and success closures
			self.successClosure = success
			self.errorClosure = error
		}
	}
	
	/// Execute a SQL query.
	func query(_ query : String) throws -> Result {
		try writeCommandPacketQuery(MysqlCommands.COM_QUERY, query: query)
		
		let resultLength = try readResultSetHeaderPacket()
		columns = try readColumns(resultLength)
		
		return MySQL.TextRow(connection: self)
	}
	
	/// Get next result to Result instance.
	func nextResult() throws {
		let resLen = try readResultSetHeaderPacket()
		columns = try readColumns(resLen)
	}
	
	/// Prepare a SQL query.
	func prepare(_ query : String) throws -> MySQL.Statement {
		// Check if connected
		guard socket != nil else {
			throw MySQL.Connection.ConnectionError.notConnected
		}
		
		// Send PREPARE query
		try writeCommandPacketQuery(MysqlCommands.COM_STMT_PREPARE, query: query)
		let stmt = MySQL.Statement(connection: self)
		
		// Get result from statement
		if let columnsCount = try stmt.readPrepareResultPacket(), let parametersCount = stmt.paramCount {
			if parametersCount > 0 {
				// MARK: User parameters count.
				try readUntilEOF()
			}
			
			if columnsCount > 0 {
				// MARK: User columns count.
				try readUntilEOF()
			}
		}
		else {
			throw MySQL.Connection.ConnectionError.statementPrepareError("Could not get columns and parameters count.")
		}
		
		return stmt
	}
	
	/// Execute a SQL query.
	func exec(_ query : String) throws {
		try writeCommandPacketQuery(MysqlCommands.COM_QUERY, query: query)
		
		let resLen = try readResultSetHeaderPacket()
		
		if resLen > 0 {
			try readUntilEOF()
			// MARK: Duplicate code?
			//try readUntilEOF()
		}
	}
	
	/// Use a database for queries.
	func use(_ database : String) throws {
		try writeCommandPacketQuery(MysqlCommands.COM_INIT_DB, query: database)
		self.database = database
		
		let resLen = try readResultSetHeaderPacket()
		
		if resLen > 0 {
			try readUntilEOF()
			// MARK: Duplicate code?
			//try readUntilEOF()
		}
	}
	
	// Enums
	enum QueryResultType {
		case success(MySQL.ResultSet)
		case error(Error)
	}
}
