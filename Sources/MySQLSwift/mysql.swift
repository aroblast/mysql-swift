import Foundation

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
	static let maxPackAllowed = 16777215
	
	struct mysql_handshake {
		var protoVersion : UInt8?
		var serverVersion : String?
		var connectionId : UInt32?
		var scramble : [UInt8]?
		var capFlags : UInt16?
		var language : UInt8?
		var status : UInt16?
		var scramble2 : [UInt8]?
	}
	
	public enum MySQLError : Error {
		case error(Int, String)
	}
	
	open class Connection : Identifiable {
		public let id : UUID = UUID()
		
		var address : String
		var user : String
		var password : String
		var dbname : String?
		var port : Int
		
		var affectedRows : UInt64 = 0
		open var insertId : UInt64 = 0
		var status : UInt16 = 0
		
		// Network
		var socket : Socket?
		var mysql_Handshake : mysql_handshake?
		
		open var columns : [Field]?
		var hasMoreResults = false
		var EOFfound = true
		
		open var isConnected = false
		
		public init(address : String, user : String, password : String, dbname : String? = nil, port : Int = 3306) throws {
			self.address = address
			self.user = user
			self.password = password
			self.dbname = dbname
			self.port = port
		}
	}
}
