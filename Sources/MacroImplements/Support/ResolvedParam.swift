import SwiftSyntax

struct ResolvedParam {
    let value: String
    let type: TypeSyntax

    var typeDescription: String {
        type.normalizedDescription
    }

    var containerKind: GenericContainerKind? {
        type.genericContainerInfo()?.kind
    }

    var isOptional: Bool {
        containerKind == .optional
    }

    var isArray: Bool {
        containerKind == .array
    }

    var isDictionary: Bool {
        containerKind == .dictionary
    }

    var isSet: Bool {
        containerKind == .set
    }
}
