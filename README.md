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
  dbname: "dbname"
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

#### Prepared
```swift
// Prepare the query
let stmt : MySQL.Statement = try connection.prepare("SELECT * FROM ?")

// Execute the query with arguments
stmt.exec(["tableName"])

// Execute the query with arguments and get results
let results : MySQL.Result = try stmt.query(["tableName"])

for row in results.readAllRows() ?? [] {
  print(row)
}
```


## Advanced

### Connection Pool
```swift
// create a connection pool with 10 connections using con as prototype
let connPool = try MySQL.ConnectionPool(num: 10, connection: con)
//create a table object using the connection
let table = MySQL.Table(tableName: "xctest_conn_pool", connection: con)
// drop the table if it exists
try table.drop()

// declare a Swift object
class obj {
  var id:Int?
  var val : Int = 1
}
            
// create a new object
let o = obj()
// create a new MySQL Table using the object 
try table.create(o, primaryKey: "id", autoInc: true)
            
// do 500 async inserts using the connections pool
for i in 1...500 {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
  //get a connection from the pool
    if let c = connPool.getConnection() {
    // get a Table reference using the connection from the pool
      let t = MySQL.Table(tableName: "xctest_conn_pool", connection: c)
      do {
        let o = obj()
        o.val = i
        // insert the object
        try t.insert(o)
      }
      catch {
        print(error)
        XCTAssertNil(error)
        connPool.free(c)
      }
      // release the connection to the pool
      connPool.free(c)
    }
  })
}
```


## License
Copyright (c) 2015, Marius Corega
All rights reserved.

Permission is granted to anyone to use this software for any purpose, 
including commercial applications, and to alter it and redistribute it freely.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the {organization} nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

* If you use this software in a product, an acknowledgment in the product 
  documentation is required. Altered source versions must be plainly marked 
  as such, and must not be misrepresented as being the original software. 
  This notice may not be removed or altered from any source or binary distribution.
  

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
