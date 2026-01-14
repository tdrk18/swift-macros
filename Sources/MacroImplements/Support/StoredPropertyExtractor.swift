import SwiftSyntax

struct StoredProperty {
    let name: String
    let type: TypeSyntax
    let initializer: InitializerClauseSyntax?

    var typeDescription: String {
        type.description
    }
}

enum StoredPropertyExtractor {
    static func extract(
        from structDecl: StructDeclSyntax,
        includeComputedProperties: Bool
    ) -> [StoredProperty] {
        structDecl.memberBlock.members.compactMap { member -> StoredProperty? in
            guard
                let varDecl = member.decl.as(VariableDeclSyntax.self),
                varDecl.bindings.count == 1,
                let binding = varDecl.bindings.first,
                let id = binding.pattern.as(IdentifierPatternSyntax.self),
                let type = binding.typeAnnotation?.type
            else {
                return nil
            }

            if !includeComputedProperties, binding.accessorBlock != nil {
                return nil
            }

            return StoredProperty(
                name: id.identifier.text,
                type: type,
                initializer: binding.initializer
            )
        }
    }
}
