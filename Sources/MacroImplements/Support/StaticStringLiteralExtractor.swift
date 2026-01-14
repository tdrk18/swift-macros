import SwiftSyntax

enum StaticStringLiteralExtractor {
    static func extract(
        from node: some FreestandingMacroExpansionSyntax,
        macroName: String,
        expectedArgumentCount: Int = 1
    ) throws -> (argument: ExprSyntax, literal: String) {
        let arguments = Array(node.arguments)

        guard arguments.count == expectedArgumentCount else {
            throw MacroDiagnostic.invalidArgumentCount(
                macroName: macroName,
                expected: expectedArgumentCount,
                actual: arguments.count
            )
        }

        guard let argument = arguments.first?.expression,
            let segments = argument.as(StringLiteralExprSyntax.self)?.segments,
            segments.count == 1,
            case .stringSegment(let literalSegment)? = segments.first
        else {
            throw MacroDiagnostic.requiresStaticStringLiteral(macroName)
        }

        return (argument, literalSegment.content.text)
    }
}
