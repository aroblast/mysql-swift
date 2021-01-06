import Foundation

// IMPORTANT NOTE: This file will probably be removed in future releases, and the use of tables is not recommended as it is too much high level and doesn't quite fit with the low level nature of the API.

public extension MySQL {
	
	class Table {
		var tableName : String
		var connection : Connection
		
		public init(tableName : String, connection : Connection) {
			self.tableName = tableName
			self.connection = connection
		}
		
		/// Get the MySQL type corresponding to the value type.
		func mysqlType(_ value : Any) throws -> String {
			var type : String = ""
			var optional : Bool = false
			
			let mirror = Mirror(reflecting: value)
			let subjectType = "\(mirror.subjectType)"
			
			// Handle optional
			if (subjectType.contains("Optional<")) {
				optional = true
				type = subjectType.replacingOccurrences(of: "Optional<", with: "").replacingOccurrences(of: ">", with: "")
			}
			else {
				type = subjectType
			}

			// Get type
			switch type {
			case "Int8":
				return "TINYINT" + (!optional ? " NOT NULL" : "")
			case "UInt8":
				return "TINYINT UNSIGNED" + (!optional ? " NOT NULL" : "")
			case "Int16":
				return "SMALLINT" + (!optional ? " NOT NULL" : "")
			case "UInt16":
				return "SMALLINT UNSIGNED" + (!optional ? " NOT NULL" : "")
			case "Int":
				return "INT" + (!optional ? " NOT NULL" : "")
			case "UInt":
				return "INT UNSIGNED" + (!optional ? " NOT NULL" : "")
			case "Int64":
				return "BIGINT" + (!optional ? " NOT NULL" : "")
			case "UInt64":
				return "BIGINT UNSIGNED" + (!optional ? " NOT NULL" : "")
			case "Float":
				return "FLOAT" + (!optional ? " NOT NULL" : "")
			case "Double":
				return "DOUBLE" + (!optional ? " NOT NULL" : "")
			case "String":
				return "MEDIUMTEXT" + (!optional ? " NOT NULL" : "")
			case "__NSTaggedDate", "__NSDate", "NSDate", "Date":
				return "DATETIME" + (!optional ? " NOT NULL" : "")
			case "NSConcreteData", "NSConcreteMutableData", "NSMutableData", "Data":
				return "LONGBLOB" + (!optional ? " NOT NULL" : "")
			case "Array<UInt8>":
				return "LONGBLOB" + (!optional ? " NOT NULL" : "")
			default:
				throw TableError.unknownType(type)
			}
		}
		
		/// Creates a new table based on a Swift Object.
		func create(_ object : Any, primaryKey : String? = nil, autoInc : Bool = false) throws {
			var columns : String = ""
			let mirror : Mirror = Mirror(reflecting: object)
			var count : Int = mirror.children.count
			
			// For each value
			for case let (label?, value) in mirror.children {
				count -= 1
				
				var type : String = try mysqlType(value)
				if (type != "") {
					if let pkey = primaryKey, pkey == label {
						type += " AUTO_INCREMENT"
					}
					
					columns += label + " " + type + (count > 0 ? ", " : "")
				}
			}
			
			// Check primary key
			if let pk = primaryKey {
				columns += ", PRIMARY KEY (\(pk))"
			}
			
			let query = "create table \(tableName) (\(columns))"
			try connection.exec(query)
		}
		
		/// Creates a new table based on a MySQL.RowStructure
		func create(_ row : MySQL.Row, primaryKey : String? = nil, autoInc : Bool = false) throws {
			var columns = ""
			var count = row.count
			
			// For each value
			for (key, value) in row {
				count -= 1
				
				var type = try mysqlType(value)
				if (type != "") {
					// Check primary key
					if let pkey = primaryKey, pkey == key {
						type += " AUTO_INCREMENT"
					}
					
					columns += key + " " + type + (count > 0 ? ", " : "")
				}
			}
			
			let query = "create table \(tableName) (\(columns))"
			try connection.exec(query)
		}
		
		/// Insert object into table.
		open func insert(_ object : Any, exclude : [String] = []) throws {
			var labels = ""
			var values = ""
			
			let mirror = Mirror(reflecting: object)
			var count = mirror.children.count
			var args = [Any]()
			
			// For each value
			for case let (label?, value) in mirror.children {
				if (!exclude.contains(label)) {
					args.append(value)
					
					labels += label + (count > 0  ? ", " : "")
					values += "?" + (count > 0  ? ", " : "")
					count -= 1
				}
			}
			
			// Prepare and execute statement
			if (labels.count != 0) {
				let query = "INSERT INTO \(tableName) (\(labels)) VALUES (\(values))"
				let stmt = try connection.prepare(query)
				try stmt.exec(args)
			}
		}
		
		/// Insert row into table.
		open func insert(_ row : Row, exclude : [String] = []) throws {
			var labels = ""
			var values = ""
			
			var count = row.count - exclude.count + 1
			var args = [Any]()
			
			// For each value
			for case let (label, value) in row {
				if (!exclude.contains(label)) {
					args.append(value)
					
					labels += label + (count > 0  ? ", " : "")
					values += "?" + (count > 0  ? ", " : "")
					count -= 1
				}
			}
			
			// Prepare and execute statement
			if (labels.count != 0) {
				let query = "INSERT INTO \(tableName) (\(labels)) VALUES (\(values))"
				let stmt = try connection.prepare(query)
				try stmt.exec(args)
			}
		}
		
