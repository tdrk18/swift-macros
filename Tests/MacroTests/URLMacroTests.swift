import MacroImplements
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

private let macros: [String: Macro.Type] = [
    "URL": URLMacro.self
]

final class URLMacroTests: XCTestCase {
    func test_expansionWithMalFormedURL() throws {
        assertMacroExpansion(
            """
            let invalid = #URL("https://not a url.com:invalid-port/")
            """,
            expandedSource: """
                let invalid = #URL("https://not a url.com:invalid-port/")
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "#URL malformed URL: \"https://not a url.com:invalid-port/\"",
                    line: 1,
                    column: 15,
                    severity: .error
                )
            ],
            macros: macros,
        )
    }

    func test_expansionWithStringInterpolation() throws {
        assertMacroExpansion(
            #"""
            #URL("https://\(domain)/api/path")
            """#,
            expandedSource: #"""
                #URL("https://\(domain)/api/path")
                """#,
            diagnostics: [
                DiagnosticSpec(
                    message: "#URL requires a static string literal",
                    line: 1,
                    column: 1,
                    severity: .error
                )
            ],
            macros: macros,
        )
    }

    func test_expansionWithValidURL() throws {
        assertMacroExpansion(
            """
            let valid = #URL("https://github.com/tdrk18")
            """,
            expandedSource: """
                let valid = URL(string: "https://github.com/tdrk18")!
                """,
            macros: macros,
        )
    }

    func test_expansionWithInvalidArgumentCount() throws {
        assertMacroExpansion(
            """
            let invalid = #URL()
            """,
            expandedSource: """
                let invalid = #URL()
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "#URL expects 1 argument(s), got 0",
                    line: 1,
                    column: 15,
                    severity: .error
                )
            ],
            macros: macros,
        )
    }

    func test_expansionWithTooManyArguments() throws {
        assertMacroExpansion(
            """
            let invalid = #URL("a", "b")
            """,
            expandedSource: """
                let invalid = #URL("a", "b")
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "#URL expects 1 argument(s), got 2",
                    line: 1,
                    column: 15,
                    severity: .error
                )
            ],
            macros: macros,
        )
    }
}
