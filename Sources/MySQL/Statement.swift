import Foundation
import Socket

public extension MySQL {
	
	class Statement {
		var connection : Connection
		
		var id : UInt32? = nil
		var paramCount : Int = 0
		var columnCount : UInt16 = 0
		var columns : [Field]? = nil
		
		init(connection : Connection) {
			self.connection = connection
		}
		
		/// Execute prepared query with optional arguments and return result.
		open func query(_ args : [Any]) throws -> Result {
			try writeExecutePacket(args)
			
			let resultLength = try connection.resultLength()
			let columns : [Field] = try connection.readColumns(resultLength)
			
			return BinaryResult(connection: connection, columns: columns)
		}
		
		/// Only execute query with optional arguments.
		open func exec(_ args : [Any]) throws {
			try writeExecutePacket(args)
			
			if (try connection.resultLength() > 0) {
				try connection.recvUntilEOF() // Columns
				try connection.recvUntilEOF() // Rows
			}
		}
		
		/// Read the prepare result response from the socket.
		func readPrepareResultPacket() throws -> UInt16 {
			let packet : Packet = try connection.socket.readPacket()
			if packet.data[0] != 0x00 {
				throw (connection.errorPacket(packet.data))
			}
			
			// Statement id
			id = packet.data[1..<5].uInt32()
			
			// Column count
			columnCount = packet.data[5..<7].uInt16()
			
			// Param count
			paramCount = Int(packet.data[7..<9].uInt16())
			
			return columnCount
		}
		
		/// Write execute packet to the socket.
		func writeExecutePacket(_ args: [Any]) throws {
			var data = [UInt8]()
			
			// If not enough args
			if args.count != paramCount {
				throw StatementError.argsCountMismatch
			}
			
			// Command
			data.append(MysqlCommands.COM_STMT_EXECUTE)
			guard id != nil else {
				throw StatementError.stmtIdNotSet
			}
			
			// Statement_id
			data.append(contentsOf:[UInt8].UInt32Array(id!))
			
			// Flags (0: CURSOR_TYPE_NO_CURSOR)
			data.append(0)
			
			// Iteration_count (uint32(1))
			data.append(contentsOf:[1,0,0,0])
			
			// Parse arguments
			if args.count > 0 {
				let nmLen = (args.count + 7) / 8
				var nullBitmap = [UInt8](repeating:0, count: nmLen)
				
				for ii in 0..<args.count {
					let mi = Mirror(reflecting: args[ii])
					
					//check for null value
					if ((mi.displayStyle == .optional) && (mi.children.count == 0)) || args[ii] is NSNull {
						
						let nullByte = ii >> 3
						let nullMask = UInt8(UInt(1) << UInt(ii-(nullByte<<3)))
						nullBitmap[nullByte] |= nullMask
					}
				}
				
				data.append(contentsOf: nullBitmap)
				data.append(1)
				
				// Data Type
				var dataTypeArr = [UInt8]()
				var argsArr = [UInt8]()
				
				for v in args {
					let mi = Mirror(reflecting: v)
					
					if ((mi.displayStyle == .optional) && (mi.children.count == 0)) || v is NSNull {
						dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_NULL))
						continue
					}
					else {
						switch v {
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
							argsArr += [UInt8].UInt32Array(vv)
							break
							
						case let vv as Int16:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_SHORT))
							argsArr +=  [UInt8].Int16Array(Int16(vv))
							break
							
						case let vv as UInt16:
							dataTypeArr += [UInt8].UInt16Array(UInt16(MysqlTypes.MYSQL_TYPE_SHORT))
							argsArr += [UInt8].UInt16Array(UInt16(vv))
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
			
			try connection.socket.writePacket(
				Packet(
					header: Header(
						length: UInt32(data.count),
						sequence: 0
					),
					
					data: data
				)
			)
		}
	}
	
	enum StatementError : Error {
		 case argsCountMismatch
		 case stmtIdNotSet
		 case unknownType(String)
		 case nilConnection
		 case mySQLPacketToLarge
	 }
}
