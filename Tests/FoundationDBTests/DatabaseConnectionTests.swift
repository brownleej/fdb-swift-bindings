/*
 * DatabaseConnectionTests.swift
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

import Foundation
import XCTest
import NIO
@testable import FoundationDB

class DatabaseConnectionTests: XCTestCase {
	static var allTests: [(String, (DatabaseConnectionTests) -> () throws -> Void)] {
		return [
			("testTransactionExecutesBlockInTransaction", testTransactionExecutesBlockInTransaction),
			("testTransactionWithFutureExecutesBlockInTransaction", testTransactionWithFutureExecutesBlockInTransaction),
			("testTransactionWithConflictRetriesTransaction", testTransactionWithConflictRetriesTransaction),
			("testTransactionWithNonFdbErrorDoesNotRetryTransaction", testTransactionWithNonFdbErrorDoesNotRetryTransaction),
		]
	}
	
	var connection: InMemoryDatabaseConnection!
	var eventLoop = EmbeddedEventLoop()
	
	override func setUp() {
		super.setUp()
		connection = InMemoryDatabaseConnection(eventLoop: eventLoop)
	}
	
	func testTransactionExecutesBlockInTransaction() throws {
		self.runLoop(eventLoop) {
			return self.connection.transaction {
				(transaction: Transaction) -> Int in
				transaction.store(key: "Test Key 1", value: "Test Value 1")
				return 5
				}.then { value -> EventLoopFuture<Void> in
					XCTAssertEqual(value, 5)
					let transaction = self.connection.startTransaction()
					transaction.read("Test Key 1")
						.map {
							XCTAssertEqual($0, "Test Value 1")
						}
						.catch(self)
					
					return transaction.commit()
				}.catch(self)
		}
	}
	
	func testTransactionWithFutureExecutesBlockInTransaction() throws {
		self.runLoop(eventLoop) {
			self.connection.transaction {
				(transaction: Transaction) -> EventLoopFuture<Int> in
				transaction.store(key: "Test Key 1", value: "Test Value 1")
				return self.eventLoop.newSucceededFuture(result: 5)
				}.then { value -> EventLoopFuture<Void> in
					XCTAssertEqual(value, 5)
					let transaction = self.connection.startTransaction()
					transaction.read("Test Key 1")
						.map { XCTAssertEqual($0, "Test Value 1") }.catch(self)
					return transaction.commit()
				}.catch(self)
		}
	}
	
	func testTransactionWithConflictRetriesTransaction() throws {
		self.runLoop(eventLoop) {
			let key: DatabaseValue = "Test Key"
			self.connection.transaction { $0.store(key: key, value: "Test Value 1") }
				.then { () -> EventLoopFuture<Void> in
					var attemptNumber = 0
					let longTransaction: EventLoopFuture<Void> = self.connection.transaction { transaction -> EventLoopFuture<Void> in
						attemptNumber += 1
						return transaction.read(key).then { value in
							var signal = self.eventLoop.newSucceededFuture(result: Void())
							if attemptNumber == 1 {
								signal = signal.then { _ in self.connection.transaction {
									$0.store(key: key, value: "Test Value 2")
									} }
							}
							
							return signal.map { _ in
								var newValue = value ?? DatabaseValue()
								newValue.increment()
								transaction.store(key: "Test Key", value: newValue)
							}
						}
					}
					
					return longTransaction.then { _ in
						self.connection.transaction { $0.read(key) }.map {
							XCTAssertEqual($0, "Test Value 3")
						}
					}
				}.catch(self)
		}
	}
	
	func testTransactionWithNonFdbErrorDoesNotRetryTransaction() {
		self.runLoop(eventLoop) {
			let transaction = self.connection.transaction {
				$0.store(key: "Test Key", value: "Test Value")
				throw TestError.test
			}
			
			transaction.mapIfError {
				switch($0) {
				case is TestError: break
				default: XCTFail("Unexpected error: \($0)")
				}
				}.then { _ in
					self.connection.transaction { $0.read("Test Key") }.map {
						XCTAssertNil($0)
					}
				}.catch(self)
		}
	}
}
