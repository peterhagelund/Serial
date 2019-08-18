import XCTest

import SerialTests

var tests = [XCTestCaseEntry]()
tests += SerialTests.allTests()
XCTMain(tests)
