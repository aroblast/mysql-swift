extension MySQL.Connection {
	
	func checkResult() throws {
		// If data to read
		if let data = try socket?.readPacket() {
			switch data[0] {
			case 0x00:
				handleSuccessPacket(data)
				break
			case 0xfe:
				break
			case 0xff:
				throw handleErrorPacket(data)
			default: break
			}
		}
	}
	
	/// Handle success packet.
	fileprivate func handleSuccessPacket(_ data:[UInt8]) {
		var n, m : Int
		var affectedRows, insertId : UInt64?
		
		// Affected rows [Length Coded Binary]
		(affectedRows, n) = MySQL.Utils.lenEncInt(Array(data[1...data.count-1]))
		self.affectedRows = affectedRows ?? 0
		
		// Insert id [Length Coded Binary]
		(insertId, m) = MySQL.Utils.lenEncInt(Array(data[1+n...data.count-1]))
		self.insertId = insertId ?? 0
		
		// Save connection status
		status = UInt16(data[1+n+m]) | UInt16(data[1+n+m+1]) << 8
	}
	
	/// Handle error packet.
	func handleErrorPacket(_ data:[UInt8]) -> MySQL.MySQLError {
		// If EOF error
		if data[0] != 0xff {
			return MySQL.MySQLError.error(-1, "EOF encountered")
		}
		
		// Error details
		let errorNumber = data[1...3].uInt16()
		var position = 3
		
		// Get error position
		if data[3] == 0x23 {
			position = 9
		}
		
		var d1 = Array(data[position..<data.count])
		d1.append(0)
		
		let errorString = d1.string()
		
		print("MySQL error #\(errorNumber) - \(errorString!)")
		return MySQL.MySQLError.error(Int(errorNumber), errorString!)
	}
	
	/// Read packets until EOF symbol.
	func readUntilEOF() throws {
		// While data to read
		while let data = try socket?.readPacket() {
			// If EOF
			if data[0] == 0xfe { return }
		}
	}
	
	/// Write command packet and query.
	func writeCommandPacketQuery(_ command : UInt8, query : String) throws {
		socket?.packetsNumber = -1
		
		var data = [UInt8]()
		data.append(command)
		data.append(contentsOf: query.utf8)
		
		try socket?.writePacket(data)
	}
	
	/// Write only command packet.
	func writeCommandPacket(_ command : UInt8) throws {
		socket?.packetsNumber = -1
		
		var data = [UInt8]()
		data.append(command)
		
		try socket?.writePacket(data)
	}
	
	/// Read result length.
	func readResultSetHeaderPacket() throws -> Int {
		EOFfound = false
		
		// If data to read
		if let data = try socket?.readPacket() {
			switch data[0] {
			case 0x00:
				handleSuccessPacket(data)
				return 0
			case 0xff:
				throw handleErrorPacket(data)
			default:
				break
			}
			
			// Count columns
			let (num, n) = MySQL.Utils.lenEncInt(data)
			
			// Check no error
			guard num != nil else {
				return 0
			}
			
			// Return columns count
			if (n - data.count) == 0 {
				return Int(num!)
			}
			
			// If no columns
			return 0
		}
		else {
			// Empty result
			return 0
		}
	}
}
