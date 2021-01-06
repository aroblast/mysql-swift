import Foundation

public protocol Result {
	init(connection : MySQL.Connection)
	
	func readRow() throws -> MySQL.Row?
	func readAllRows() throws -> [MySQL.ResultSet]?
}

public protocol RowType {
	init(dict : MySQL.Row)
}

extension MySQL {
	public typealias Row = [String:Any]
	public typealias ResultSet = [Row]
	
	/// Row composed of human-readable values.
	class TextRow: Result {
		var connection : Connection
		
		required init(connection : Connection) {
			self.connection = connection
		}
		
		/// Read current row.
		func readRow() throws -> MySQL.Row?{
			// Check if socket is connected
			guard connection.isConnected == true else {
				throw Connection.ConnectionError.notConnected
			}
			
			// If columns have no results
			if connection.columns?.count == 0 {
				connection.hasMoreResults = false
				connection.EOFfound = true
				
				return nil
			}
			
			// If not EOF
			if !connection.EOFfound, let columns = connection.columns, columns.count > 0, let data = try connection.socket?.readPacket()  {
				// EOF packet
				if (data[0] == 0xfe) && (data.count == 5) {
					connection.EOFfound = true
					let flags = Array(data[3..<5]).uInt16()
					
					if ((flags & MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS) == MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS) {
						connection.hasMoreResults = true
					}
					else {
						connection.hasMoreResults = false
					}
					
					return nil
				}
				
				// Error packet
				if data[0] == 0xff {
					throw connection.handleErrorPacket(data)
				}
				
				var row = Row()
				var pos = 0
				
				// For each column
				if columns.count > 0 {
					for i in 0..<columns.count {
						let (name, n) = MySQL.Utils.lenEncStr(Array(data[pos..<data.count]))
						pos += n
						
						// Read and interpret type for value
						if let val = name {
							switch columns[i].fieldType {
							case MysqlTypes.MYSQL_TYPE_VAR_STRING:
								row[columns[i].name] = name
								break
								
							case MysqlTypes.MYSQL_TYPE_LONGLONG:
								if ((columns[i].flags & MysqlFieldFlag.UNSIGNED) == MysqlFieldFlag.UNSIGNED) {
									row[columns[i].name] = UInt64(val)
									break
								}
								
								row[columns[i].name] = Int64(val)
								break
								
								
							case MysqlTypes.MYSQL_TYPE_LONG, MysqlTypes.MYSQL_TYPE_INT24:
								if ((columns[i].flags & MysqlFieldFlag.UNSIGNED) == MysqlFieldFlag.UNSIGNED) {
									row[columns[i].name] = UInt(val)
									break
								}
								
								row[columns[i].name] = Int(val)
								break
								
							case MysqlTypes.MYSQL_TYPE_SHORT:
								if ((columns[i].flags & MysqlFieldFlag.UNSIGNED) == MysqlFieldFlag.UNSIGNED) {
									row[columns[i].name] = UInt16(val)
									break
								}
								row[columns[i].name] = Int16(val)
								break
								
							case MysqlTypes.MYSQL_TYPE_TINY:
								if ((columns[i].flags & MysqlFieldFlag.UNSIGNED) == MysqlFieldFlag.UNSIGNED) {
									row[columns[i].name] = UInt8(val)
									break
								}
								
								row[columns[i].name] = Int8(val)
								break
								
								
							case MysqlTypes.MYSQL_TYPE_DOUBLE:
								row[columns[i].name] = Double(val)
								break
								
							case MysqlTypes.MYSQL_TYPE_FLOAT:
								row[columns[i].name] = Float(val)
								break
								
							case MysqlTypes.MYSQL_TYPE_DATE:
								row[columns[i].name] = Date(dateString: String(val))
								break
								
							case MysqlTypes.MYSQL_TYPE_TIME:
								row[columns[i].name] = Date(timeString: String(val))
								break
								
							case MysqlTypes.MYSQL_TYPE_DATETIME:
								row[columns[i].name] = Date(dateTimeString: String(val))
								break
								
							case MysqlTypes.MYSQL_TYPE_TIMESTAMP:
								
								row[columns[i].name] = Date(dateTimeString: String(val))
								break
								
							case MysqlTypes.MYSQL_TYPE_NULL:
								row[columns[i].name] = NSNull()
								break
								
							default:
								row[columns[i].name] = NSNull()
								break
							}
						}
						else {
							row[columns[i].name] = NSNull()
						}
					}
				}
				
				return row
			}
			else {
				return nil
			}
		}
		
		/// Read all rows.
		func readAllRows() throws -> [ResultSet]? {
			var result = [ResultSet]()
			
			repeat {
				// If more results exists
				if connection.hasMoreResults {
					try connection.nextResult()
				}
				
				// Read row
				var rows = ResultSet()
				while let row = try readRow() {
					rows.append(row)
				}
				
				// If row not empty
				if (rows.count > 0){
					result.append(rows)
				}
				
			} while connection.hasMoreResults
			
			return result
		}
	}
	
