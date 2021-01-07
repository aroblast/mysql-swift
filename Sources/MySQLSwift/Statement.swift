import Foundation

public extension MySQL {
	
	class Statement {
		var connection : Connection
		
		var id : UInt32?
		var paramCount : Int?
		var columnCount : UInt16?
		var columns : [Field]?
		
		init(connection : Connection){
			self.connection = connection
		}
		
		/// Execute query with optional arguments and return its result.
		open func query(_ args : [Any] = []) throws -> Result {
			try writeExecutePacket(args)
			
			let resultsLen = try connection.readResultSetHeaderPacket()
			self.columns = try connection.readColumns(resultsLen)
			
			return BinaryRow(connection: connection)
		}
		
		/// Only execute query with optional arguments.
		open func exec(_ args:[Any]) throws {
			try writeExecutePacket(args)
			
			let resultLen = try connection.readResultSetHeaderPacket()
			if resultLen > 0 {
				try connection.readUntilEOF()
				// MARK: Code duplicate?
				try connection.readUntilEOF()
			}
		}
		
		/// Read the prepare result response from the socket.
		func readPrepareResultPacket() throws -> UInt16? {
			if let data = try connection.socket?.readPacket() {
				// If error occured
				if data[0] != 0x00 {
					throw connection.handleErrorPacket(data)
				}
				
				// Statement id [4 bytes]
				self.id = data[1..<5].uInt32()
				
				// Column count [16 bit uint]
				self.columnCount = data[5..<7].uInt16()
				
				// Param count [16 bit uint]
				self.paramCount = Int(data[7..<9].uInt16())
				
				return self.columnCount
			}
			else {
				return 0
			}
		}
		
		/// Write execute packet to the socket.
		func writeExecutePacket(_ args: [Any]) throws {
			// If missing or too much arguments
			if (args.count != paramCount) {
				throw StatementError.argsCountMismatch
			}
			
			connection.socket?.packetsNumber = -1
			
			var data = [UInt8]()
			
			// Command [1 byte]
			data.append(MysqlCommands.COM_STMT_EXECUTE)
			guard self.id != nil else {
				throw StatementError.stmtIdNotSet
			}
			
			// Statement_id [4 bytes]
			data.append(contentsOf:[UInt8].UInt32Array(self.id!))
			
			// Flags (0: CURSOR_TYPE_NO_CURSOR) [1 byte]
			data.append(0)
			
			// Iteration_count (uint32(1)) [4 bytes]
			data.append(contentsOf: [ 1, 0, 0, 0 ])
			
			// If args
			if args.count > 0 {
				let nmLen = (args.count + 7) / 8
				var nullBitmap = [UInt8](repeating:0, count: nmLen)
				
				for ii in 0..<args.count {
					let mi = Mirror(reflecting: args[ii])
					
					// Check for null value
					if ((mi.displayStyle == .optional) && (mi.children.count == 0)) || args[ii] is NSNull {
						let nullByte = ii >> 3
						let nullMask = UInt8(UInt(1) << UInt(ii-(nullByte<<3)))
						nullBitmap[nullByte] |= nullMask
					}
				}
				
				// Null Mask
				data.append(contentsOf: nullBitmap)
				// Types
				data.append(1)
				
				// Data Type
				var dataTypeArr = [UInt8]()
				var argsArr = [UInt8]()
				
				for arg in args {
					let mi = Mirror(reflecting: arg)
					
					if ((mi.displayStyle == .optional) && (mi.children.count == 0)) || arg is NSNull {
						dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_NULL))
						continue
					}
					else {
						switch arg {
						case let vv as Int64:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_LONGLONG))
							argsArr += [UInt8].Int64Array(vv)
							break
							
						case let vv as UInt64:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_LONGLONG))
							argsArr += [UInt8].UInt64Array(vv)
							break
							
						case let vv as Int:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_LONG))
							argsArr += [UInt8].IntArray(vv)
							break
							
						case let vv as UInt:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_LONG))
							argsArr += [UInt8].UIntArray(vv)
							break
							
						case let vv as Int32:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_LONG))
							argsArr += [UInt8].Int32Array(vv)
							break
							
						case let vv as UInt32:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_LONG))
							argsArr += [UInt8].UInt32Array(vv) //vv.array()
							break
							
						case let vv as Int16:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_SHORT))
							argsArr +=  [UInt8].Int16Array(Int16(vv)) //vv.array()
							break
							
						case let vv as UInt16:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_SHORT))
							argsArr += [UInt8].UInt16Array(UInt16(vv)) //vv.array()
							break
							
						case let vv as Int8:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_TINY))
							argsArr += vv.array()
							break
							
						case let vv as UInt8:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_TINY))
							argsArr += vv.array()
							break
							
						case let vv as Double:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_DOUBLE))
							argsArr += [UInt8].DoubleArray(vv)
							break
							
						case let vv as Float:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_FLOAT))
							argsArr += [UInt8].FloatArray(vv)
							break
							
						case let arr as [UInt8]:
							if arr.count < MySQL.maxPackAllowed - 1024*1024 {
								let lenArr = MySQL.Utils.lenEncIntArray(UInt64(arr.count))
								dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_LONG_BLOB))
								argsArr += lenArr
								argsArr += arr
							}
							else {
								throw StatementError.mySQLPacketToLarge
							}
							break
							
						case let data as Data:
							let count = data.count / MemoryLayout<UInt8>.size
							
							if count < MySQL.maxPackAllowed - 1024*1024 {
								var arr = [UInt8](repeating:0, count: count)
								data.copyBytes(to: &arr, count: count)
								
								let lenArr = MySQL.Utils.lenEncIntArray(UInt64(arr.count))
								dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_LONG_BLOB))
								argsArr += lenArr
								argsArr += arr
							}
							else {
								throw StatementError.mySQLPacketToLarge
							}
							break
							
						case let str as String:
							if str.count < MySQL.maxPackAllowed - 1024*1024 {
								let lenArr = MySQL.Utils.lenEncIntArray(UInt64(str.count))
								dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_STRING))
								argsArr += lenArr
								argsArr += [UInt8](str.utf8)
							}
							else {
								throw StatementError.mySQLPacketToLarge
							}
							break
							
						case let date as Date:
							let arr = [UInt8](date.dateTimeString().utf8)
							let lenArr = MySQL.Utils.lenEncIntArray(UInt64(arr.count))
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_STRING))
							argsArr += lenArr
							argsArr += arr
							break
						default:
							throw StatementError.unknownType("\(mi.subjectType)")
						}
					}
				}
				
				data += dataTypeArr
				data += argsArr
			}
			
			try connection.socket?.writePacket(data)
		}
	}
	
	// Enums
	enum StatementError : Error {
		 case argsCountMismatch
		 case stmtIdNotSet
		 case unknownType(String)
		 case nilConnection
		 case mySQLPacketToLarge
	 }
}
