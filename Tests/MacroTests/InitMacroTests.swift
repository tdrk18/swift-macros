import Macro
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import MacroImplements

private let macros = [
    "Init": InitMacro.self
]

final class InitMacroTests: XCTestCase {
    func testInitMacroPublic() {
        assertMacroExpansion(
            """
            @Init(.public)
            struct User {
                let id: Int
                let name: String
            }
            """,
            expandedSource:
                """
                struct User {
                    let id: Int
                    let name: String

                    public init(id: Int, name: String) {
                        self.id = id
                        self.name = name
                    }
                }
                """,
            macros: macros,
        )
    }

    func testInitMacroInternal() {
        assertMacroExpansion(
            """
            @Init(.internal)
            struct User {
                let id: Int
                let name: String
            }
            """,
            expandedSource:
                """
                struct User {
                    let id: Int
                    let name: String

                    init(id: Int, name: String) {
                        self.id = id
                        self.name = name
                    }
                }
                """,
            macros: macros,
        )
    }

    func testInitMacroFileprivate() {
        assertMacroExpansion(
            """
            @Init(.fileprivate)
            struct User {
                let id: Int
                let name: String
            }
            """,
            expandedSource:
                """
                struct User {
                    let id: Int
                    let name: String

                    fileprivate init(id: Int, name: String) {
                        self.id = id
                        self.name = name
                    }
                }
                """,
            macros: macros,
        )
    }

    func testInitMacroPrivate() {
        assertMacroExpansion(
            """
            @Init(.private)
            struct User {
                let id: Int
                let name: String
            }
            """,
            expandedSource:
                """
                struct User {
                    let id: Int
                    let name: String

                    private init(id: Int, name: String) {
                        self.id = id
                        self.name = name
                    }
                }
                """,
            macros: macros,
        )
    }

    func testInitMacroWithInitializedValue() {
        assertMacroExpansion(
            """
            @Init
            struct User {
                let id: UUID = UUID()
                let name: String
            }
            """,
            expandedSource:
                """
                struct User {
                    let id: UUID = UUID()
                    let name: String

                    init(id: UUID = UUID(), name: String) {
                        self.id = id
                        self.name = name
                    }
                }
                """,
            macros: macros,
        )
    }
}