		/// Update SQL row from row.
		open func update(_ row : Row, where : [String:Any], exclude : [String] = []) throws {
			var labels = ""
			var values = ""
			var wheres = ""
			
			var count = row.count - exclude.count + 1
			var args = [Any]()
			
			// For each value
			for case let (label, value) in row {
				if (!exclude.contains(label)) {
					args.append(value)
					
					labels += label + (count > 0  ? ", " : "")
					values += "?" + (count > 0  ? ", " : "")
					count -= 1
				}
			}
			
			// Reset count
			count = `where`.count
			
			// For each where
			for case let (label, value) in `where` {
				args.append(value)
				
				wheres += label + " = ?" + (count > 0  ? " AND " : "")
				count -= 1
			}
			
			if (labels.count != 0) {
				let query = "UPDATE \(tableName) SET \(values) WHERE \(wheres)"
				let stmt = try connection.prepare(query)
				try stmt.exec(args)
			}
		}
		
		/// Update SQL row from key.
		open func update(_ row : Row, key : String, exclude : [String] = []) throws {
			try update(row, where: [key : row[key] as Any], exclude: exclude)
		}
		
		/// Update SQL row from object.
		open func update(_ object : Any, where : [String:Any], exclude : [String] = []) throws {
			let mirror = Mirror(reflecting: object)
			var row = Row()
			
			// Get all values to update
			for case let (label?, value) in mirror.children {
				row[label] = value
			}
			
			try update(row, where: `where`, exclude: exclude)
		}
		
		/// Update SQL row from object key,
		/*open func update(_ object : Any, key : String, exclude : [String] = []) throws {
			let mirror = Mirror(reflecting: object)
			var row = Row()
			
			// Get all values to update
			for case let (label?, value) in mirror.children {
				row[label] = value
			}
			
			try update(row, key: key, exclude: exclude)
		}
		
		fileprivate func parsePredicate(_ pred:[Any]) throws -> (String, [Any]) {
			guard pred.count % 2 == 0 else {
				throw TableError.wrongParamCountInWhereClause
			}
			
			var res = ""
			var values = [Any]()
			
			for i in 0..<pred.count {
				let val = pred[i]
				
				if let k = val as? String, i % 2 == 0 {
					res += " \(k)?"
				}
				else if i%2 == 1 {
					values.append(val)
				}
				else {
					throw TableError.wrongParamInWhereClause
				}
			}
			
			return (res, values)
		}
		
		open func select(_ columns : [String]?=nil, Where:[Any]) throws -> [MySQL.ResultSet]? {
			
			guard Where.count > 0 else {
				throw TableError.nilWhereClause
			}
			
			let (predicate, vals) = try parsePredicate(Where)
			
			var q = ""
			var res : [MySQL.ResultSet]?
			var cols = ""
			
			if let colsArg = columns, colsArg.count > 0 {
				cols += colsArg[0]
				for i in 1..<colsArg.count {
					cols += "," + colsArg[i]
				}
			}
			else {
				cols = "*"
			}
			
			q = "SELECT \(cols) FROM \(tableName) WHERE \(predicate)"
			
			let stmt = try con.prepare(q)
			let stRes = try stmt.query(vals)
			
			if let rr = try stRes.readAllRows() {
				res = rr
			}
			
			return res
		}
		
		open func select<T:Codable>(_ columns:[String]?=nil, Where:[Any]) throws -> [T] {
			
			var result = [T]();
			
			if let rs = try select(columns, Where:Where) {
				for rr in rs {
					for r in rr {
						let data = try JSONSerialization.data(withJSONObject: r)
						let tr:T = try JSONDecoder().decode(T.self, from: data)
						res.append(tr)
					}
				}
			}
			
			return res
		}
		
		
		open func getRecord(_ Where:[String: Any], columns:[String]?=nil) throws -> MySQL.Row? {
			
			var q = ""
			var res : MySQL.Row?
			var cols = ""
			
			if let colsArg = columns, colsArg.count > 0 {
				cols += colsArg[0]
				for i in 1..<colsArg.count {
					cols += "," + colsArg[i]
				}
			}
			
			//          if let wcl = Where {
			let keys = Array(Where.keys)
			
			if  keys.count > 0 {
				let key = keys[0]
				if let val = Where[key] {
					if cols == "" {
						q = "SELECT * FROM \(tableName) WHERE \(key)=? LIMIT 1"
					}
					else {
						q = "SELECT \(cols) FROM \(tableName) WHERE \(key)=? LIMIT 1"
					}
					
					let stmt = try con.prepare(q)
					let stRes = try stmt.query([val])
					
					if let rr = try stRes.readAllRows() {
						if rr.count > 0 && rr[0].count > 0 {
							res = rr[0][0]
						}
					}
					
				}
				//             }
			}
			
			
			return res
		}
		
		open func getRecord<T:RowType>(_ Where:[String: Any], columns:[String]?=nil) throws -> T? {
			if let r = try getRecord(Where, columns: columns) {
				return T(dict: r)
			}
			return nil
		}
		*/
		
		/// Drop the table.
		open func drop() throws {
			let query = "DROP TABLE IF EXISTS " + tableName
			try connection.exec(query)
		}
	}
	
	enum TableError : Error {
		 case tableExists
		 case nilWhereClause
		 case wrongParamCountInWhereClause
		 case wrongParamInWhereClause
		 case unknownType(String)
	 }
}
