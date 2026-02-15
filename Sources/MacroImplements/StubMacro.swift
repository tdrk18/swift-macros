import SwiftSyntax
import SwiftSyntaxMacros

public struct StubMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf decl: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        if let structDecl = decl.as(StructDeclSyntax.self) {
            return makeStructStub(structDecl: structDecl)
        }

        if let enumDecl = decl.as(EnumDeclSyntax.self) {
            return makeEnumStub(enumDecl: enumDecl)
        }

        return []
    }

    private static func makeStructStub(structDecl: StructDeclSyntax) -> [DeclSyntax] {
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

    private static func makeEnumStub(enumDecl: EnumDeclSyntax) -> [DeclSyntax] {
        guard
            let firstCase = enumDecl.memberBlock.members.lazy
                .compactMap({ $0.decl.as(EnumCaseDeclSyntax.self) })
                .flatMap({ $0.elements })
                .first
        else {
            return []
        }

        let expression = makeEnumCaseExpression(firstCase)
        let function: DeclSyntax =
            """
            static func stub() -> Self {
                \(raw: expression)
            }
            """

        return [function]
    }

    private static func makeEnumCaseExpression(_ element: EnumCaseElementSyntax) -> String {
        guard
            let parameterClause = element.parameterClause,
            !parameterClause.parameters.isEmpty
        else {
            return ".\(element.name.text)"
        }

        let arguments = parameterClause.parameters.map { parameter in
            let defaultValue = TypeDefaultValue.value(for: parameter.type)
            guard let firstName = parameter.firstName, firstName.text != "_" else {
                return defaultValue
            }
            return "\(firstName.text): \(defaultValue)"
        }
        .joined(separator: ", ")

        return ".\(element.name.text)(\(arguments))"
    }

    private static func makeParameters(from properties: [StoredProperty]) -> String {
        properties.map {
            "\($0.name): \($0.typeDescription) = \(TypeDefaultValue.value(for: $0.type))"
        }
        .joined(separator: ",\n")
    }
}