	/// Row composed of binary values.
	class BinaryRow: Result {
		fileprivate var connection : Connection
		
		required init(connection : Connection) {
			self.connection = connection
		}
		
		/// Read current row.
		func readRow() throws -> MySQL.Row?{
			// Check if socket is connected
			guard connection.isConnected == true else {
				throw Connection.ConnectionError.notConnected
			}
			
			// If columns have no results
			if connection.columns?.count == 0 {
				connection.hasMoreResults = false
				connection.EOFfound = true
			}
			
			// If not EOF
			if !connection.EOFfound, let columns = connection.columns, columns.count > 0, let data = try connection.socket?.readPacket() {
				// Success packet
				if data[0] != 0x00 {
					// EOF Packet
					if (data[0] == 0xfe) && (data.count == 5) {
						connection.EOFfound = true
						let flags = Array(data[3..<5]).uInt16()
						
						if flags & MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS == MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS {
							connection.hasMoreResults = true
						}
						else {
							connection.hasMoreResults = false
						}
						
						return nil
					}
					
					// Error packet
					if data[0] == 0xff {
						throw connection.handleErrorPacket(data)
					}
					
					if (data[0] > 0 && data[0] < 251) {
						// MARK: Result set header packet.
						//Utils.le
					}
					else {
						return nil
					}
					
				}
				
				var pos = 1 + (columns.count + 7 + 2)>>3
				let nullBitmap = Array(data[1..<pos])
				var row = Row()
				
				// For each column
				for i in 0..<columns.count {
					let idx = (i+2)>>3
					let shiftval = UInt8((i+2)&7)
					let val = nullBitmap[idx] >> shiftval
					
					if (val & 1) == 1 {
						row[columns[i].name] = NSNull()
						continue
					}
					
					switch columns[i].fieldType {
					case MysqlTypes.MYSQL_TYPE_NULL:
						row[columns[i].name] = NSNull()
						break
						
					case MysqlTypes.MYSQL_TYPE_TINY:
						if ((columns[i].flags & MysqlFieldFlag.UNSIGNED) == MysqlFieldFlag.UNSIGNED) {
							row[columns[i].name] = UInt8(data[pos..<pos+1])
							pos += 1
							break
						}
						
						row[columns[i].name] = Int8(data[pos..<pos+1])
						pos += 1
						break
						
					case MysqlTypes.MYSQL_TYPE_SHORT:
						if ((columns[i].flags & MysqlFieldFlag.UNSIGNED) == MysqlFieldFlag.UNSIGNED) {
							row[columns[i].name] = UInt16(data[pos..<pos+2])
							pos += 2
							break
						}
						
						row[columns[i].name] = Int16(data[pos..<pos+2])
						pos += 2
						break
						
					case MysqlTypes.MYSQL_TYPE_INT24, MysqlTypes.MYSQL_TYPE_LONG:
						if ((columns[i].flags & MysqlFieldFlag.UNSIGNED) == MysqlFieldFlag.UNSIGNED) {
							row[columns[i].name] = UInt(UInt32(data[pos..<pos+4]))
							pos += 4
							break
						}
						
						row[columns[i].name] = Int(Int32(data[pos..<pos+4]))
						pos += 4
						break
						
					case MysqlTypes.MYSQL_TYPE_LONGLONG:
						if ((columns[i].flags & MysqlFieldFlag.UNSIGNED) == MysqlFieldFlag.UNSIGNED) {
							row[columns[i].name] = UInt64(data[pos..<pos+8])
							pos += 8
							break
						}
						
						row[columns[i].name] = Int64(data[pos..<pos+8])
						pos += 8
						break
						
					case MysqlTypes.MYSQL_TYPE_FLOAT:
						row[columns[i].name] = data[pos..<pos+4].float32()
						pos += 4
						break
						
					case MysqlTypes.MYSQL_TYPE_DOUBLE:
						row[columns[i].name] = data[pos..<pos+8].float64()
						pos += 8
						break
						
					case MysqlTypes.MYSQL_TYPE_TINY_BLOB, MysqlTypes.MYSQL_TYPE_MEDIUM_BLOB, MysqlTypes.MYSQL_TYPE_VARCHAR,
							 MysqlTypes.MYSQL_TYPE_VAR_STRING, MysqlTypes.MYSQL_TYPE_STRING, MysqlTypes.MYSQL_TYPE_LONG_BLOB,
							 MysqlTypes.MYSQL_TYPE_BLOB:
						
						if columns[i].charSetNr == 63 {
							let (bres, n) = MySQL.Utils.lenEncBin(Array(data[pos..<data.count]))
							row[columns[i].name] = bres
							pos += n
							
						}
						else {
							let (str, n) = MySQL.Utils.lenEncStr(Array(data[pos..<data.count]))
							row[columns[i].name] = str
							pos += n
						}
						break
						
					case MysqlTypes.MYSQL_TYPE_DECIMAL, MysqlTypes.MYSQL_TYPE_NEWDECIMAL,
							 MysqlTypes.MYSQL_TYPE_BIT, MysqlTypes.MYSQL_TYPE_ENUM, MysqlTypes.MYSQL_TYPE_SET,
							 MysqlTypes.MYSQL_TYPE_GEOMETRY:
						
						let (str, n) = MySQL.Utils.lenEncStr(Array(data[pos..<data.count]))
						row[columns[i].name] = str
						pos += n
						break
						
					case MysqlTypes.MYSQL_TYPE_DATE:
						let (dlen, n) = MySQL.Utils.lenEncInt(Array(data[pos..<data.count]))
						
						guard dlen != nil else {
							row[columns[i].name] = NSNull()
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
							y = Int(data[pos+1..<pos+3].uInt16())
							mo = Int(data[pos+3])
							d = Int(data[pos+4])
							res = Date(dateString: String(format: "%4d-%02d-%02d", arguments: [y, mo, d]))
							break
						default:break
						}
						
						row[columns[i].name] = res ?? NSNull()
						pos += n + Int(dlen!)
						
						break
						
					case MysqlTypes.MYSQL_TYPE_TIME:
						let (dlen, n) = MySQL.Utils.lenEncInt(Array(data[pos..<data.count]))
						
						guard dlen != nil else {
							row[columns[i].name] = NSNull()
							break
						}
						var h = 0, m = 0, s = 0, u = 0
						var res : Date?
						
						switch Int(dlen!) {
						case 12:
							//12:03:15.000 001
							u = Int(data[pos+9..<pos+13].uInt32())
							fallthrough
						case 8:
							//12:03:15
							h = Int(data[pos+6])
							m = Int(data[pos+7])
							s = Int(data[pos+8])
							res = Date(timeStringUsec:String(format: "%02d:%02d:%02d.%06d", arguments: [h, m, s, u]))
							break
						default:
							res = Date(timeString: "00:00:00")
							break
						}
						
						row[columns[i].name] = res ?? NSNull()
						pos += n + Int(dlen!)
						
						break
						
					case MysqlTypes.MYSQL_TYPE_TIMESTAMP, MysqlTypes.MYSQL_TYPE_DATETIME:
						
						let (dlen, n) = MySQL.Utils.lenEncInt(Array(data[pos..<data.count]))
						
						guard dlen != nil else {
							row[columns[i].name] = NSNull()
							break
						}
						var y = 0, mo = 0, d = 0, h = 0, m = 0, s = 0, u = 0
						
						switch Int(dlen!) {
						case 11:
							// 2015-12-02 12:03:15.001004005
							u = Int(data[pos+8..<pos+12].uInt32())
							fallthrough
						case 7:
							// 2015-12-02 12:03:15
							h = Int(data[pos+5])
							m = Int(data[pos+6])
							s = Int(data[pos+7])
							fallthrough
						case 4:
							// 2015-12-02
							y = Int(data[pos+1..<pos+3].uInt16())
							mo = Int(data[pos+3])
							d = Int(data[pos+4])
							break
							
						default:break
						}
						
						let dstr = String(format: "%4d-%02d-%02d %02d:%02d:%02d.%06d", arguments: [y, mo, d, h, m, s, u])
						row[columns[i].name] = Date(dateTimeStringUsec: dstr) ?? NSNull()
						
						pos += n + Int(dlen!)
						break
					default:
						row[columns[i].name] = NSNull()
						break
					}
					
				}
				return row
			}
			else {
				return nil
			}
		}
		
		/// Read row of a specific type
		func readRow<T : RowType>() throws -> T? {
			let result = try readRow()
			return T(dict:result!)
		}
		
		/// Read all rows.
		func readAllRows() throws -> [ResultSet]? {
			var result = [ResultSet]()
			
			repeat {
				// If result has more than one row
				if connection.hasMoreResults {
					try connection.nextResult()
				}
				
				var rows = ResultSet()
				while let row = try readRow() {
					rows.append(row)
				}
				
				if (rows.count > 0){
					result.append(rows)
				}
			} while connection.hasMoreResults
			
			return result
		}
		
		/// Read all rows of specific type.
		func readAllRows<T : RowType>() throws -> [[T]]? {
			var result = [[T]]()
			
			repeat {
				// If result has more than one row
				if connection.hasMoreResults {
					try connection.nextResult()
				}
				
				var rows = [T]()
				while let row = try readRow() as? T {
					rows.append(row)
				}
				
				if (rows.count > 0){
					result.append(rows)
				}
			} while connection.hasMoreResults
			
			return result
		}
	}
}
