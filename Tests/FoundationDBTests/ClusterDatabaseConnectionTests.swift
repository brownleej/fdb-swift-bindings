/*
 * ClusterDatabaseConnectionTests.swift
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
@testable import FoundationDB
import CFoundationDB
import NIO

class ClusterDatabaseConnectionTests: XCTestCase {
	let eventLoop = EmbeddedEventLoop()
	var connection: ClusterDatabaseConnection? = nil
	
	static var allTests : [(String, (ClusterDatabaseConnectionTests) -> () throws -> Void)] {
		return [
			("testStartTransactionCreatesClusterTransaction", testStartTransactionCreatesClusterTransaction),
		]
	}
	
	override func setUp() {
		super.setUp()
		setFdbApiVersion(FDB_API_VERSION)
		
		if connection == nil {
			do {
				connection = try ClusterDatabaseConnection(eventLoop: eventLoop)
			}
			catch let error {
				print("Error creating database connection for testing: \(error)")
			}
		}
		
		self.runLoop(eventLoop) {
			_ = self.connection?.transaction {
				$0.clear(range: Tuple().childRange)
			}
		}
	}
	
	func testStartTransactionCreatesClusterTransaction() throws {
		self.runLoop(eventLoop) {
			guard let connection = self.connection else { return XCTFail() }
			
			let transaction = connection.startTransaction()
			XCTAssertTrue(transaction is ClusterTransaction)
			transaction.commit().mapIfError { XCTFail("\($0)") }.catch(self)
		}
	}
}
