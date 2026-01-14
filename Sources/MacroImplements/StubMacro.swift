import SwiftSyntax
import SwiftSyntaxMacros

public struct StubMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf decl: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        guard let structDecl = decl.as(StructDeclSyntax.self) else {
            return []
        }

        let properties = StoredPropertyExtractor.extract(
            from: structDecl,
            includeComputedProperties: true
        )
        let parameters = makeParameters(from: properties)
        let arguments = properties.map { "\($0.name): \($0.name)" }.joined(separator: ", ")

        let function: DeclSyntax =
            """
            static func stub(
                \(raw: parameters)
            ) -> Self {
                Self(
                    \(raw: arguments)
                )
            }
            """

        return [function]
    }

    private static func makeParameters(from properties: [StoredProperty]) -> String {
        properties.map {
            "\($0.name): \($0.typeDescription) = \(TypeDefaultValue.value(for: $0.type))"
        }
        .joined(separator: ",\n")
    }
}
