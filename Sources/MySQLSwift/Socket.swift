import Foundation

extension Socket {
	enum SocketError: Error {
		case socketCreationFailed(String)
		case socketShutdownFailed(String)
		case socketSettingReUseAddrFailed(String)
		case connectFailed(String)
		case bindFailed(String)
		case listenFailed(String)
		case writeFailed(String)
		case getPeerNameFailed(String)
		case convertingPeerNameFailed
		case getNameInfoFailed(String)
		case acceptFailed(String)
		case recvFailed(String)
		case setSockOptFailed(String)
		case getHostIPFailed
	}
}

open class Socket {
	let socket : Int32
	var address : sockaddr_in?
	
	var bytesToRead : UInt32
	var packetsNumber : Int
	
	init(host : String, port : Int) throws {
		// Create socket to MySQL Server
		bytesToRead = 0
		packetsNumber = 0
		socket = Darwin.socket(AF_INET, SOCK_STREAM, Int32(0))
		
		// Check socket creation successful
		guard self.socket != -1 else {
			throw SocketError.socketCreationFailed(Socket.descriptionOfLastError())
		}
		
		// Set socket options
		var value : Int32 = 1;
		guard setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &value,
										 socklen_t(MemoryLayout<Int32>.size)) != -1 else {
			throw SocketError.setSockOptFailed(Socket.descriptionOfLastError())
		}
		guard setsockopt(socket, SOL_SOCKET, SO_KEEPALIVE, &value,
										 socklen_t(MemoryLayout<Int32>.size)) != -1 else {
			throw SocketError.setSockOptFailed(Socket.descriptionOfLastError())
		}
		
		// Host
		let hostIP = try getHostIP(host)
		address = sockaddr_in(sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
											 sin_family: sa_family_t(AF_INET),
											 sin_port: Socket.porthtons(in_port_t(port)),
											 sin_addr: in_addr(s_addr: inet_addr(hostIP)),
											 sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
		guard setsockopt(socket, SOL_SOCKET,  SO_NOSIGPIPE, &value,
										 socklen_t(MemoryLayout<Int32>.size)) != -1 else {
			throw SocketError.setSockOptFailed(Socket.descriptionOfLastError())
		}
	}
	
	/// Connect socket to MySQL server.
	func open() throws {
		var socketAddress = sockaddr(sa_len: 0, sa_family: 0,
												 sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
		
		memcpy(&address, &socketAddress, Int(MemoryLayout<sockaddr_in>.size))
		guard connect(socket, &socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size)) != -1 else {
			throw SocketError.connectFailed(Socket.descriptionOfLastError())
		}
	}
	
	func close() throws {
		guard shutdown(socket, 2) == 0 else {
			throw SocketError.socketShutdownFailed(Socket.descriptionOfLastError())
		}
	}
	
	func getHostIP(_ host : String) throws -> String{
		let he = gethostbyname(host)
		
		guard he != nil else {
			throw SocketError.getHostIPFailed
		}
		
		let p1 = he?.pointee.h_addr_list[0]
		let p2 = UnsafeRawPointer(p1)?.assumingMemoryBound(to: in_addr.self)
		let p3 = inet_ntoa(p2!.pointee)
		
		return String(cString:p3!)
	}
	
	fileprivate class func descriptionOfLastError() -> String {
		return String(cString:UnsafePointer(strerror(errno))) //?? "Error: \(errno)"
	}
	
	/// Read a UInt8 from socket.
	func readNUInt8(_ n:UInt32) throws -> [UInt8] {
		var buffer = [UInt8](repeating: 0, count: Int(n))
		
		let bufferPrt = withUnsafeMutableBytes(of: &buffer) { bytes in UnsafeMutableRawPointer(bytes.baseAddress) }!
		var read = 0
		
		while read < Int(n) {
			read += recv(socket, bufferPrt + read, Int(n) - read, 0)
			
			if read <= 0 {
				throw SocketError.recvFailed(Socket.descriptionOfLastError())
			}
		}
		
		if bytesToRead >= UInt32(n) {
			bytesToRead -= UInt32(n)
		}
		
		return buffer
	}
	
	/// Read header buffer  from socket.
	func readHeader() throws -> (UInt32, Int) {
		let b = try readNUInt8(3).uInt24()
		
		let pn = try readNUInt8(1)[0]
		bytesToRead = b
		
		return (b, Int(pn))
	}
	
	/// Read packet from socket.
	func readPacket() throws -> [UInt8] {
		let (len, pknr) = try readHeader()
		bytesToRead = len
		packetsNumber = pknr
		return try readNUInt8(len)
	}
	
	/// Write packet to socket.
	func writePacket(_ data:[UInt8]) throws {
		try writeHeader(UInt32(data.count), pn: UInt8(packetsNumber + 1))
		try  writeBuffer(data)
	}
	
	/// Write buffer to socket.
	func writeBuffer(_ buffer:[UInt8]) throws  {
		try buffer.withUnsafeBufferPointer {
			var sent = 0
			while sent < buffer.count {
				let size = write(socket, $0.baseAddress! + sent, Int(buffer.count - sent))
				
				if size <= 0 {
					throw SocketError.writeFailed(Socket.descriptionOfLastError())
				}
				else {
					sent += size
				}
			}
		}
	}
	
	/// Write header buffer to socket.
	func writeHeader(_ len:UInt32, pn:UInt8) throws {
		var ph = [UInt8].UInt24Array(len)
		ph.append(pn)
		try writeBuffer(ph)
	}
	
	fileprivate static func porthtons(_ port: in_port_t) -> in_port_t {
		let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
		return isLittleEndian ? _OSSwapInt16(port) : port
	}
}
