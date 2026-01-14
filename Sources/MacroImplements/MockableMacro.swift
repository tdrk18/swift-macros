import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct MockableMacro: PeerMacro {

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
        let classDecl = ClassDeclSyntax(
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: .keyword(.final))
            },
            name: .identifier(mockName),
            inheritanceClause: InheritanceClauseSyntax(
                inheritedTypes: InheritedTypeListSyntax {
                    InheritedTypeSyntax(type: TypeSyntax(IdentifierTypeSyntax(name: .identifier(protocolName))))
                    InheritedTypeSyntax(type: TypeSyntax(uncheckedSendableType))
                }
            ),
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
        let resolvedParams = params.resolvedParams()
        let receivedArgumentsType = receivedArgumentsType(from: resolvedParams)
        let hasThrows = funcDecl.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let returnTypeSyntax = funcDecl.signature.returnClause?.type

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
                                type: receivedArgumentsType
                            ),
                            initializer: InitializerClauseSyntax(
                                value: ArrayExprSyntax(elements: ArrayElementListSyntax())
                            )
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
            let handlerType = handlerType(
                params: resolvedParams,
                isAsync: isAsync,
                returnType: returnTypeSyntax
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

            let returnValueType =
                isOptionalReturn
                ? returnTypeSyntax
                : TypeSyntax(
                    ImplicitlyUnwrappedOptionalTypeSyntax(
                        wrappedType: returnTypeSyntax
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
                ? ExprSyntax(AwaitExprSyntax(expression: handlerCallExpr))
                : handlerCallExpr
            bodyItems.append(
                ifLetStatement(
                    bindingName: "handler",
                    value: ExprSyntax(
                        DeclReferenceExprSyntax(baseName: .identifier("\(name)Handler"))
                    ),
                    bodyItems: [
                        statement(
                            ReturnStmtSyntax(
                                expression: handlerReturnExpr
                            )
                        )
                    ]
                )
            )

            bodyItems.append(
                statement(
                    ReturnStmtSyntax(
                        expression: ExprSyntax(
                            DeclReferenceExprSyntax(baseName: .identifier("\(name)ReturnValue"))
                        )
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
        let functionDecl = FunctionDeclSyntax(
            name: funcDecl.name,
            signature: signature,
            body: body
        )

        return declSyntaxes + [DeclSyntax(functionDecl)]
    }

    private static func receivedArgumentsType(from params: [ResolvedParam]) -> TypeSyntax {
        let tupleType = TupleTypeSyntax(elements: receivedArgumentsTupleTypeElements(from: params))
        let arrayType = ArrayTypeSyntax(element: TypeSyntax(tupleType))
        return TypeSyntax(arrayType)
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
