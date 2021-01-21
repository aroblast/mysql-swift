import Foundation
import Socket

struct Packet {
	let header : Header
	let data : [UInt8]
}

struct Header {
	var length : UInt32
	let sequence : UInt8
	
	init(_ array : [UInt8]) {
		var lengthArray : [UInt8] = []
		
		// Add 0 for 4 bytes length
		lengthArray.append(contentsOf: array[0..<3])
		lengthArray.append(0)
		
		self.length = UInt32(littleEndian: lengthArray.withUnsafeBytes { $0.load(as: UInt32.self) })
		self.sequence = array[3]
	}
	
	init(length : UInt32, sequence : UInt8) {
		self.length = length
		self.sequence = sequence
	}
	
	func encode() -> [UInt8] {
		var result : [UInt8] = Array(byteArray(from: length.bigEndian)[0..<3])
		result.append(sequence)
		
		return result
	}
}

extension MySQL.Connection {
	/// Handle a success packet returned by socket.
	func successPacket(_ data : [UInt8]) {
		var n, m : Int
		var ar, insId : UInt64?
		
		(ar, n) = MySQL.Utils.lenEncInt(Array(data[1...data.count-1]))
		self.affectedRows = ar ?? 0
		
		// Insert id [Length Coded Binary]
		(insId, m) = MySQL.Utils.lenEncInt(Array(data[1+n...data.count-1]))
		self.insertId = insId ?? 0
		
		self.status = UInt16(data[1+n+m]) | UInt16(data[1+n+m+1]) << 8
	}
	
	/// Handle an error packet returned by socket.
	func errorPacket(_ data : [UInt8]) -> MySQL.MySQLError {
		// Check not EOF
		guard data[0] == 0xff else { return MySQL.MySQLError.error(-1, "EOF encountered") }
		
		// Get errno and details
		let errno = data[1...3].uInt16()
		var pos = 3
		
		if data[3] == 0x23 {
			pos = 9
		}
		
		// Error details string
		var errorCStr = Array(data[pos..<data.count])
		errorCStr.append(0)
		print("MySQL error #\(errno): \(errorCStr)")
		
		return MySQL.MySQLError.error(Int(errno), String(cString: errorCStr))
	}
	
	/// Read packets data until EOF.
	func recvUntilEOF() throws {
		while true {
			// Check for EOF
			if try socket.readPacket().data[0] == 0xfe { return }
		}
	}
	
	/// Write command and query to socket.
	func writeCommandPacketStr(_ cmd : UInt8, query : String) throws {
		var data = [UInt8]()
		
		data.append(cmd)
		data.append(contentsOf: query.utf8)
		
		// Send header and data
		try socket.writeData(data: Header(length: UInt32(data.count), sequence: 0).encode())
		try socket.writeData(data: data)
	}
	
	/// Write command only to socket.
	func writeCommandPacket(_ cmd : UInt8) throws {
		var data = [UInt8]()
		
		data.append(cmd)
		
		try socket.writePacket(
			Packet(
				header: Header(
					length: UInt32(data.count),
					sequence: 0),
				
				data: data
			)
		)
	}
	
	/// Read result length.
	func resultLength() throws ->Int {
		let data : [UInt8] = try socket.readPacket().data
		
		switch data[0] {
		case 0x00:
			successPacket(data)
			return 0
		case 0xff:
			throw errorPacket(data)
		default:break
		}
		
		// Column count
		let (num, n) = MySQL.Utils.lenEncInt(data)
		
		// Check no error
		guard num != nil else {
			return 0
		}
		
		// Return columns count
		if (n - data.count) == 0 {
			return Int(num!)
		}
		else {
			return 0
		}
	}
	
	/// Read columns from MySQL response.
	func readColumns(_ count : Int) throws -> [Field] {
		var columns : [Field] = [Field](repeating: Field(), count: count)
		
		if count > 0 {
			var i = 0
			while true {
				let packet : Packet = try socket.readPacket()
				
				// EOF Packet
				if (packet.data[0] == 0xfe) && ((packet.data.count == 5) || (packet.data.count == 1)) {
					return columns
				}
				
				// Catalog
				var pos = MySQL.Utils.skipLenEncStr(packet.data)
				
				// Database [len coded string]
				var n = MySQL.Utils.skipLenEncStr(Array(packet.data[pos..<packet.data.count]))
				pos += n
				
				// Table [len coded string]
				n = MySQL.Utils.skipLenEncStr(Array(packet.data[pos..<packet.data.count]))
				pos += n
				
				// Original table [len coded string]
				n = MySQL.Utils.skipLenEncStr(Array(packet.data[pos..<packet.data.count]))
				pos += n
				
				// Name [len coded string]
				var name : String?
				(name, n) = MySQL.Utils.lenEncStr(Array(packet.data[pos..<packet.data.count]))
				columns[i].name = name ?? ""
				pos += n
				
				// Original name [len coded string]
				(name,n) = MySQL.Utils.lenEncStr(Array(packet.data[pos..<packet.data.count]))
				columns[i].origName = name ?? ""
				pos += n
				
				// Filler [uint8]
				pos +=  1
				// Charset [charset, collation uint8]
				columns[i].charSetNr = packet.data[pos]
				columns[i].collation = packet.data[pos + 1]
				// Length [uint32]
				pos +=  2 + 4
				
				// Field type [uint8]
				columns[i].fieldType = packet.data[pos]
				pos += 1
				
				// Flags [uint16]
				columns[i].flags = packet.data[pos...pos+1].uInt16()
				pos += 2
				
				// Decimals [uint8]
				columns[i].decimals = packet.data[pos]
				
				i += 1
			}
		}
		
		return columns
	}
}
