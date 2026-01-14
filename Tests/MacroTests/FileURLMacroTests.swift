import MacroImplements
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

private let macros: [String: Macro.Type] = [
    "FileURL": FileURLMacro.self
]

final class FileURLMacroTests: XCTestCase {
    func test_expansionWithStringInterpolation() throws {
        assertMacroExpansion(
            #"""
            #FileURL("/path/to/\(domain)/api/path")
            """#,
            expandedSource: #"""
                #FileURL("/path/to/\(domain)/api/path")
                """#,
            diagnostics: [
                DiagnosticSpec(
                    message: "#FileURL requires a static string literal",
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
            let valid = #FileURL("/path/to/file.txt")
            """,
            expandedSource: """
                let valid = URL(fileURLWithPath: "/path/to/file.txt")
                """,
            macros: macros,
        )
    }

    func test_expansionWithInvalidArgumentCount() throws {
        assertMacroExpansion(
            """
            let invalid = #FileURL()
            """,
            expandedSource: """
                let invalid = #FileURL()
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "#FileURL expects 1 argument(s), got 0",
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
            let invalid = #FileURL("a", "b")
            """,
            expandedSource: """
                let invalid = #FileURL("a", "b")
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "#FileURL expects 1 argument(s), got 2",
                    line: 1,
                    column: 15,
                    severity: .error
                )
            ],
            macros: macros,
        )
    }
}
