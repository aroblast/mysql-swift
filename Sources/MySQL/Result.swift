import Foundation
import Socket

public protocol Result {
	var EOFfound : Bool { get }
	var hasMoreResults : Bool { get }

	func readRow() throws -> MySQL.Row?
	func readAllRows() throws -> [MySQL.Row]?
}

extension MySQL {

	public class Row : Identifiable {
		public let id : UUID = UUID()
		public var values : [String : Any] = [:]
		public var stringValues : [String : String?] = [:]

		public init() {}
	}
	
	/// Row composed of human-readable values.
	class TextResult : Result {
		let columns : [Field]
		let connection : Connection
		
		var EOFfound : Bool = false
		var hasMoreResults : Bool = false
		
		required init(connection : Connection, columns : [Field]) {
			self.connection = connection
			self.columns = columns
		}
		
		/// Read current row.
		func readRow() throws -> Row? {
			// If no columns
			if columns.count == 0 {
				hasMoreResults = false
				EOFfound = true
			}
			
			if (!EOFfound && columns.count > 0) {
				// Get result packet
				let packet : Packet = try connection.socket.recvPacket(headerLength: 3)
				
				// Check if last packet
				if (packet.data[0] == 0xfe) && (packet.data.count == 5) {
					EOFfound = true
					
					// Check if more results exist
					let flags = Array(packet.data[3..<5]).uInt16()
					hasMoreResults = (flags & MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS) == MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS
					
					return nil
				}
				
				// Check no error packet
				if packet.data[0] == 0xff {
					throw connection.errorPacket(packet.data)
				}
				
				let row = Row()
				var pos = 0
				
				// For each column
				for column in columns {
					// Get row column value
					let (value, n) = MySQL.Utils.lenEncStr(Array(packet.data[pos..<packet.data.count]))
					pos += n
					
					// If value not nil
					if (value != nil) {
						// Save string value
						row.stringValues[column.name] = value

						switch column.fieldType {
						case MysqlTypes.MYSQL_TYPE_VAR_STRING:
							row.values[column.name] = value
							break
							
						case MysqlTypes.MYSQL_TYPE_LONGLONG:
							// Unsigned
							if column.flags & MysqlFieldFlag.UNSIGNED == MysqlFieldFlag.UNSIGNED {
								row.values[column.name] = UInt64(value!)
								break
							}
							
							row.values[column.name] = Int64(value!)
							break
							
						case MysqlTypes.MYSQL_TYPE_LONG, MysqlTypes.MYSQL_TYPE_INT24:
							// Unsigned
							if column.flags & MysqlFieldFlag.UNSIGNED == MysqlFieldFlag.UNSIGNED {
								row.values[column.name] = UInt(value!)
								break
							}
							
							row.values[column.name] = Int(value!)
							break
							
						case MysqlTypes.MYSQL_TYPE_SHORT:
							// Unsigned
							if column.flags & MysqlFieldFlag.UNSIGNED == MysqlFieldFlag.UNSIGNED {
								row.values[column.name] = UInt16(value!)
								break
							}
							
							row.values[column.name] = Int16(value!)
							break
							
						case MysqlTypes.MYSQL_TYPE_TINY:
							// Unsigned
							if column.flags & MysqlFieldFlag.UNSIGNED == MysqlFieldFlag.UNSIGNED {
								row.values[column.name] = UInt8(value!)
								break
							}
							
							row.values[column.name] = Int8(value!)
							break
							
						case MysqlTypes.MYSQL_TYPE_DOUBLE:
							row.values[column.name] = Double(value!)
							break
							
						case MysqlTypes.MYSQL_TYPE_FLOAT:
							row.values[column.name] = Float(value!)
							break
							
						case MysqlTypes.MYSQL_TYPE_DATE:
							// MARK: Custom made conversion
							row.values[column.name] = Date(dateString: String(value!))
							break
							
						case MysqlTypes.MYSQL_TYPE_TIME:
							// MARK: Custom made conversion
							row.values[column.name] = Date(timeString: String(value!))
							break
							
						case MysqlTypes.MYSQL_TYPE_DATETIME:
							// MARK: Custom made conversion
							row.values[column.name] = Date(dateTimeString: String(value!))
							break
							
						case MysqlTypes.MYSQL_TYPE_TIMESTAMP:
							// MARK: Custom made conversion
							row.values[column.name] = Date(dateTimeString: String(value!))
							break
							
						case MysqlTypes.MYSQL_TYPE_NULL:
							row.values[column.name] = NSNull()
							break
							
						default:
							// MARK: Default conversion to nil
							row.values[column.name] = NSNull()
							break
						}
					}
					else {
						row.values[column.name] = NSNull()
					}
				}
				
				return row
			}
			else {
				return nil
			}
		}
		
