import Foundation
import Socket

public extension MySQL.Connection {
	
	/// Open MySQL connection.
	func open() throws {
		try self.connect()
		try self.sendAuth()
		
		// MySQL connected
		self.isConnected = true
	}
	
	/// Close MySQL connection.
	func close() throws {
		try writeCommandPacket(MysqlCommands.COM_QUIT)
		
		try self.socket.close()
		self.isConnected = false
	}
	
	/// Connect socket to server.
	private func connect() throws {
		// Connect socket to address matching informations provided in init()
		try self.socket.connectAll(infos: socket.getAddressInfos())
		
		// MySQL handshake
		self.mysql_Handshake = try readHandshake()
	}
	
	/// Send authentification data to MySQL server.
	private func sendAuth() throws {
		var encodedPass = [UInt8]()
		var result = [UInt8]()
		
		// Setup flags
		var flags : UInt32 = MysqlClientCaps.CLIENT_PROTOCOL_41 |
			MysqlClientCaps.CLIENT_LONG_PASSWORD |
			MysqlClientCaps.CLIENT_TRANSACTIONS |
			MysqlClientCaps.CLIENT_SECURE_CONN |
			
			MysqlClientCaps.CLIENT_LOCAL_FILES |
			MysqlClientCaps.CLIENT_MULTI_STATEMENTS |
			MysqlClientCaps.CLIENT_MULTI_RESULTS
		flags &= UInt32((mysql_Handshake?.cap_flags)!) | 0xffff0000
		
		// Connect without database
		if database != nil { flags |= MysqlClientCaps.CLIENT_CONNECT_WITH_DB }
		
		// Make sure handhsake is received
		guard mysql_Handshake != nil else {
			throw ConnectionError.wrongHandshake
		}
		
		guard mysql_Handshake!.scramble != nil else {
			throw ConnectionError.wrongHandshake
		}
		
		// Encode with scrambles
		encodedPass = MySQL.Utils.encPasswd(password, scramble: self.mysql_Handshake!.scramble!)
		
		
		// Flags
		result.append(contentsOf: [UInt8].UInt32Array(UInt32(flags)))
		
		// Maximum packet length
		result.append(contentsOf:[UInt8].UInt32Array(MySQL.maxPackAllowed))
		
		result.append(UInt8(33))
		
		result.append(contentsOf: [UInt8](repeating:0, count: 23))
		
		// Username
		result.append(contentsOf: user.utf8)
		result.append(0)
		
		// Hashed password
		result.append(UInt8(encodedPass.count))
		result.append(contentsOf: encodedPass)
		
		// Database
		if database != nil { result.append(contentsOf: database!.utf8) }
		result.append(0)
		
		// MARK: Change mysql_native_password to user defined.
		result.append(contentsOf:"mysql_native_password".utf8)
		result.append(0)
		
		// Send to server
		try socket.sendPacket(header: Packet.header(length: result.count, number: 1), data: result)
		
		// Check is auth is successful
		try checkAuth()
	}
	
	/// Check if authentification is successful from server response.
	func checkAuth() throws {
		let packet : Packet = try socket.recvPacket(headerLength: 3)
		
		switch packet.data[0] {
		case 0x00:
			successPacket(packet.data)
			break
		case 0xfe:
			break
		case 0xff:
			throw errorPacket(packet.data)
		default: break
		}
	}
	
	/// Read received MySQL handshake.
	private func readHandshake() throws -> MySQL.mysql_handshake {
		let packet : Packet = try socket.recvPacket(headerLength: 3)
		var handshake = MySQL.mysql_handshake()
		var pos = 0
			
		handshake.proto_version = packet.data[pos]
		pos += 1
		handshake.server_version = String(cString: packet.data[pos..<packet.data.count].withUnsafeBufferPointer { $0.baseAddress! })
		pos += (handshake.server_version?.utf8.count)! + 1
		handshake.conn_id = packet.data[pos...pos+4].uInt32()
		pos += 4
		handshake.scramble = Array(packet.data[pos..<pos+8])
		pos += 8 + 1
		handshake.cap_flags = packet.data[pos...pos+2].uInt16()
		pos += 2
		
		if packet.data.count > pos {
			pos += 1 + 2 + 2 + 1 + 10
			
			let c = Array(packet.data[pos..<pos+12])
			handshake.scramble?.append(contentsOf:c)
		}
		
		return handshake
	}
	
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



