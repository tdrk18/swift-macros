import Foundation
import SwiftSyntax

extension TypeSyntax {
    var normalizedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isOptionalType: Bool {
        genericContainerInfo()?.kind == .optional
    }

    func genericContainerInfo() -> (kind: GenericContainerKind, arguments: [TypeSyntax])? {
        if let optional = self.as(OptionalTypeSyntax.self) {
            return (.optional, [optional.wrappedType])
        }

        if let array = self.as(ArrayTypeSyntax.self) {
            return (.array, [array.element])
        }

        if let dictionary = self.as(DictionaryTypeSyntax.self) {
            return (.dictionary, [dictionary.key, dictionary.value])
        }

        if let identifier = self.as(IdentifierTypeSyntax.self),
            let kind = GenericContainerKind(name: identifier.name.text)
        {
            let arguments =
                identifier.genericArgumentClause?.arguments
                .compactMap { argument -> TypeSyntax? in
                    guard case .type(let type) = argument.argument else {
                        return nil
                    }
                    return type
                } ?? []
            return (kind, arguments)
        }

        if let member = self.as(MemberTypeSyntax.self),
            let kind = GenericContainerKind(name: member.name.text)
        {
            let arguments =
                member.genericArgumentClause?.arguments
                .compactMap { argument -> TypeSyntax? in
                    guard case .type(let type) = argument.argument else {
                        return nil
                    }
                    return type
                } ?? []
            return (kind, arguments)
        }

        return nil
    }
}
