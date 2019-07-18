//
//  SerialPort.swift
//  Serial
//
//  Created by Peter Hagelund on 7/18/19.
//

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import Foundation

public enum BaudRate: Int {
    case baud300 = 300
    case baud600 = 600
    case baud1200 = 1200
    case baud2400 = 2400
    case baud4800 = 4800
    case baud9600 = 9600
    case baud19200 = 19200
    case baud38400 = 38400
    case baud57600 = 57600
    case baud115200 = 115200
}

public enum Parity: Int {
    case none = 0
    case odd = 1
    case even = 2
}

public enum DataBits: Int {
    case bits5 = 0
    case bits6 = 1
    case bits7 = 2
    case bits8 = 3
}

public enum StopBits: Int {
    case bits1 = 0
    case bits2 = 1
}

public enum SerialError: Error {
    case readError
    case writeError
    case timeout
}

public class SerialPort {
    var fd: Int32
    
    public init?(device: String, baudRate: BaudRate, parity: Parity, dataBits: DataBits, stopBits: StopBits) {
        fd = open(device, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd != -1 else { return nil }
        var result: Int32
        #if os(Linux)
        result = ioctl(fd, UInt(TIOCEXCL))
        #else
        result = ioctl(fd, TIOCEXCL)
        #endif
        guard result == 0 else { return nil }
        result = fcntl(fd, F_SETFL)
        guard result == 0 else { return nil }
        var attrs = termios()
        result = tcgetattr(fd, &attrs)
        guard result == 0 else { return nil }
        var speed: Int32
        switch baudRate {
        case .baud300: speed = B300
        case .baud600: speed = B600
        case .baud1200: speed = B1200
        case .baud2400: speed = B2400
        case .baud4800: speed = B4800
        case .baud9600: speed = B9600
        case .baud19200: speed = B19200
        case .baud38400: speed = B38400
        case .baud57600: speed = B57600
        case .baud115200: speed = B115200
        }
        cfsetispeed(&attrs, speed_t(speed))
        cfsetospeed(&attrs, speed_t(speed))
        attrs.c_cflag &= ~tcflag_t(PARENB | PARODD)
        switch parity {
        case .none: break
        case .odd: attrs.c_cflag |= tcflag_t(PARODD)
        case .even: attrs.c_cflag |= tcflag_t(PARENB)
        }
        attrs.c_cflag &= ~tcflag_t(CSIZE)
        switch dataBits {
        case .bits5: attrs.c_cflag |= tcflag_t(CS5)
        case .bits6: attrs.c_cflag |= tcflag_t(CS6)
        case .bits7: attrs.c_cflag |= tcflag_t(CS7)
        case .bits8: attrs.c_cflag |= tcflag_t(CS8)
        }
        attrs.c_cflag &= ~tcflag_t(CSTOPB)
        switch stopBits {
        case .bits1: break
        case .bits2: attrs.c_cflag |= tcflag_t(CSTOPB)
        }
        attrs.c_iflag &= ~tcflag_t(IGNBRK)
        attrs.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)
        attrs.c_lflag = 0
        attrs.c_oflag = 0
        attrs.c_cflag |= tcflag_t(CLOCAL | CREAD)
        attrs.c_cc.16 = cc_t(0)
        attrs.c_cc.17 = cc_t(0)
        result = tcsetattr(fd, TCSANOW, &attrs)
        guard result == 0 else { return nil }
        tcflush(fd, TCIOFLUSH)
    }
    
    deinit {
        close(fd)
    }
    
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
                guard errno == EAGAIN else { throw SerialError.readError }
            }
            bytesRemaining -= bytesRead
            if bytesRemaining > 0 {
                guard Date() < latest else { throw SerialError.timeout }
                data = data.advanced(by: bytesRead)
            }
        }
        return buffer
    }
    
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
                guard errno == EAGAIN else { throw SerialError.writeError }
            }
            bytesRemaining -= bytesWritten
            if bytesRemaining > 0 {
                guard Date() < latest else { throw SerialError.timeout }
                data = data.advanced(by: bytesWritten)
            }
        }
    }
}
