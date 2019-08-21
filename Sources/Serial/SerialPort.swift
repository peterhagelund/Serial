// Copyright (c) 2019 Peter Hagelund
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import Foundation

/// Enumeration of the supported baud rates.
public enum BaudRate: UInt32 {
    /// 300 bps.
    case bps300 = 300
    /// 600 bps.
    case bps600 = 600
    /// 1,200 bps.
    case bps1200 = 1200
    /// 2,400 bps.
    case bps2400 = 2400
    /// 4,800 bps
    case bps4800 = 4800
    /// 9,600 bps.
    case bps9600 = 9600
    /// 14,400 bps.
    case bps14400 = 14400
    /// 19,200 bps.
    case bps19200 = 19200
    /// 28,800 bps.
    case bps28800 = 28800
    /// 38,400 bps.
    case bps38400 = 38400
    /// 57,600 bps.
    case bps57600 = 57600
    /// 115,200 bps.
    case bps115200 = 115200
    /// 230,400 bps.
    case bps230400 = 230400
}

/// Enumeration of the parity types.
public enum Parity: UInt8 {
    /// No parity.
    case none = 0
    /// Odd parity.
    case odd = 1
    /// Even parity.
    case even = 2
}

/// Enumeration of the supported number of data bits.
public enum DataBits: UInt8 {
    /// 5 data bits.
    case bits5 = 0
    /// 6 data bits.
    case bits6 = 1
    /// 7 data bits.
    case bits7 = 2
    /// 8 data bits.
    case bits8 = 3
}

/// Enumeration of the supported number of stop bits.
public enum StopBits: UInt8 {
    /// 1 stop bit.
    case bits1 = 0
    /// 2 stop bits.
    case bits2 = 1
}

/// Encapsulation of a POSIX serial port.
public class SerialPort {
    /// The baud rate (`300` to `230,400`).
    public private(set) var baudRate: BaudRate = .bps9600
    
    /// The parity (`none`, `odd` or `even`).
    public private(set) var parity: Parity = .none
    
    /// The number of data bits (`5` to `8`).
    public private(set) var dataBits: DataBits = .bits8
    
    /// The number of data bits (`1` or `2`).
    public private(set) var stopBits: StopBits = .bits1
    
    /// The underlying file descriptor.
    var fd: Int32
    
    /// Initializes a new `SerialPort` instance for the specified name with the specified baud rate, parity, number of data bits and number of stop bits.
    ///
    /// - Parameters:
    ///   - device: The name of the device.
    ///   - baudRate: The baud rate.
    ///   - parity: The parity.
    ///   - dataBits: The number of data bits.
    ///   - stopBits: The number of stop bits.
    public init?(device: String, baudRate: BaudRate = .bps9600, parity: Parity = .none, dataBits: DataBits = .bits8, stopBits: StopBits = .bits1) {
        fd = open(device, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd != -1 else {
            return nil
        }
        #if os(Linux)
        guard ioctl(fd, UInt(TIOCEXCL)) == 0 else {
            return nil
        }
        #else
        guard ioctl(fd, TIOCEXCL) == 0 else {
            return nil
        }
        #endif
        guard fcntl(fd, F_SETFL) == 0 else {
            return nil
        }
        var attrs = termios()
        guard tcgetattr(fd, &attrs) == 0 else {
            return nil
        }
        guard cfsetspeed(&attrs, speed_t(B9600)) == 0 else {
            return nil
        }
        attrs.c_cflag &= ~tcflag_t(PARENB | PARODD)
        attrs.c_cflag &= ~tcflag_t(CSIZE)
        attrs.c_cflag |= tcflag_t(CS8)
        attrs.c_cflag &= ~tcflag_t(CSTOPB)
        attrs.c_iflag &= ~tcflag_t(IGNBRK)
        attrs.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)
        attrs.c_lflag = 0
        attrs.c_oflag = 0
        attrs.c_cflag |= tcflag_t(CLOCAL | CREAD)
        attrs.c_cc.16 = cc_t(0)
        attrs.c_cc.17 = cc_t(0)
        guard tcsetattr(fd, TCSANOW, &attrs) == 0 else {
            return nil
        }
        guard tcflush(fd, TCIOFLUSH) == 0 else {
            return nil
        }
        do {
            try setBaudRate(baudRate: baudRate)
            try setParity(parity: parity)
            try setDataBits(dataBits: dataBits)
            try setStopBits(stopBits: stopBits)
        } catch {
            return nil
        }
    }
    
