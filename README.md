# MySQL Swift

This repo is only a first try at a reboot from this great [original repository](https://github.com/mcorega/MySqlSwiftNative) made by [@mcorega](https://github.com/mcorega/).


## Installation
To install this package, simply use the `Swift Packages > Add Package Dependency` on your Xcode project.


## Usage

### Connection
A connection is the object allowing you to communicate to the server via MySQL queries.

```swift
// Create the connection object
let connection = MySQL.Connection(
  address: "address",
  user: "user",
  password: "password",
  database: "database" // Optional
)

do{
  // Open a new connection
  try connection.open()

  // Closing the connection
  try connection.close()
}
catch {
  print("Error: \(error)")
}
```

### Queries
Create a new query from a connection.

#### Execute
```swift
try connection.exec("USE db")
```

#### Query

##### Single result
```swift
	let results = try connection!.query("SELECT * FROM users")
	
  for row in results.first?.rows ?? [] {
    // Do something
  }
```

##### Multiple results
```swift
  let results = try connection!.query("SELECT * FROM users; SELECT * FROM projects")
		
  for result in results {
    // Do something
	}
```

#### Prepared
```swift
// Prepare the query
let stmt : MySQL.Statement = try connection.prepare("SELECT * FROM table WHERE condition = ?")

// Either execute the query with arguments
stmt.exec(["value"])

// Or execute the query with arguments and get results
let result : Result = try stmt.query(["tableName"])

for row in result.rows {
  print(row)
}
```


## Advanced

### Connection Pool
```swift
// Create a connection pool with 10 connections from connection
let pool = try MySQL.ConnectionPool(connection: connection)

// Use a connection from the connection pool
if let poolConnection = pool.getConnection() {
  
  // Free the connection when done
  connPool.free(poolConnection)
}
```


## License

This project is under MIT license.