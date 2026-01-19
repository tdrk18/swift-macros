import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct MockableMacro: PeerMacro {
    private struct AssociatedTypeInfo {
        let name: String
        let inheritedTypes: InheritedTypeListSyntax?
        let whereClause: GenericWhereClauseSyntax?
    }

    private final class GenericParameterRewriter: SyntaxRewriter {
        let replacements: [String: TypeSyntax]
        let genericNames: Set<String>

        init(replacements: [String: TypeSyntax], genericNames: Set<String>) {
            self.replacements = replacements
            self.genericNames = genericNames
        }

        override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
            if let replacement = replacements[node.name.text] {
                return replacement
            }
            return TypeSyntax(super.visit(node))
        }

        override func visit(_ node: MemberTypeSyntax) -> TypeSyntax {
            if memberTypeUsesGenericBase(node) {
                return TypeSyntax(stringLiteral: "Any")
            }
            return TypeSyntax(super.visit(node))
        }

        private func memberTypeUsesGenericBase(_ node: MemberTypeSyntax) -> Bool {
            var current: TypeSyntax = node.baseType
            while true {
                if let identifier = current.as(IdentifierTypeSyntax.self) {
                    return genericNames.contains(identifier.name.text)
                }
                if let member = current.as(MemberTypeSyntax.self) {
                    current = member.baseType
                    continue
                }
                return false
            }
        }
    }

    private final class GenericTypeUsageVisitor: SyntaxVisitor {
        let names: Set<String>
        private(set) var found = false

        init(names: Set<String>) {
            self.names = names
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
            if names.contains(node.name.text) {
                found = true
                return .skipChildren
            }
            return .visitChildren
        }
    }

    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let protocolDecl = decl.as(ProtocolDeclSyntax.self) else {
            return []
        }

        let protocolName = protocolDecl.name.text
        let mockName = "Mock\(protocolName)"

        let members = protocolDecl.memberBlock.members.flatMap { member -> [DeclSyntax] in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else {
                return []
            }

            return generateMock(for: funcDecl)
        }

        let uncheckedSendableType = AttributedTypeSyntax(
            specifiers: TypeSpecifierListSyntax(),
            attributes: AttributeListSyntax {
                AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("unchecked")))
            },
            baseType: IdentifierTypeSyntax(name: .identifier("Sendable"))
        )
        let associatedTypes = associatedTypeInfos(from: protocolDecl)
        let classDecl = ClassDeclSyntax(
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: .keyword(.final))
            },
            name: .identifier(mockName),
            genericParameterClause: genericParameterClause(from: associatedTypes),
            inheritanceClause: InheritanceClauseSyntax(
                inheritedTypes: InheritedTypeListSyntax {
                    InheritedTypeSyntax(type: TypeSyntax(IdentifierTypeSyntax(name: .identifier(protocolName))))
                    InheritedTypeSyntax(type: TypeSyntax(uncheckedSendableType))
                }
            ),
            genericWhereClause: genericWhereClause(from: associatedTypes),
            memberBlock: MemberBlockSyntax(
                members: MemberBlockItemListSyntax(
                    members.map { MemberBlockItemSyntax(decl: $0) }
                )
            )
        )

        return [DeclSyntax(classDecl)]
    }

    // - Methods
    private static func generateMock(
        for funcDecl: FunctionDeclSyntax
    ) -> [DeclSyntax] {

        let name = funcDecl.name.text
        let params = funcDecl.signature.parameterClause.parameters
        let genericNames = Set(
            funcDecl.genericParameterClause?.parameters.map { $0.name.text } ?? []
        )
        let resolvedParams = params.resolvedParams()
        let genericReplacements = genericParameterReplacements(from: funcDecl)
        let storageParams = resolvedParams.map {
            ResolvedParam(
                value: $0.value,
                type: replacedType($0.type, replacements: genericReplacements, genericNames: genericNames)
            )
        }
        let hasThrows = funcDecl.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let returnTypeSyntax = funcDecl.signature.returnClause?.type
        let usesGenericReturn =
            returnTypeSyntax.map {
                typeUsesGenericParam($0, names: genericNames)
            } ?? false
        let storageReturnType = returnTypeSyntax.map {
            replacedType($0, replacements: genericReplacements, genericNames: genericNames)
        }

        var decls: [VariableDeclSyntax] = [
            VariableDeclSyntax(
                bindingSpecifier: .keyword(.var),
                bindings: PatternBindingListSyntax {
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier("\(name)CallCount")),
                        initializer: InitializerClauseSyntax(
                            value: IntegerLiteralExprSyntax(integerLiteral: 0)
                        )
                    )
                }
            )
        ]

        if !params.isEmpty {
            decls.append(
                VariableDeclSyntax(
                    bindingSpecifier: .keyword(.var),
                    bindings: PatternBindingListSyntax {
                        PatternBindingSyntax(
                            pattern: IdentifierPatternSyntax(identifier: .identifier("\(name)ReceivedArguments")),
                            typeAnnotation: TypeAnnotationSyntax(
                                type: receivedArgumentsType(from: storageParams)
                            ),
                            initializer: InitializerClauseSyntax(
                                value: ArrayExprSyntax(elements: ArrayElementListSyntax())
                            ),
                        )
                    }
                )
            )
        }

        if hasThrows {
            decls.append(
                VariableDeclSyntax(
                    bindingSpecifier: .keyword(.var),
                    bindings: PatternBindingListSyntax {
                        PatternBindingSyntax(
                            pattern: IdentifierPatternSyntax(identifier: .identifier("\(name)Error")),
                            typeAnnotation: TypeAnnotationSyntax(
                                type: TypeSyntax(
                                    OptionalTypeSyntax(
                                        wrappedType: IdentifierTypeSyntax(name: .identifier("Error"))
                                    )
                                )
                            )
                        )
                    }
                )
            )
        }

        if let returnTypeSyntax {
            let isOptionalReturn = returnTypeSyntax.isOptionalType
            let erasedReturnType =
                usesGenericReturn
                ? TypeSyntax(stringLiteral: isOptionalReturn ? "Any?" : "Any")
                : nil
            let handlerType = handlerType(
                params: storageParams,
                isAsync: isAsync,
                returnType: erasedReturnType ?? storageReturnType ?? returnTypeSyntax
            )
            let handlerOptionalType = TypeSyntax(
                stringLiteral: "(\(handlerType.description))?"
            )
            decls.append(
                VariableDeclSyntax(
                    bindingSpecifier: .keyword(.var),
                    bindings: PatternBindingListSyntax {
                        PatternBindingSyntax(
                            pattern: IdentifierPatternSyntax(identifier: .identifier("\(name)Handler")),
                            typeAnnotation: TypeAnnotationSyntax(
                                type: handlerOptionalType
                            ),
                            initializer: InitializerClauseSyntax(
                                value: NilLiteralExprSyntax()
                            )
                        )
                    }
                )
            )

            let returnValueBaseType = erasedReturnType ?? storageReturnType ?? returnTypeSyntax
            let returnValueType =
                isOptionalReturn
                ? returnValueBaseType
                : TypeSyntax(
                    ImplicitlyUnwrappedOptionalTypeSyntax(
                        wrappedType: returnValueBaseType
                    )
                )
            decls.append(
                VariableDeclSyntax(
                    bindingSpecifier: .keyword(.var),
                    bindings: PatternBindingListSyntax {
                        PatternBindingSyntax(
                            pattern: IdentifierPatternSyntax(identifier: .identifier("\(name)ReturnValue")),
                            typeAnnotation: TypeAnnotationSyntax(
                                type: returnValueType
                            ),
                            initializer: isOptionalReturn
                                ? InitializerClauseSyntax(value: NilLiteralExprSyntax())
                                : nil
                        )
                    }
                )
            )
        }

        var bodyItems: [CodeBlockItemSyntax] = [
            incrementStatement("\(name)CallCount")
        ]

        if !params.isEmpty {
            bodyItems.append(
                appendReceivedArgumentsStatement(
                    receiverName: "\(name)ReceivedArguments",
                    params: resolvedParams
                )
            )
        }

        if hasThrows {
            bodyItems.append(
                ifLetStatement(
                    bindingName: "error",
                    value: ExprSyntax(
                        DeclReferenceExprSyntax(baseName: .identifier("\(name)Error"))
                    ),
                    bodyItems: [
                        statement(
                            ThrowStmtSyntax(
                                expression: ExprSyntax(
                                    DeclReferenceExprSyntax(baseName: .identifier("error"))
                                )
                            )
                        )
                    ]
                )
            )
        }

        if returnTypeSyntax != nil {
            let handlerCall = FunctionCallExprSyntax(
                calledExpression: ExprSyntax(
                    DeclReferenceExprSyntax(baseName: .identifier("handler"))
                ),
                leftParen: .leftParenToken(),
                arguments: handlerArgumentList(from: resolvedParams),
                rightParen: .rightParenToken()
            )
            let handlerCallExpr = ExprSyntax(handlerCall)
            let handlerReturnExpr =
                isAsync
                ? ExprSyntax(
                    AwaitExprSyntax(
                        awaitKeyword: .keyword(.await, trailingTrivia: .spaces(1)),
                        expression: handlerCallExpr
                    )
                )
                : handlerCallExpr
            let handlerReturnValue =
                usesGenericReturn
                ? castExpr(handlerReturnExpr, to: returnTypeSyntax)
                : handlerReturnExpr
            bodyItems.append(
                ifLetStatement(
                    bindingName: "handler",
                    value: ExprSyntax(
                        DeclReferenceExprSyntax(baseName: .identifier("\(name)Handler"))
                    ),
                    bodyItems: [
                        statement(
                            ReturnStmtSyntax(
                                expression: handlerReturnValue
                            )
                        )
                    ]
                )
            )

            let returnValueExpr = ExprSyntax(
                DeclReferenceExprSyntax(baseName: .identifier("\(name)ReturnValue"))
            )
            let returnValue =
                usesGenericReturn
                ? castExpr(returnValueExpr, to: returnTypeSyntax)
                : returnValueExpr
            bodyItems.append(
                statement(
                    ReturnStmtSyntax(
                        expression: returnValue
                    )
                )
            )
        }

        let declSyntaxes = decls.map { DeclSyntax($0) }
        let body = CodeBlockSyntax(statements: CodeBlockItemListSyntax(bodyItems))
        let signature = FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: funcDecl.signature.effectSpecifiers,
            returnClause: funcDecl.signature.returnClause
        )
        var functionDecl = FunctionDeclSyntax(
            name: funcDecl.name,
            signature: signature,
            body: body
        )
        functionDecl = functionDecl.with(\.genericParameterClause, funcDecl.genericParameterClause)
        functionDecl = functionDecl.with(\.genericWhereClause, funcDecl.genericWhereClause)

        return declSyntaxes + [DeclSyntax(functionDecl)]
    }

    private static func receivedArgumentsType(from params: [ResolvedParam]) -> TypeSyntax {
        let tupleType = TupleTypeSyntax(elements: receivedArgumentsTupleTypeElements(from: params))
        let arrayType = ArrayTypeSyntax(element: TypeSyntax(tupleType))
        return TypeSyntax(arrayType)
    }

    private static func typeUsesGenericParam(
        _ type: TypeSyntax,
        names: Set<String>
    ) -> Bool {
        guard !names.isEmpty else {
            return false
        }
        let visitor = GenericTypeUsageVisitor(names: names)
        visitor.walk(type)
        return visitor.found
    }

    private static func genericParameterReplacements(
        from funcDecl: FunctionDeclSyntax
    ) -> [String: TypeSyntax] {
        guard let genericClause = funcDecl.genericParameterClause else {
            return [:]
        }

        var inheritedConstraints: [String: [TypeSyntax]] = [:]
        for param in genericClause.parameters {
            guard let inheritedType = param.inheritedType else {
                continue
            }
            inheritedConstraints[param.name.text, default: []].append(inheritedType)
        }

        var sameTypeConstraints: [String: TypeSyntax] = [:]
        if let whereClause = funcDecl.genericWhereClause {
            for requirement in whereClause.requirements {
                switch requirement.requirement {
                case .conformanceRequirement(let conformance):
                    if let leftIdentifier = conformance.leftType.as(IdentifierTypeSyntax.self) {
                        inheritedConstraints[leftIdentifier.name.text, default: []].append(
                            conformance.rightType
                        )
                    }
                case .sameTypeRequirement(let sameType):
                    if let leftIdentifier = sameType.leftType.as(IdentifierTypeSyntax.self) {
                        sameTypeConstraints[leftIdentifier.name.text] = TypeSyntax(sameType.rightType)
                    } else if let rightIdentifier = sameType.rightType.as(IdentifierTypeSyntax.self) {
                        sameTypeConstraints[rightIdentifier.name.text] = TypeSyntax(sameType.leftType)
                    }
                default:
                    continue
                }
            }
        }

        var replacements: [String: TypeSyntax] = [:]
        for param in genericClause.parameters {
            let name = param.name.text
            if let sameType = sameTypeConstraints[name] {
                replacements[name] = sameType
                continue
            }

            let constraints = inheritedConstraints[name] ?? []
            if constraints.isEmpty {
                replacements[name] = TypeSyntax(stringLiteral: "Any")
                continue
            }

            let constraintNames = constraints.map { $0.normalizedDescription }.joined(separator: " & ")
            replacements[name] = TypeSyntax(stringLiteral: "any \(constraintNames)")
        }

        return replacements
    }

    private static func replacedType(
        _ type: TypeSyntax,
        replacements: [String: TypeSyntax],
        genericNames: Set<String>
    ) -> TypeSyntax {
        guard !replacements.isEmpty else {
            return type
        }
        let rewriter = GenericParameterRewriter(
            replacements: replacements,
            genericNames: genericNames
        )
        let rewritten = rewriter.rewrite(Syntax(type))
        return rewritten.as(TypeSyntax.self) ?? type
    }

    private static func castExpr(
        _ expr: ExprSyntax,
        to returnType: TypeSyntax?
    ) -> ExprSyntax {
        guard let returnType else {
            return expr
        }
        return ExprSyntax(
            stringLiteral: "(\(expr.description)) as! \(returnType.description)"
        )
    }

    private static func associatedTypeInfos(
        from protocolDecl: ProtocolDeclSyntax
    ) -> [AssociatedTypeInfo] {
        var infos: [AssociatedTypeInfo] = []
        var seen = Set<String>()

        for member in protocolDecl.memberBlock.members {
            guard let associatedType = member.decl.as(AssociatedTypeDeclSyntax.self) else {
                continue
            }
            let name = associatedType.name.text
            guard seen.insert(name).inserted else {
                continue
            }
            infos.append(
                AssociatedTypeInfo(
                    name: name,
                    inheritedTypes: associatedType.inheritanceClause?.inheritedTypes,
                    whereClause: associatedType.genericWhereClause
                )
            )
        }

        return infos
    }

    private static func genericParameterClause(
        from associatedTypes: [AssociatedTypeInfo]
    ) -> GenericParameterClauseSyntax? {
        guard !associatedTypes.isEmpty else {
            return nil
        }

        let parameters = GenericParameterListSyntax(
            associatedTypes.enumerated().map { index, info in
                var parameter = GenericParameterSyntax(name: .identifier(info.name))
                if index < associatedTypes.count - 1 {
                    parameter = parameter.with(\.trailingComma, .commaToken())
                }
                return parameter
            }
        )
        return GenericParameterClauseSyntax(
            leftAngle: .leftAngleToken(),
            parameters: parameters,
            rightAngle: .rightAngleToken()
        )
    }

    private static func genericWhereClause(
        from associatedTypes: [AssociatedTypeInfo]
    ) -> GenericWhereClauseSyntax? {
        var requirements: [GenericRequirementSyntax] = []

        for info in associatedTypes {
            if let inheritedTypes = info.inheritedTypes {
                for inheritedType in inheritedTypes {
                    let leftType = TypeSyntax(
                        IdentifierTypeSyntax(name: .identifier(info.name))
                    )
                    let requirement = GenericRequirementSyntax(
                        requirement: .conformanceRequirement(
                            ConformanceRequirementSyntax(
                                leftType: leftType,
                                colon: .colonToken(),
                                rightType: inheritedType.type
                            )
                        )
                    )
                    requirements.append(requirement)
                }
            }

            if let whereClause = info.whereClause {
                requirements.append(
                    contentsOf: whereClause.requirements.map {
                        $0.with(\.trailingComma, nil)
                    }
                )
            }
        }

        guard !requirements.isEmpty else {
            return nil
        }

        let requirementList = GenericRequirementListSyntax(
            requirements.enumerated().map { index, requirement in
                var item = requirement
                if index < requirements.count - 1 {
                    item = item.with(\.trailingComma, .commaToken())
                }
                return item
            }
        )

        return GenericWhereClauseSyntax(
            whereKeyword: .keyword(.where),
            requirements: requirementList
        )
    }

    private static func handlerType(
        params: [ResolvedParam],
        isAsync: Bool,
        returnType: TypeSyntax
    ) -> TypeSyntax {
        let parameters = handlerTupleTypeElements(from: params)
        let effectSpecifiers =
            isAsync
            ? TypeEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async),
                throwsClause: nil
            )
            : nil
        let returnClause = ReturnClauseSyntax(type: returnType)
        let functionType = FunctionTypeSyntax(
            parameters: parameters,
            effectSpecifiers: effectSpecifiers,
            returnClause: returnClause
        )
        return TypeSyntax(functionType)
    }

    private static func statement(_ stmt: some StmtSyntaxProtocol) -> CodeBlockItemSyntax {
        CodeBlockItemSyntax(item: .stmt(StmtSyntax(stmt)))
    }

    private static func ifLetStatement(
        bindingName: String,
        value: ExprSyntax,
        bodyItems: [CodeBlockItemSyntax]
    ) -> CodeBlockItemSyntax {
        let condition = OptionalBindingConditionSyntax(
            bindingSpecifier: .keyword(.let),
            pattern: IdentifierPatternSyntax(identifier: .identifier(bindingName)),
            initializer: InitializerClauseSyntax(
                value: value
            )
        )
        let ifExpr = IfExprSyntax(
            conditions: ConditionElementListSyntax {
                ConditionElementSyntax(condition: .optionalBinding(condition))
            },
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax(bodyItems)
            )
        )
        return statement(ExpressionStmtSyntax(expression: ExprSyntax(ifExpr)))
    }

    private static func incrementStatement(_ name: String) -> CodeBlockItemSyntax {
        let expr = SequenceExprSyntax {
            ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
            ExprSyntax(BinaryOperatorExprSyntax(operator: "+="))
            ExprSyntax(IntegerLiteralExprSyntax(integerLiteral: 1))
        }
        return statement(ExpressionStmtSyntax(expression: ExprSyntax(expr)))
    }

    private static func handlerArgumentList(from params: [ResolvedParam]) -> LabeledExprListSyntax {
        LabeledExprListSyntax(
            params.enumerated().map { index, param in
                var element = LabeledExprSyntax(
                    expression: ExprSyntax(
                        DeclReferenceExprSyntax(baseName: .identifier(param.value))
                    )
                )
                if index < params.count - 1 {
                    element = element.with(\.trailingComma, .commaToken())
                }
                return element
            }
        )
    }

    private static func handlerTupleTypeElements(
        from params: [ResolvedParam]
    ) -> TupleTypeElementListSyntax {
        TupleTypeElementListSyntax(
            params.enumerated().map { index, param in
                var element = TupleTypeElementSyntax(type: param.type)
                if index < params.count - 1 {
                    element = element.with(\.trailingComma, .commaToken())
                }
                return element
            }
        )
    }

    private static func receivedArgumentsTupleTypeElements(
        from params: [ResolvedParam]
    ) -> TupleTypeElementListSyntax {
        if params.count == 1, let param = params.first {
            return TupleTypeElementListSyntax {
                TupleTypeElementSyntax(type: param.type)
            }
        }

        return TupleTypeElementListSyntax(
            params.enumerated().map { index, param in
                var element = TupleTypeElementSyntax(
                    firstName: .identifier(param.value),
                    colon: .colonToken(),
                    type: param.type
                )
                if index < params.count - 1 {
                    element = element.with(\.trailingComma, .commaToken())
                }
                return element
            }
        )
    }

    private static func appendReceivedArgumentsStatement(
        receiverName: String,
        params: [ResolvedParam]
    ) -> CodeBlockItemSyntax {
        let tupleElements = receivedArgumentsTupleElements(from: params)
        let tupleExpr = TupleExprSyntax(elements: tupleElements)
        let wrappedTuple = ExprSyntax(tupleExpr)
        let callExpr = FunctionCallExprSyntax(
            calledExpression: ExprSyntax(
                MemberAccessExprSyntax(
                    base: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(receiverName))),
                    declName: DeclReferenceExprSyntax(baseName: .identifier("append"))
                )
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                LabeledExprSyntax(expression: wrappedTuple)
            },
            rightParen: .rightParenToken()
        )
        return statement(ExpressionStmtSyntax(expression: ExprSyntax(callExpr)))
    }

    private static func receivedArgumentsTupleElements(
        from params: [ResolvedParam]
    ) -> LabeledExprListSyntax {
        if params.count == 1, let param = params.first {
            return LabeledExprListSyntax {
                LabeledExprSyntax(
                    expression: ExprSyntax(
                        DeclReferenceExprSyntax(baseName: .identifier(param.value))
                    )
                )
            }
        }

        return LabeledExprListSyntax(
            params.enumerated().map { index, param in
                var element = LabeledExprSyntax(
                    label: .identifier(param.value),
                    colon: .colonToken(),
                    expression: ExprSyntax(
                        DeclReferenceExprSyntax(baseName: .identifier(param.value))
                    )
                )
                if index < params.count - 1 {
                    element = element.with(\.trailingComma, .commaToken())
                }
                return element
            }
        )
    }

}
