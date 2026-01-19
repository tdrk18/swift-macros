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

    func testProtocolWithGenerics() {
        assertMacroExpansion(
            """
            @Mockable
            protocol Cache {
                func get<Key: Hashable>(key: Key) -> String
            }
            """,
            expandedSource:
                """
                protocol Cache {
                    func get<Key: Hashable>(key: Key) -> String
                }

                final class MockCache: Cache, @unchecked Sendable {
                    var getCallCount = 0
                    var getReceivedArguments: [(any Hashable)] = []
                    var getHandler: ((any Hashable) -> String)? = nil
                    var getReturnValue: String!
                    func get<Key: Hashable>(key: Key) -> String {
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

    func testMethodGenericReturnType() {
        assertMacroExpansion(
            """
            @Mockable
            protocol Factory {
                func make<T>() -> T
            }
            """,
            expandedSource:
                """
                protocol Factory {
                    func make<T>() -> T
                }

                final class MockFactory: Factory, @unchecked Sendable {
                    var makeCallCount = 0
                    var makeHandler: (() -> Any)? = nil
                    var makeReturnValue: Any!
                    func make<T>() -> T {
                        makeCallCount += 1
                        if let handler = makeHandler {
                            return (handler()) as! T
                        }
                        return (makeReturnValue) as! T
                    }
                }
                """,
            macros: macros
        )
    }

    func testMethodGenericReturnTypeWithConstraint() {
        assertMacroExpansion(
            """
            @Mockable
            protocol BoxFactory {
                func make<T: Hashable>() -> T
            }
            """,
            expandedSource:
                """
                protocol BoxFactory {
                    func make<T: Hashable>() -> T
                }

                final class MockBoxFactory: BoxFactory, @unchecked Sendable {
                    var makeCallCount = 0
                    var makeHandler: (() -> Any)? = nil
                    var makeReturnValue: Any!
                    func make<T: Hashable>() -> T {
                        makeCallCount += 1
                        if let handler = makeHandler {
                            return (handler()) as! T
                        }
                        return (makeReturnValue) as! T
                    }
                }
                """,
            macros: macros
        )
    }

    func testMethodGenericOptionalReturnType() {
        assertMacroExpansion(
            """
            @Mockable
            protocol OptionalFactory {
                func make<T>() -> T?
            }
            """,
            expandedSource:
                """
                protocol OptionalFactory {
                    func make<T>() -> T?
                }

                final class MockOptionalFactory: OptionalFactory, @unchecked Sendable {
                    var makeCallCount = 0
                    var makeHandler: (() -> Any?)? = nil
                    var makeReturnValue: Any? = nil
                    func make<T>() -> T? {
                        makeCallCount += 1
                        if let handler = makeHandler {
                            return (handler()) as! T?
                        }
                        return (makeReturnValue) as! T?
                    }
                }
                """,
            macros: macros
        )
    }

    func testMethodGenericAssociatedTypeReturn() {
        assertMacroExpansion(
            """
            protocol ResponseProvider {
                associatedtype Response
            }

            @Mockable
            protocol Service {
                func fetch<T: ResponseProvider>() -> T.Response
            }
            """,
            expandedSource:
                """
                protocol ResponseProvider {
                    associatedtype Response
                }
                protocol Service {
                    func fetch<T: ResponseProvider>() -> T.Response
                }

                final class MockService: Service, @unchecked Sendable {
                    var fetchCallCount = 0
                    var fetchHandler: (() -> Any)? = nil
                    var fetchReturnValue: Any!
                    func fetch<T: ResponseProvider>() -> T.Response {
                        fetchCallCount += 1
                        if let handler = fetchHandler {
                            return (handler()) as! T.Response
                        }
                        return (fetchReturnValue) as! T.Response
                    }
                }
                """,
            macros: macros
        )
    }

    func testMethodGenericAssociatedTypeOptionalReturn() {
        assertMacroExpansion(
            """
            protocol ResponseProvider {
                associatedtype Response
            }

            @Mockable
            protocol Service {
                func fetch<T: ResponseProvider>() -> T.Response?
            }
            """,
            expandedSource:
                """
                protocol ResponseProvider {
                    associatedtype Response
                }
                protocol Service {
                    func fetch<T: ResponseProvider>() -> T.Response?
                }

                final class MockService: Service, @unchecked Sendable {
                    var fetchCallCount = 0
                    var fetchHandler: (() -> Any?)? = nil
                    var fetchReturnValue: Any? = nil
                    func fetch<T: ResponseProvider>() -> T.Response? {
                        fetchCallCount += 1
                        if let handler = fetchHandler {
                            return (handler()) as! T.Response?
                        }
                        return (fetchReturnValue) as! T.Response?
                    }
                }
                """,
            macros: macros
        )
    }

    func testMethodGenericAssociatedTypeParameter() {
        assertMacroExpansion(
            """
            protocol ResponseProvider {
                associatedtype Response
            }

            @Mockable
            protocol Service {
                func save<T: ResponseProvider>(response: T.Response)
            }
            """,
            expandedSource:
                """
                protocol ResponseProvider {
                    associatedtype Response
                }
                protocol Service {
                    func save<T: ResponseProvider>(response: T.Response)
                }

                final class MockService: Service, @unchecked Sendable {
                    var saveCallCount = 0
                    var saveReceivedArguments: [(Any)] = []
                    func save<T: ResponseProvider>(response: T.Response) {
                        saveCallCount += 1
                        saveReceivedArguments.append((response))
                    }
                }
                """,
            macros: macros
        )
    }

    func testMethodGenericAssociatedTypeInResultReturn() {
        assertMacroExpansion(
            """
            protocol ResponseProvider {
                associatedtype Response
            }

            @Mockable
            protocol Service {
                func fetch<T: ResponseProvider>() -> Result<T.Response, NSError>
            }
            """,
            expandedSource:
                """
                protocol ResponseProvider {
                    associatedtype Response
                }
                protocol Service {
                    func fetch<T: ResponseProvider>() -> Result<T.Response, NSError>
                }

                final class MockService: Service, @unchecked Sendable {
                    var fetchCallCount = 0
                    var fetchHandler: (() -> Any)? = nil
                    var fetchReturnValue: Any!
                    func fetch<T: ResponseProvider>() -> Result<T.Response, NSError> {
                        fetchCallCount += 1
                        if let handler = fetchHandler {
                            return (handler()) as! Result<T.Response, NSError>
                        }
                        return (fetchReturnValue) as! Result<T.Response, NSError>
                    }
                }
                """,
            macros: macros
        )
    }

    func testMethodGenericAssociatedTypeInResultReturnWithError() {
        assertMacroExpansion(
            """
            protocol ResponseProvider {
                associatedtype Response
            }

            @Mockable
            protocol Service {
                func fetch<T: ResponseProvider>() -> Result<T.Response, Error>
            }
            """,
            expandedSource:
                """
                protocol ResponseProvider {
                    associatedtype Response
                }
                protocol Service {
                    func fetch<T: ResponseProvider>() -> Result<T.Response, Error>
                }

                final class MockService: Service, @unchecked Sendable {
                    var fetchCallCount = 0
                    var fetchHandler: (() -> Any)? = nil
                    var fetchReturnValue: Any!
                    func fetch<T: ResponseProvider>() -> Result<T.Response, Error> {
                        fetchCallCount += 1
                        if let handler = fetchHandler {
                            return (handler()) as! Result<T.Response, Error>
                        }
                        return (fetchReturnValue) as! Result<T.Response, Error>
                    }
                }
                """,
            macros: macros
        )
    }

    func testMethodGenericAssociatedTypeInResultOptionalReturn() {
        assertMacroExpansion(
            """
            protocol ResponseProvider {
                associatedtype Response
            }

            @Mockable
            protocol Service {
                func fetch<T: ResponseProvider>() -> Result<T.Response?, NSError>
            }
            """,
            expandedSource:
                """
                protocol ResponseProvider {
                    associatedtype Response
                }
                protocol Service {
                    func fetch<T: ResponseProvider>() -> Result<T.Response?, NSError>
                }

                final class MockService: Service, @unchecked Sendable {
                    var fetchCallCount = 0
                    var fetchHandler: (() -> Any)? = nil
                    var fetchReturnValue: Any!
                    func fetch<T: ResponseProvider>() -> Result<T.Response?, NSError> {
                        fetchCallCount += 1
                        if let handler = fetchHandler {
                            return (handler()) as! Result<T.Response?, NSError>
                        }
                        return (fetchReturnValue) as! Result<T.Response?, NSError>
                    }
                }
                """,
            macros: macros
        )
    }

    func testAsyncHandlerAwaitSpacing() {
        assertMacroExpansion(
            """
            @Mockable
            protocol Loader {
                func load() async -> String
            }
            """,
            expandedSource:
                """
                protocol Loader {
                    func load() async -> String
                }

                final class MockLoader: Loader, @unchecked Sendable {
                    var loadCallCount = 0
                    var loadHandler: (() async -> String)? = nil
                    var loadReturnValue: String!
                    func load() async -> String {
                        loadCallCount += 1
                        if let handler = loadHandler {
                            return await handler()
                        }
                        return loadReturnValue
                    }
                }
                """,
            macros: macros
        )
    }
}