		func readAllRows() throws -> [Row]? {
			var result = [Row]()
			
			// While row exists
			while let row = try readRow() {
				result.append(row)
			}
			
			return result
		}
	}
	
	class BinaryResult : Result {
		var columns : [Field]
		var connection: Connection
		
		var EOFfound : Bool = false
		var hasMoreResults : Bool = false
		
		required init(connection : Connection, columns : [Field]) {
			self.connection = connection
			self.columns = columns
		}
		
		func readRow() throws -> MySQL.Row?{
			if columns.count == 0 {
				hasMoreResults = false
				EOFfound = true
			}
			
			if !EOFfound, columns.count > 0 {
				let packet : Packet = try connection.socket.recvPacket(headerLength: 3)
				
				// Success packet
				if packet.data[0] != 0x00 {
					// EOF Packet
					if (packet.data[0] == 0xfe) && (packet.data.count == 5) {
						EOFfound = true
						
						// Check if more results exist
						let flags = Array(packet.data[3..<5]).uInt16()
						hasMoreResults = (flags & MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS) == MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS
						
						return nil
					}
					
					// Error packet
					if packet.data[0] == 0xff {
						throw connection.errorPacket(packet.data)
					}
					
					if packet.data[0] > 0 && packet.data[0] < 251 {
						// Result set header packet
					}
					else {
						return nil
					}
				}
				
				var pos = 1 + (columns.count + 7 + 2)>>3
				let nullBitmap = Array(packet.data[1..<pos])
				let row = Row()
				
				for i in 0..<columns.count {
					
					let idx = (i+2)>>3
					let shiftval = UInt8((i+2)&7)
					let val = nullBitmap[idx] >> shiftval
					
					if (val & 1) == 1 {
						row.values[columns[i].name] = NSNull()
						continue
					}
					
					switch columns[i].fieldType {
					
					case MysqlTypes.MYSQL_TYPE_NULL:
						row.values[columns[i].name] = NSNull()
						break
						
					case MysqlTypes.MYSQL_TYPE_TINY:
						if columns[i].flags & MysqlFieldFlag.UNSIGNED == MysqlFieldFlag.UNSIGNED {
							row.values[columns[i].name] = UInt8(packet.data[pos..<pos+1])
							pos += 1
							break
						}
						row.values[columns[i].name] = Int8(packet.data[pos..<pos+1])
						
						pos += 1
						break
						
					case MysqlTypes.MYSQL_TYPE_SHORT:
						if columns[i].flags & MysqlFieldFlag.UNSIGNED == MysqlFieldFlag.UNSIGNED {
							row.values[columns[i].name] = UInt16(packet.data[pos..<pos+2])
							pos += 2
							break
						}
						row.values[columns[i].name] = Int16(packet.data[pos..<pos+2])
						
						pos += 2
						break
						
					case MysqlTypes.MYSQL_TYPE_INT24, MysqlTypes.MYSQL_TYPE_LONG:
						if columns[i].flags & MysqlFieldFlag.UNSIGNED == MysqlFieldFlag.UNSIGNED {
							row.values[columns[i].name] = UInt(UInt32(packet.data[pos..<pos+4]))
							pos += 4
							break
						}
						row.values[columns[i].name] = Int(Int32(packet.data[pos..<pos+4]))
						
						pos += 4
						break
						
					case MysqlTypes.MYSQL_TYPE_LONGLONG:
						if columns[i].flags & MysqlFieldFlag.UNSIGNED == MysqlFieldFlag.UNSIGNED {
							row.values[columns[i].name] = UInt64(packet.data[pos..<pos+8])
							pos += 8
							break
						}
						row.values[columns[i].name] = Int64(packet.data[pos..<pos+8])
						
						pos += 8
						break
						
					case MysqlTypes.MYSQL_TYPE_FLOAT:
						row.values[columns[i].name] = packet.data[pos..<pos+4].float32()
						pos += 4
						break
						
					case MysqlTypes.MYSQL_TYPE_DOUBLE:
						row.values[columns[i].name] = packet.data[pos..<pos+8].float64()
						pos += 8
						break
						
					case MysqlTypes.MYSQL_TYPE_TINY_BLOB, MysqlTypes.MYSQL_TYPE_MEDIUM_BLOB, MysqlTypes.MYSQL_TYPE_VARCHAR,
							 MysqlTypes.MYSQL_TYPE_VAR_STRING, MysqlTypes.MYSQL_TYPE_STRING, MysqlTypes.MYSQL_TYPE_LONG_BLOB,
							 MysqlTypes.MYSQL_TYPE_BLOB:
						
						if columns[i].charSetNr == 63 {
							let (bres, n) = MySQL.Utils.lenEncBin(Array(packet.data[pos..<packet.data.count]))
							row.values[columns[i].name] = bres
							pos += n
							
						}
						else {
							let (str, n) = MySQL.Utils.lenEncStr(Array(packet.data[pos..<packet.data.count]))
							row.values[columns[i].name] = str
							pos += n
						}
						break
						
					case MysqlTypes.MYSQL_TYPE_DECIMAL, MysqlTypes.MYSQL_TYPE_NEWDECIMAL,
							 MysqlTypes.MYSQL_TYPE_BIT, MysqlTypes.MYSQL_TYPE_ENUM, MysqlTypes.MYSQL_TYPE_SET,
							 MysqlTypes.MYSQL_TYPE_GEOMETRY:
						
						let (str, n) = MySQL.Utils.lenEncStr(Array(packet.data[pos..<packet.data.count]))
						row.values[columns[i].name] = str
						pos += n
						break
						
					case MysqlTypes.MYSQL_TYPE_DATE:
						let (dlen, n) = MySQL.Utils.lenEncInt(Array(packet.data[pos..<packet.data.count]))
						
						guard dlen != nil else {
							row.values[columns[i].name] = NSNull()
							break
						}
						var y = 0, mo = 0, d = 0
						var res : Date?
						
						switch Int(dlen!) {
						case 11:
							// 2015-12-02 12:03:15.000 001
							fallthrough
						case 7:
							// 2015-12-02 12:03:15
							fallthrough
						case 4:
							// 2015-12-02
							y = Int(packet.data[pos+1..<pos+3].uInt16())
							mo = Int(packet.data[pos+3])
							d = Int(packet.data[pos+4])
							res = Date(dateString: String(format: "%4d-%02d-%02d", arguments: [y, mo, d]))
							break
						default:break
						}
						
						row.values[columns[i].name] = res ?? NSNull()
						pos += n + Int(dlen!)
						
						break
						
					case MysqlTypes.MYSQL_TYPE_TIME:
						let (dlen, n) = MySQL.Utils.lenEncInt(Array(packet.data[pos..<packet.data.count]))
						
						guard dlen != nil else {
							row.values[columns[i].name] = NSNull()
							break
						}
						var h = 0, m = 0, s = 0, u = 0
						var res : Date?
						
						switch Int(dlen!) {
						case 12:
							//12:03:15.000 001
							u = Int(packet.data[pos+9..<pos+13].uInt32())
							fallthrough
						case 8:
							//12:03:15
							h = Int(packet.data[pos+6])
							m = Int(packet.data[pos+7])
							s = Int(packet.data[pos+8])
							res = Date(timeStringUsec:String(format: "%02d:%02d:%02d.%06d", arguments: [h, m, s, u]))
							break
						default:
							res = Date(timeString: "00:00:00")
							break
						}
						
						row.values[columns[i].name] = res ?? NSNull()
						pos += n + Int(dlen!)
						
						break
						
					case MysqlTypes.MYSQL_TYPE_TIMESTAMP, MysqlTypes.MYSQL_TYPE_DATETIME:
						let (dlen, n) = MySQL.Utils.lenEncInt(Array(packet.data[pos..<packet.data.count]))
						
						guard dlen != nil else {
							row.values[columns[i].name] = NSNull()
							break
						}
						
						var y = 0, mo = 0, d = 0, h = 0, m = 0, s = 0, u = 0
						
						switch Int(dlen!) {
						case 11:
							u = Int(packet.data[pos+8..<pos+12].uInt32())
							fallthrough
						case 7:
							// 2015-12-02 12:03:15
							h = Int(packet.data[pos+5])
							m = Int(packet.data[pos+6])
							s = Int(packet.data[pos+7])
							fallthrough
						case 4:
							// 2015-12-02
							y = Int(packet.data[pos+1..<pos+3].uInt16())
							mo = Int(packet.data[pos+3])
							d = Int(packet.data[pos+4])
							break
							
						default:break
						}
						
						let dstr = String(format: "%4d-%02d-%02d %02d:%02d:%02d.%06d", arguments: [y, mo, d, h, m, s, u])
						row.values[columns[i].name] = Date(dateTimeStringUsec: dstr) ?? NSNull()
						
						pos += n + Int(dlen!)
						break
					default:
						row.values[columns[i].name] = NSNull()
						break
					}
					
				}
				return row
			}
			
			return nil
		}
		
		func readAllRows() throws -> [Row]? {
			var result = [Row]()
			
			// For each result
			while let row = try readRow() {
				result.append(row)
			}
			
			return result
		}
	}
}
