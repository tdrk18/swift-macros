import SwiftSyntax

enum MacroDiagnostic {
    case requiresStaticStringLiteral(String)
    case malformedURL(macroName: String, argument: ExprSyntax)
    case invalidArgumentCount(macroName: String, expected: Int, actual: Int)
}

extension MacroDiagnostic: Error, CustomStringConvertible {
    var description: String {
        switch self {
        case .requiresStaticStringLiteral(let macroName):
            "\(macroName) requires a static string literal"
        case .malformedURL(let macroName, let argument):
            "\(macroName) malformed URL: \(argument)"
        case .invalidArgumentCount(let macroName, let expected, let actual):
            "\(macroName) expects \(expected) argument(s), got \(actual)"
        }
    }
}
