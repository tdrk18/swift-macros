import Macro
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import MacroImplements

private let macros = [
    "Mockable": MockableMacro.self
]

final class MockableMacroTests: XCTestCase {
    func testSimpleProtocol() {
        assertMacroExpansion(
            """
            @Mockable
            protocol UserRepository {
                func fetch(id: Int) throws -> String
            }
            """,
            expandedSource:
                """
                protocol UserRepository {
                    func fetch(id: Int) throws -> String
                }

                final class MockUserRepository: UserRepository, @unchecked Sendable {
                    var fetchCallCount = 0
                    var fetchReceivedArguments: [(Int)] = []
                    var fetchError: Error?
                    var fetchHandler: ((Int) -> String)? = nil
                    var fetchReturnValue: String!
                    func fetch(id: Int) throws -> String {
                        fetchCallCount += 1
                        fetchReceivedArguments.append((id))
                        if let error = fetchError {
                            throw error
                        }
                        if let handler = fetchHandler {
                            return handler(id)
                        }
                        return fetchReturnValue
                    }
                }
                """,
            macros: macros
        )
    }

    func testUnderscoreParameter() {
        assertMacroExpansion(
            """
            @Mockable
            protocol Repo {
                func save(_ value: Int)
            }
            """,
            expandedSource:
                """
                protocol Repo {
                    func save(_ value: Int)
                }

                final class MockRepo: Repo, @unchecked Sendable {
                    var saveCallCount = 0
                    var saveReceivedArguments: [(Int)] = []
                    func save(_ value: Int) {
                        saveCallCount += 1
                        saveReceivedArguments.append((value))
                    }
                }
                """,
            macros: macros
        )
    }

    func testOptionalReturnValue() {
        assertMacroExpansion(
            """
            @Mockable
            protocol Cache {
                func get(key: String) -> String?
            }
            """,
            expandedSource:
                """
                protocol Cache {
                    func get(key: String) -> String?
                }

                final class MockCache: Cache, @unchecked Sendable {
                    var getCallCount = 0
                    var getReceivedArguments: [(String)] = []
                    var getHandler: ((String) -> String?)? = nil
                    var getReturnValue: String? = nil
                    func get(key: String) -> String? {
                        getCallCount += 1
                        getReceivedArguments.append((key))
                        if let handler = getHandler {
                            return handler(key)
                        }
                        return getReturnValue
                    }
                }
                """,
            macros: macros
        )
    }

    func testVoidReturnValue() {
        assertMacroExpansion(
            """
            @Mockable
            protocol Reporter {
                func send(message: String)
            }
            """,
            expandedSource:
                """
                protocol Reporter {
                    func send(message: String)
                }

                final class MockReporter: Reporter, @unchecked Sendable {
                    var sendCallCount = 0
                    var sendReceivedArguments: [(String)] = []
                    func send(message: String) {
                        sendCallCount += 1
                        sendReceivedArguments.append((message))
                    }
                }
                """,
            macros: macros
        )
    }

    func testReceivedArgumentsUsesInternalName() {
        assertMacroExpansion(
            """
            @Mockable
            protocol Updater {
                func update(userID id: Int, value newValue: String)
            }
            """,
            expandedSource:
                """
                protocol Updater {
                    func update(userID id: Int, value newValue: String)
                }

                final class MockUpdater: Updater, @unchecked Sendable {
                    var updateCallCount = 0
                    var updateReceivedArguments: [(id: Int, newValue: String)] = []
                    func update(userID id: Int, value newValue: String) {
                        updateCallCount += 1
                        updateReceivedArguments.append((id: id, newValue: newValue))
                    }
                }
                """,
            macros: macros
        )
    }

    func testProtocolWithAssociatedTypes() {
        assertMacroExpansion(
            """
            @Mockable
            protocol Cache {
                associatedtype Key: Hashable
                associatedtype Value
                func get(key: Key) -> Value
            }
            """,
            expandedSource:
                """
                protocol Cache {
                    associatedtype Key: Hashable
                    associatedtype Value
                    func get(key: Key) -> Value
                }

                final class MockCache<Key, Value>: Cache, @unchecked Sendable where Key: Hashable {
                    var getCallCount = 0
                    var getReceivedArguments: [(Key)] = []
                    var getHandler: ((Key) -> Value)? = nil
                    var getReturnValue: Value!
                    func get(key: Key) -> Value {
                        getCallCount += 1
                        getReceivedArguments.append((key))
                        if let handler = getHandler {
                            return handler(key)
                        }
                        return getReturnValue
                    }
                }
                """,
            macros: macros
        )
    }

    func testAssociatedTypeWhereClause() {
        assertMacroExpansion(
            """
            @Mockable
            protocol PayloadStore {
                associatedtype Payload where Payload: Codable, Payload == String
                func save(_ payload: Payload)
            }
            """,
            expandedSource:
                """
                protocol PayloadStore {
                    associatedtype Payload where Payload: Codable, Payload == String
                    func save(_ payload: Payload)
                }

                final class MockPayloadStore<Payload>: PayloadStore, @unchecked Sendable where Payload: Codable, Payload == String {
                    var saveCallCount = 0
                    var saveReceivedArguments: [(Payload)] = []
                    func save(_ payload: Payload) {
                        saveCallCount += 1
                        saveReceivedArguments.append((payload))
                    }
                }
                """,
            macros: macros
        )
    }

}
