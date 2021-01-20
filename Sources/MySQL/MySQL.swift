import Foundation
import Socket

public struct Field {
	public var name : String = ""
	public var fieldType : UInt8 = 0
	
	var tableName : String = ""
	var flags : UInt16 = 0
	var decimals : UInt8 = 0
	var origName : String = ""
	var charSetNr : UInt8 = 0
	var collation : UInt8 = 0
}

public struct MySQL {
	
	// Max packets allowed
	static let maxPackAllowed : UInt32 = 16777215
	
	public class Connection : Identifiable {
		public let id : UUID = UUID()
		
		var host : String
		var user : String
		var password : String
		var database : String?
		var port : UInt16
		
		var status : UInt16 = 0
		var affectedRows : UInt64 = 0
		public var insertId : UInt64 = 0
		
		// Network
		var socket : Socket
		var mysql_Handshake: mysql_handshake?
		
		public var isConnected = false
		
		public init(host : String, user : String, password : String = "", database : String? = nil, port : Int = 3306) throws {
			self.host = host
			self.user = user
			self.password = password
			self.database = database
			self.port = UInt16(port)
			
			self.socket = try Socket(
				host: host,
				port: UInt16(port),
				
				addressFamily: AF_INET,
				socketType: SOCK_STREAM,
				socketProtocol: 0
			)
			
			// Setup options
			var value : Int = 1
			try socket.setOption(level: SOL_SOCKET, option: SO_REUSEADDR, value: &value, length: socklen_t(MemoryLayout<Int32>.size))
			try socket.setOption(level: SOL_SOCKET, option: SO_KEEPALIVE, value: &value, length: socklen_t(MemoryLayout<Int32>.size))
			try socket.setOption(level: SOL_SOCKET, option: SO_NOSIGPIPE, value: &value, length: socklen_t(MemoryLayout<Int32>.size))
		}
	}
	
	struct mysql_handshake {
		var proto_version:UInt8?
		var server_version:String?
		var conn_id:UInt32?
		var scramble:[UInt8]?
		var cap_flags:UInt16?
		var lang:UInt8?
		var status:UInt16?
		var scramble2:[UInt8]?
	}
	
	public enum MySQLError : Error {
		case error(Int, String)
	}
}
