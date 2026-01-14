import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct InitMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf decl: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        guard let structDecl = decl.as(StructDeclSyntax.self) else {
            return []
        }

        let access = extractAccess(from: node)
        let properties = StoredPropertyExtractor.extract(
            from: structDecl,
            includeComputedProperties: false
        )

        let initDecl = InitializerDeclSyntax(
            modifiers: accessModifiers(from: access),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: parameterList(from: properties)
                )
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax(
                    properties.map { assignmentStatement(for: $0) }
                )
            )
        )

        return [DeclSyntax(initDecl)]
    }

    private static func extractAccess(
        from attribute: AttributeSyntax
    ) -> String {
        guard
            let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
            let first = arguments.first,
            let member = first.expression
                .as(MemberAccessExprSyntax.self)
        else {
            return ""
        }

        let value = member.declName.baseName.text

        switch value {
        case "public":
            return "public"
        case "fileprivate":
            return "fileprivate"
        case "private":
            return "private"
        default:
            return ""
        }
    }

    private static func accessModifiers(from access: String) -> DeclModifierListSyntax {
        let keyword: Keyword?
        switch access {
        case "public":
            keyword = .public
        case "fileprivate":
            keyword = .fileprivate
        case "private":
            keyword = .private
        default:
            keyword = nil
        }

        guard let keyword else {
            return DeclModifierListSyntax()
        }

        return DeclModifierListSyntax {
            DeclModifierSyntax(name: .keyword(keyword))
        }
    }

    private static func parameterList(
        from properties: [StoredProperty]
    ) -> FunctionParameterListSyntax {
        FunctionParameterListSyntax(
            properties.enumerated().map { index, property in
                var parameter = FunctionParameterSyntax(
                    firstName: .identifier(property.name),
                    colon: .colonToken(),
                    type: property.type,
                    defaultValue: property.initializer
                )
                if index < properties.count - 1 {
                    parameter = parameter.with(\.trailingComma, .commaToken())
                }
                return parameter
            }
        )
    }

    private static func assignmentStatement(
        for property: StoredProperty
    ) -> CodeBlockItemSyntax {
        let selfAccess = MemberAccessExprSyntax(
            base: ExprSyntax(
                DeclReferenceExprSyntax(baseName: .identifier("self"))
            ),
            declName: DeclReferenceExprSyntax(baseName: .identifier(property.name))
        )
        let expr = SequenceExprSyntax {
            ExprSyntax(selfAccess)
            ExprSyntax(BinaryOperatorExprSyntax(operator: "="))
            ExprSyntax(
                DeclReferenceExprSyntax(baseName: .identifier(property.name))
            )
        }
        return CodeBlockItemSyntax(
            item: .stmt(
                StmtSyntax(
                    ExpressionStmtSyntax(expression: ExprSyntax(expr))
                )
            )
        )
    }
}
