import SwiftSyntax

extension FunctionParameterListSyntax {
    func resolvedParams() -> [ResolvedParam] {
        enumerated().map { index, param in
            param.resolvedParam(index: index)
        }
    }
}
