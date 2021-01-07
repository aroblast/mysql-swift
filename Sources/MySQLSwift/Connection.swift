import Foundation

public extension MySQL.Connection {
	
	/// Open MySQL connection.
	func open() throws {
		try connect()
		try auth()
		try checkResult()
		
		// Save state
		isConnected = true
	}
	
	/// Close MySQL connection.
	func close() throws {
		try writeCommandPacket(MysqlCommands.COM_QUIT)
		try self.socket?.close()
		self.hasMoreResults = false
		self.EOFfound = true
		self.isConnected = false
	}
	
	/// Read received MySQL handshake.
	private func readHandshake() throws -> MySQL.mysql_handshake {
		var result = MySQL.mysql_handshake()
		
		// If handshake is received
		if let data = try socket?.readPacket() {
			var pos = 0
			result.protoVersion = data[pos]
			pos += 1
			result.serverVersion = data[pos..<data.count].string()
			pos += (result.serverVersion?.utf8.count)! + 1
			result.connectionId = data[pos...pos+4].uInt32()
			pos += 4
			result.scramble = Array(data[pos..<pos+8])
			pos += 8 + 1
			result.capFlags = data[pos...pos+2].uInt16()
			pos += 2
			
			if (data.count > pos) {
				pos += 1 + 2 + 2 + 1 + 10
				
				let c = Array(data[pos..<pos+12])
				result.scramble?.append(contentsOf:c)
			}
		}
		
		return result
	}
	
	/// Connect socket to server.
	private func connect() throws {
		// Setup mysql socket
		socket = try Socket(host: address, port: port)
		try socket?.open()
		
		// Handshake
		self.mysql_Handshake = try readHandshake()
	}
	
	/// Authenticate user in MySQL server.
	private func auth() throws {
		// For binary ops
		var flags : UInt32 =
			MysqlClientCaps.CLIENT_PROTOCOL_41 |
			MysqlClientCaps.CLIENT_LONG_PASSWORD |
			MysqlClientCaps.CLIENT_TRANSACTIONS |
			MysqlClientCaps.CLIENT_SECURE_CONN |
			
			MysqlClientCaps.CLIENT_LOCAL_FILES |
			MysqlClientCaps.CLIENT_MULTI_STATEMENTS |
			MysqlClientCaps.CLIENT_MULTI_RESULTS
		
		// Set flags
		flags &= UInt32((mysql_Handshake?.capFlags)!) | 0xffff0000
		
		// If database is set
		if dbname != nil { flags |= MysqlClientCaps.CLIENT_CONNECT_WITH_DB }
		
		// Encode password
		var encodedPassword = [UInt8]()
		
		guard mysql_Handshake != nil else {
			throw ConnectionError.wrongHandshake
		}
		guard mysql_Handshake!.scramble != nil else {
			throw ConnectionError.wrongHandshake
		}
		
		// Encode with scrambles
		encodedPassword = MySQL.Utils.encPasswd(password, scramble: mysql_Handshake!.scramble!)
		
		// Response
		var reponse = [UInt8]()
		
		// Flags
		reponse.append(contentsOf: [UInt8].UInt32Array(UInt32(flags)))
		
		// Max packet length
		reponse.append(contentsOf: [UInt8].UInt32Array(16777215))
		reponse.append(UInt8(33))
		
		reponse.append(contentsOf:[UInt8](repeating:0, count: 23))
		
		// Username
		reponse.append(contentsOf: user.utf8)
		reponse.append(0)
		
		// Password
		reponse.append(UInt8(encodedPassword.count))
		reponse.append(contentsOf: encodedPassword)
		
		// If connect with db
		if (self.dbname != nil) {
			reponse.append(contentsOf:self.dbname!.utf8)
		}
		reponse.append(0)
		
		// MARK: Change mysql_native_password to user defined.
		reponse.append(contentsOf: "mysql_native_password".utf8)
		reponse.append(0)
		
		try socket?.writePacket(reponse)
	}
	
	
	// Structure
	
	/// Read columns from socket response.
	func readColumns(_ count : Int) throws -> [Field]? {
		// Empty columns
		columns = [Field](repeating:Field(), count: count)
		
		if (count > 0) {
			var i = 0
			while true {
				if let data = try socket?.readPacket() {
					
					//EOF Packet
					if (data[0] == 0xfe) && ((data.count == 5) || (data.count == 1)) {
						return columns
					}
					
					//Catalog
					var pos = MySQL.Utils.skipLenEncStr(data)
					
					// Database [len coded string]
					var n = MySQL.Utils.skipLenEncStr(Array(data[pos..<data.count]))
					pos += n
					
					// Table [len coded string]
					n = MySQL.Utils.skipLenEncStr(Array(data[pos..<data.count]))
					pos += n
					
					// Original table [len coded string]
					n = MySQL.Utils.skipLenEncStr(Array(data[pos..<data.count]))
					pos += n
					
					// Name [len coded string]
					var name :String?
					(name, n) = MySQL.Utils.lenEncStr(Array(data[pos..<data.count]))
					columns![i].name = name ?? ""
					pos += n
					
					// Original name [len coded string]
					(name,n) = MySQL.Utils.lenEncStr(Array(data[pos..<data.count]))
					columns![i].origName = name ?? ""
					pos += n
					
					// Filler [uint8]
					pos +=  1
					// Charset [charset, collation uint8]
					columns![i].charSetNr = data[pos]
					columns![i].collation = data[pos + 1]
					// Length [uint32]
					pos +=  2 + 4
					
					// Field type [uint8]
					columns![i].fieldType = data[pos]
					pos += 1
					
					// Flags [uint16]
					columns![i].flags = data[pos...pos+1].uInt16()
					pos += 2
					
					// Decimals [uint8]
					columns![i].decimals = data[pos]
				}
				
				i += 1
			}
		}
		
		return columns
	}
	
	// Enums
	enum ConnectionError : Error {
		case addressNotSet
		case usernameNotSet
		case notConnected
		case statementPrepareError(String)
		case dataReadingError
		case queryInProgress
		case wrongHandshake
	}
}



