# MySQL Swift

This repo is only a first try at a reboot from this great [original repository](https://github.com/mcorega/MySqlSwiftNative) made by [@mcorega](https://github.com/mcorega/).

## Installation

To install this package, simply use the `Swift Packages > Add Package Dependency` on your Xcode project.

## Usage

### Connection
```swift
// Create the connection object
let con = MySQL.Connection()
let db_name = "swift_test"

do{
  // Open a new connection
  try con.open("localhost", user: "test", passwd: "test")
  
  // Your code goes here...

  // Closing the connection
  try con.close()
}
catch {
  print("Error: \(error)")
}
```

### Tables

#### From Swift

```swift
// Create a new Table object with name on a connection
let table = MySQL.Table(tableName: "createtable_obj", connection: con)
// drop the table if it exists
try table.drop()
          
// declare a new Swft Object with various types
struct obj {
  var iint8 : Int8 = -1
  var uint8: UInt8 = 1
  var int16 : Int16 = -1
  var uint16: UInt16 = 1
  var id:Int = 1
  var count:UInt = 10
  var uint64 : UInt64 = 19999999999
  var int64 : Int64 = -19999999999
  var ffloat : Float = 1.1
  var ddouble : Double = 1.1
  var ddate = NSDate()
  var str = "test string"
  var ddata = "test data".dataUsingEncoding(NSUTF8StringEncoding)!
}

// create a new object
let o = obj()
 
// create the MySQL Table based on the Swift object
try table.create(o)

// create a table with given primaryKey and auto_increment set to true
try table.create(o, primaryKey: "id", autoInc: true)
```

#### From a MySQL.Row

```swift
// create a new Table object with name on a connection
let table = MySQL.Table(tableName: "createtable_row", connection: con)
// drop the table if it exists
try table.drop()

// declare a new MySQL.Row with various types
let obj : MySQL.Row = [
      "oint": Int?(0),
      "iint8" : Int8(-1),
      "uint8": UInt8(1),
      "int16" : Int16(-1),
      "uint16": UInt16(100),
      "id":Int(1),
      "count":UInt?(10),
      "uint64" : UInt64(19999999999),
      "int64" : Int64(-19999999999),
      "ffloat" : Float(1.1),
      "ddouble" : Double(1.1),
      "ddate" : NSDate(dateString: "2015-11-10"),
      "str" : "test string",
      "nsdata" : "test data".dataUsingEncoding(NSUTF8StringEncoding)!,
      "uint8_array" : [UInt8]("test data uint8 array".utf8),
]

// create the MySQL Table based on MySQL.Row object
try table.create(obj)

// create a table with given primaryKey and auto_increment set to true
try table.create(o, primaryKey: "id", autoInc: true)
```

### Insert
```swift
try table.insert(o)
```

### Update

#### Using key

```swift
o.iint8 = -100
o.uint8 = 100
o.int16 = -100
o.iint32 = -200

try table.update(o, key:"id")
```

#### Using a key property

```swift
obj["iint32"] = 4000
obj["iint16"] = Int16(-100)
            
try table.update(obj, key: "id")
```

### Select

```swift
// insert 100 objects
for i in 1...100 {
    o.str = "test string \(i)"
    try table.insert(o)
}


// select all rows from the table given a condition
if let rows = try table.select(Where: ["id=",90, "or id=",91, "or id>",95]) {
    print(rows)
}

// select rows specifying the columns we want and a select condition
if let rows = try table.select(["str", "uint8_array"], Where: ["id=",90, "or id=",91, "or id>",95]) {
    print(rows)
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
