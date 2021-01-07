//
//  MySQLSwiftTest.swift
//  MySQLSwiftTest
//
//  Created by Bastien LE CORRE on 2021-01-07.
//

import XCTest
import MySQL

class MySQLSwiftTest : XCTestCase {
	
	var connection : MySQL.Connection? = nil
	
	override func setUpWithError() throws {
		// Create connection
		connection = try MySQL.Connection(
			address: "eu-cdbr-west-03.cleardb.net",
			user: "b1eadad858e1b1",
			password: "ab3498f5",
			database: "heroku_9d423e70da80c12"
		)
	}
	
	override func tearDownWithError() throws {
		// Close connection
		try connection!.close()
	}
	
	// Connection
	func testConnect() throws {
		// Open connection
		try connection!.open()
		return
	}
	
	// Statements
	func testStatementQuery() throws {
		let stmt : MySQL.Statement = try connection!.prepare("SELECT * FROM ?")
		try stmt.exec(["users"])
	}
}
