enum GenericContainerKind {
    case optional
    case array
    case dictionary
    case set

    init?(name: String) {
        switch name {
        case "Optional":
            self = .optional
        case "Array":
            self = .array
        case "Dictionary":
            self = .dictionary
        case "Set":
            self = .set
        default:
            return nil
        }
    }
}
