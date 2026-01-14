import SwiftSyntax
import SwiftSyntaxMacros

public enum FileURLMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        let extracted = try StaticStringLiteralExtractor.extract(
            from: node,
            macroName: "#FileURL"
        )

        return "URL(fileURLWithPath: \(extracted.argument))"
    }
}