    deinit {
        close(fd)
    }
    
    /// Sets the baud rate for the already-open serial port.
    ///
    /// - Note: Changing the baud rate flushes the connection.
    /// - Parameter baudRate: The new baud rate.
    /// - Throws: `POSIXError` if the baud rate cannot be changed.
    public func setBaudRate(baudRate: BaudRate) throws {
        guard baudRate != self.baudRate else {
            return
        }
        var attrs = termios()
        guard tcgetattr(fd, &attrs) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var speed: Int32
        switch baudRate {
        case .bps300:
            speed = B300
        case .bps600:
            speed = B600
        case .bps1200:
            speed = B1200
        case .bps2400:
            speed = B2400
        case .bps4800:
            speed = B4800
        case .bps9600:
            speed = B9600
        case .bps14400:
            speed = B14400
        case .bps19200:
            speed = B19200
        case .bps28800:
            speed = B28800
        case .bps38400:
            speed = B38400
        case .bps57600:
            speed = B57600
        case .bps115200:
            speed = B115200
        case .bps230400:
            speed = B230400
        }
        guard cfsetspeed(&attrs, speed_t(speed)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard tcsetattr(fd, TCSANOW, &attrs) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard tcflush(fd, TCIOFLUSH) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        self.baudRate = baudRate
    }
    
    /// Sets the parity for the already-open serial port.
    ///
    /// - Note: Changing parity flushes the connection.
    /// - Parameter parity: The parity.
    /// - Throws: `POSIXError` if the parity cannot be changed.
    public func setParity(parity: Parity) throws {
        guard parity != self.parity else {
            return
        }
        var attrs = termios()
        guard tcgetattr(fd, &attrs) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        switch parity {
        case .none:
            break
        case .odd:
            attrs.c_cflag |= tcflag_t(PARODD)
        case .even:
            attrs.c_cflag |= tcflag_t(PARENB)
        }
        guard tcsetattr(fd, TCSANOW, &attrs) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard tcflush(fd, TCIOFLUSH) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        self.parity = parity
    }
    
    /// Sets the number of data bits for the already-open serial port.
    ///
    /// - Note: Changing the number of data bits flushes the connection.
    /// - Parameter dataBits: The number of data bits.
    /// - Throws: `POSIXError` if the number of data bits cannot be changed.
    public func setDataBits(dataBits: DataBits) throws {
        guard dataBits != self.dataBits else {
            return
        }
        var attrs = termios()
        guard tcgetattr(fd, &attrs) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        attrs.c_cflag &= ~tcflag_t(CSIZE)
        switch dataBits {
        case .bits5:
            attrs.c_cflag |= tcflag_t(CS5)
        case .bits6:
            attrs.c_cflag |= tcflag_t(CS6)
        case .bits7:
            attrs.c_cflag |= tcflag_t(CS7)
        case .bits8:
            attrs.c_cflag |= tcflag_t(CS8)
        }
        guard tcsetattr(fd, TCSANOW, &attrs) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard tcflush(fd, TCIOFLUSH) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        self.dataBits = dataBits
    }
    
    /// Sets the number of stop bits for the already-open serial port.
    ///
    /// - Parameter stopBits: The number of stop bits.
    /// - Throws: `POSIXError` if the number of stop bits cannot be changed.
    public func setStopBits(stopBits: StopBits) throws {
        guard stopBits != self.stopBits else {
            return
        }
        var attrs = termios()
        guard tcgetattr(fd, &attrs) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        attrs.c_cflag &= ~tcflag_t(CSTOPB)
        switch stopBits {
        case .bits1:
            break
        case .bits2:
            attrs.c_cflag |= tcflag_t(CSTOPB)
        }
        guard tcsetattr(fd, TCSANOW, &attrs) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard tcflush(fd, TCIOFLUSH) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        self.stopBits = stopBits
    }
    
    /// Attempts to read the specified number of bytes within the timeout period.
    ///
    /// - Parameters:
    ///   - count: The number of bytes to read.
    ///   - timeout: The timeout period time interval.
    /// - Returns: The requested bytes.
    /// - Throws: `POSIXError` if the bytes cannot be read.
    public func read(count: Int, timeout: TimeInterval) throws -> [UInt8] {
        let buffer = [UInt8](repeating: 0x00, count: count)
        var data = UnsafeMutableRawPointer(mutating: buffer)
        var bytesRemaining = count
        var bytesRead: Int
        let latest = Date(timeIntervalSinceNow: timeout)
        while bytesRemaining > 0 {
            #if os(Linux)
            bytesRead = Glibc.read(fd, data, bytesRemaining)
            #else
            bytesRead = Darwin.read(fd, data, bytesRemaining)
            #endif
            if bytesRead == -1 {
                let code = POSIXErrorCode(rawValue: errno) ?? .EIO
                guard code == .EAGAIN else {
                    throw POSIXError(code)
                }
            }
            bytesRemaining -= bytesRead
            if bytesRemaining > 0 {
                guard Date() < latest else {
                    throw POSIXError(.EWOULDBLOCK)
                }
                data = data.advanced(by: bytesRead)
            }
        }
        return buffer
    }
    
    /// Attempts to read the specified number of bytes.
    ///
    /// - Parameter count: The number of bytes to read.
    /// - Returns: The requested bytes (which may be empty).
    /// - Throws: `POSIXError` if the bytes cannot be read.
    public func read(count: Int) throws -> [UInt8] {
        let buffer = [UInt8](repeating: 0x00, count: count)
        var data = UnsafeMutableRawPointer(mutating: buffer)
        var bytesRead: Int
        #if os(Linux)
        bytesRead = Glibc.read(fd, data, buffer.count)
        #else
        bytesRead = Darwin.read(fd, data, buffer.count)
        #endif
        guard bytesRead != -1 else {
            let code = POSIXErrorCode(rawValue: errno) ?? .EIO
            guard code == .EAGAIN else {
                throw POSIXError(code)
            }
            return [UInt8]()
        }
        guard bytesRead == buffer.count else {
            return Array(buffer[0..<bytesRead])
        }
        return buffer
    }
    
    /// Attempts to write the specified buffer of bytes within the timeout period.
    ///
    /// - Parameters:
    ///   - buffer: The buffer of bytes to write.
    ///   - timeout: The timeout period time interval.
    /// - Throws: `POSIXError` if the bytes cannot be written.
    public func write(buffer: [UInt8], timeout: TimeInterval) throws {
        var data = UnsafeRawPointer(buffer)
        var bytesRemaining = buffer.count
        var bytesWritten: Int
        let latest = Date(timeIntervalSinceNow: timeout)
        while bytesRemaining > 0 {
            #if os(Linux)
            bytesWritten = Glibc.write(fd, data, bytesRemaining)
            #else
            bytesWritten = Darwin.write(fd, data, bytesRemaining)
            #endif
            if bytesWritten == -1 {
                let code = POSIXErrorCode(rawValue: errno) ?? .EIO
                guard code == .EAGAIN else {
                    throw POSIXError(code)
                }
            }
            bytesRemaining -= bytesWritten
            if bytesRemaining > 0 {
                guard Date() < latest else {
                    throw POSIXError(.EWOULDBLOCK)
                }
                data = data.advanced(by: bytesWritten)
            }
        }
    }
    
    /// Attempts to write the specified buffer.
    ///
    /// - Parameter buffer: The buffer of bytes to write.
    /// - Returns: The actual number of bytes written (may be `0`).
    /// - Throws: `POSIXError` if the bytes cannot be written.
    public func write(buffer: [UInt8]) throws -> Int {
        let data = UnsafeRawPointer(buffer)
        var bytesWritten: Int
        #if os(Linux)
        bytesWritten = Glibc.write(fd, data, buffer.count)
        #else
        bytesWritten = Darwin.write(fd, data, buffer.count)
        #endif
        guard bytesWritten != -1 else {
            let code = POSIXErrorCode(rawValue: errno) ?? .EIO
            guard code == .EAGAIN else {
                throw POSIXError(code)
            }
            return 0
        }
        return bytesWritten
    }
}
