import SwiftSyntax

extension FunctionParameterSyntax {
    func resolvedParam(index: Int) -> ResolvedParam {
        let valueName =
            secondName?.text ?? (firstName.text == "_" ? "arg\(index)" : firstName.text)

        return ResolvedParam(value: valueName, type: type)
    }
}
