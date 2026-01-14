import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

public enum URLMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        let extracted = try StaticStringLiteralExtractor.extract(
            from: node,
            macroName: "#URL"
        )

        guard URL(string: extracted.literal) != nil else {
            throw MacroDiagnostic.malformedURL(
                macroName: "#URL",
                argument: extracted.argument
            )
        }

        return "URL(string: \(extracted.argument))!"
    }
}
