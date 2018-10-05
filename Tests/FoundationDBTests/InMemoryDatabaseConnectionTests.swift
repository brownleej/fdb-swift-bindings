/*
 * InMemoryDatabaseConnectionTests.swift
 *
 * This source file is part of the FoundationDB open source project
 *
 * Copyright 2016-2018 Apple Inc. and the FoundationDB project authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import XCTest
import Foundation
import NIO
import CFoundationDB
@testable import FoundationDB

class InMemoryDatabaseConnectionTests: XCTestCase {
	let eventLoop = EmbeddedEventLoop()
	var connection: InMemoryDatabaseConnection!
	
	static var allTests : [(String, (InMemoryDatabaseConnectionTests) -> () throws -> Void)] {
		return [
			("testSubscriptAllowsGettingAndSettingValues", testSubscriptAllowsGettingAndSettingValues),
			("testKeysReturnsKeysInRange", testKeysReturnsKeysInRange),
			("testStartTransactionCreatesInMemoryTransaction", testStartTransactionCreatesInMemoryTransaction),
		]
	}
	
	override func setUp() {
		super.setUp()
		connection = InMemoryDatabaseConnection(eventLoop: eventLoop)
	}
	
	override func tearDown() {
	}
	
	func testSubscriptAllowsGettingAndSettingValues() {
		connection["Test Key 1"] = "Test Value 1"
		connection["Test Key 2"] = "Test Value 2"
		XCTAssertEqual(connection["Test Key 1"], "Test Value 1")
		XCTAssertEqual(connection["Test Key 2"], "Test Value 2")
	}
	
	func testKeysReturnsKeysInRange() {
		connection["Test Key 1"] = "Test Value 1"
		connection["Test Key 2"] = "Test Value 2"
		connection["Test Key 3"] = "Test Value 3"
		connection["Test Key 4"] = "Test Value 4"
		let keys = connection.keys(from: "Test Key 1", to: "Test Key 3")
		XCTAssertEqual(keys, ["Test Key 1", "Test Key 2"])
	}
	
	func testStartTransactionCreatesInMemoryTransaction() {
		let transaction = connection.startTransaction() as? InMemoryTransaction
		XCTAssertNotNil(transaction)
		XCTAssertEqual(transaction?.readVersion, connection.currentVersion)
	}
}
