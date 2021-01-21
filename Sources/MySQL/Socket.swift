//
//  File.swift
//  
//
//  Created by Bastien LE CORRE on 2021-01-21.
//

import Socket

extension Socket {
	func readPacket() throws -> Packet {
		let header : Header = Header(try self.readData(length: 4))
		let data : [UInt8] = try self.readData(length: header.length)
		
		return Packet(header: header, data: data)
	}
	
	func writePacket(_ packet : Packet) throws {
		try self.writeData(data: packet.header.encode())
		try self.writeData(data: packet.data)
	}
}
