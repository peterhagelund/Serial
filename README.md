# Serial

POSIX serial port, for macOS and Linux, written in Swift.

## Copyright and License

Copyright (c) 2019 Peter Hagelund

This software is licensed under the [MIT Lincense](https://en.wikipedia.org/wiki/MIT_License)

See `LICENSE.txt`

## Installation and Setup

* Clone the repository (`git clone https://github.com/peterhagelund/Serial`)
* `cd Serial/`
* `swift build`
* `swift package generate-xcodeproj`
* `open Serial.xcodeproj/`

### Documentation

The source contains documentation comments suitable for [jazzy](https://github.com/realm/jazzy)

TL;DR:
* `[sudo] gem install jazzy`
* `jazzy --clean --author "Peter Hagelund" --module Serial --min-acl private`
* `open docs/index.html`

### Testing

Testing a serial port API is gnarly. I have not found a good, reliable "tty device" or "virtual tty" I can use, so the few tests that are included only test the very basics.

If you have something like an FTDI usb-to-serial device, plug it in and make a not of the device name (usually something like `/dev/tty.usbXXX-YYY`), then run:

    XCTEST_SERIAL_DEVICE=/dev/tty.usbXXX-YYY swift test

If you have something like an Arduino at the other end that can echo back whan you send it, configure it for `9600,N,8,1` run:

    XCTEST_SERIAL_DEVICE=/dev/tty.usbXXX-YYY XCTEST_SERIAL_LOOPBACKs wift test

This will write a few bytes and then read them back.

## Using

For projects that depend upon `Serial`, make sure `Package.swift` contains the correct dependency:

    // swift-tools-version:5.0
    // The swift-tools-version declares the minimum version of Swift required to build this package.

    import PackageDescription

    let package = Package(
        name: "<package name>",
        products: [
            .library(
                name: "<package name>",
                targets: ["<your target>"]),
        ],
        dependencies: [
           .package(url: "https://github.com/peterhagelund/Serial")
           .package(url: "https://github.com/...")
           .package(url: "https://github.com/...")
        ],
        targets: [
            .target(
                name: "<your target>",
                dependencies: ["Serial", "...", "..."]),
            .testTarget(
                name: "<your test target>",
                dependencies: ["<your target>"]),
        ]
    )

Look at `Tests/SerialTests/SerialPortTests.swift` for quick inspiration. In general:

    import Serial

    guard let serialPort = SerialPort(device: device, baudRate: .bps115200, parity: .none, dataBits: .bits8, stopBits: .bits1) else {
        // Complain and bail
    }
    
    // To write (transmit) bytes:
    let buffer: [UInt8] = ...
    let timeout = ...
    try serialPort.write(buffer: buffer, timeout: timeout))

    // To read (receive) bytes:
    let count = ...
    let timeout = ...
    let buffer = try serialPort.read(count: 8, timeout: timout)

### Error Handling

Since the `SerialPort` class deals with low-level devices, termios attritbutes and I/O in general anything and everything can go wrong.

The initializer (`init?(...)`) is failable - it returns `nil` if the device cannot be opened or any of the termios gymanstics, such as setting baud rate, parity, data- and stop bits fails.

All public functions declare `throws` and in the case of an error, they all throw an instance of `POSIXError` (from `Foundation`) containing a `POSIXErrorCode` initialized from `errno` (and if _that_ fails, the error reported is simply `.EIO`).

### Timeouts

Both `SerialPort.read(...)` and `SerialPort.write(...)` take a timeout value (of type `TimeInterval`. If the read or write fails to complete within the specified time interval, a `POSIXError` with `POSIXErrorCode` `.EWOULDBLOCK` is thrown.
