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
			host: "eu-cdbr-west-03.cleardb.net",
			user: "b1eadad858e1b1",
			password: "ab3498f5",
			database: "heroku_9d423e70da80c12"
		)
	}
	
	override func tearDownWithError() throws {
		// Close connection
		try connection!.close()
	}
	
	// Statements
	func testExec() throws {
		try connection!.open()
		try connection!.exec("DESCRIBE users")
	}
	
	func testQuery() throws {
		try connection!.open()
		let result = try connection!.query("SELECT * FROM users")
		
		for row in result.first?.rows ?? [] {
			print(row)
		}
	}
	
	func testQueryMultipleResults() throws {
		try connection!.open()
		let results = try connection!.query("SELECT * FROM users; SELECT * FROM projects")
		
		for result in results {
			// Display rows
			for row in result.rows {
				print(row)
			}
		}
	}
	
	func testPrepareNoArgs() throws {
		try connection!.open()
		let stmt : MySQL.Statement = try connection!.prepare("SELECT * FROM users")
		let result : Result = try stmt.query([])
		
		for row in result.rows {
			print(row)
		}
	}
	
	func testPrepareArgs() throws {
		try connection!.open()
		let stmt : MySQL.Statement = try connection!.prepare("SELECT SQRT(POW(?,2) + POW(?,2)) AS hypotenuse")
		let result : Result = try stmt.query(["1", "2"])
		
		for row in result.rows {
			print(row)
		}
	}
	
	func testLoop() throws {
		try connection!.open()
		
		try connection!.query("SELECT * FROM users")
		print("REQUEST 0")
		
		DispatchQueue(label: "test").sync { [self] in
			sleep(60)
			
			do {
				try connection!.query("SELECT * FROM users")
				print("REQUEST 1")
			}
			catch {
				print(error)
			}
		}
	}
}
