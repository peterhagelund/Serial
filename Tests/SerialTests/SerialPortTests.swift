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
import XCTest
@testable import Serial

final class SerialPortTests: XCTestCase {
    var device: String = ""
    var isLoopBack: Bool = false
    
    override func setUp() {
        super.setUp()
        guard let device = ProcessInfo.processInfo.environment["XCTEST_SERIAL_DEVICE"] else {
            XCTFail("No serial port configured for testing")
            return
        }
        self.device = device
        isLoopBack = ProcessInfo.processInfo.environment["XCTEST_SERIAL_LOOPBACK"] ?? "false" == "true"
    }
    
    func testInitWithDefaults() {
        guard let serialPort = SerialPort(device: device) else {
            XCTFail("Unable to create serial port")
            return
        }
        XCTAssertEqual(serialPort.baudRate, .bps9600)
        XCTAssertEqual(serialPort.parity, .none)
        XCTAssertEqual(serialPort.dataBits, .bits8)
        XCTAssertEqual(serialPort.stopBits, .bits1)
    }
    
    func testInit() {
        guard let serialPort = SerialPort(device: device, baudRate: .bps115200, parity: .even, dataBits: .bits7, stopBits: .bits2) else {
            XCTFail("Unable to create serial port")
            return
        }
        XCTAssertEqual(serialPort.baudRate, .bps115200)
        XCTAssertEqual(serialPort.parity, .even)
        XCTAssertEqual(serialPort.dataBits, .bits7)
        XCTAssertEqual(serialPort.stopBits, .bits2)
    }
    
    func testInitWithUnknownDevice() {
        let serialPort = SerialPort(device: "/dev/tty.totally.unknown.port")
        XCTAssertNil(serialPort)
    }
    
    func testReadWrite() {
        guard isLoopBack else {
            return
        }
        guard let serialPort = SerialPort(device: device) else {
            XCTFail("Unable to create serial port")
            return
        }
        do {
            let tx:[UInt8] = [0, 1, 2, 3, 4, 5, 6, 7]
            try serialPort.write(buffer: tx, timeout: 0.1)
            let rx = try serialPort.read(count: 8, timeout: 0.1)
            XCTAssertEqual(rx.count, 8)
            XCTAssertEqual(rx, tx)
        } catch let e as POSIXError {
            XCTFail("POSIX error \(e.errorCode)")
        } catch {
            XCTFail("Unexpected error")
        }
    }
}
