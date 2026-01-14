import SwiftSyntax

enum TypeDefaultValue {
    static func value(for type: TypeSyntax) -> String {
        if let container = type.genericContainerInfo() {
            return defaultValue(for: container.kind)
        }

        if let identifier = type.as(IdentifierTypeSyntax.self) {
            let name = identifier.name.text
            switch name {
            case "Int", "Int64", "Int32", "UInt", "UInt64":
                return "0"
            case "Double", "Float", "CGFloat":
                return "0"
            case "Bool":
                return "false"
            case "String":
                return "\"\""
            case "Date":
                return "Date(timeIntervalSince1970: 0)"
            case "UUID":
                return "UUID()"
            case "URL":
                return "URL(string: \"https://example.com\")!"
            default:
                break
            }
        }

        // Fail safe: let unsupported types surface compile errors.
        return "\(type.normalizedDescription)()"
    }

    private static func defaultValue(for kind: GenericContainerKind) -> String {
        switch kind {
        case .optional:
            return "nil"
        case .array:
            return "[]"
        case .dictionary:
            return "[:]"
        case .set:
            return "Set()"
        }
    }
}
