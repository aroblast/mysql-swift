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
