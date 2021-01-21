//
//  Query.swift
//  mysql_driver
//
//  Created by Marius Corega on 24/12/15.
//  Copyright © 2015 Marius Corega. All rights reserved.
//


import Foundation

public extension MySQL.Connection {
	/// Execute a SQL query.
	func query(_ query : String) throws -> [Result] {
		try writeCommandPacketStr(MysqlCommands.COM_QUERY, query: query)
		
		var results : [Result] = []
		
		repeat {
			// Get result
			let resLen = try resultLength()
			let columns : [Field] = try readColumns(resLen)
			
			results.append(MySQL.TextResult(connection: self, columns: columns))
		}
		while results.last?.hasMoreResults ?? false
		
		return results
	}
	
	/// Prepare a SQL query.
	func prepare(_ query : String) throws -> MySQL.Statement {
		try writeCommandPacketStr(MysqlCommands.COM_STMT_PREPARE, query: query)
		let stmt = MySQL.Statement(connection: self)
		
		// Check number of parameters and columns
		let columnCount = try stmt.readPrepareResultPacket()
		let paramCount = stmt.paramCount
		
		if paramCount > 0 {
			try recvUntilEOF() // Params
		}
		
		if columnCount > 0 {
			try recvUntilEOF() // Columns
		}
		
		return stmt
	}
	
	/// Execute a SQL query.
	func exec(_ query : String) throws {
		try writeCommandPacketStr(MysqlCommands.COM_QUERY, query: query)
		
		// Skip result
		if try resultLength() > 0 {
			try recvUntilEOF() // Columns
			try recvUntilEOF() // Rows
		}
	}
	
	/// Use database.
	func use(_ database : String) throws {
		try writeCommandPacketStr(MysqlCommands.COM_INIT_DB, query: database)
		self.database = database
		
		// Skip result
		if try resultLength() > 0 {
			try recvUntilEOF() // Columns
			try recvUntilEOF() // Rows
		}
	}
}
