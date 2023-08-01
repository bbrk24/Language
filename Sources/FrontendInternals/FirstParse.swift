extension RangeReplaceableCollection
where Element == Lexer.Token {
    mutating func discardLeadingTrivia() {
        let triviaTokens = self.prefix {
            $0.kind == .whitespace || $0.kind == .lineComment || $0.kind == .blockComment
        }
        self.removeFirst(triviaTokens.count)
    }
}

extension SyntaxTree {
    /// A statement that is partially parsed based on its first token.
    enum PartiallyParsedStatement {
        typealias Token = Lexer.Token

        case whileLoop(condition: [Token], body: [PartiallyParsedStatement])
        case traitDecl(name: String, refining: [Token], body: [PartiallyParsedStatement])
        case structDecl(name: String, body: [PartiallyParsedStatement])
        case implBlock(type: String, traits: [Token], body: [PartiallyParsedStatement])
        case enumDecl(name: String, body: [Token])
        case ifElse(condition: [Lexer.Token], trueBody: [PartiallyParsedStatement], falseBody: [PartiallyParsedStatement])
        case funcDecl(name: String, parameters: [Token], returnType: [Token], body: [PartiallyParsedStatement])
        case varDecl(name: String, type: [Token], initialValue: [Token])
        case `return`([Token])
        case unparsedExpr([Token])
    }

    struct UnexpectedToken: Error {
        var found: Lexer.Token?
        var expected: Set<Lexer.TokenKind>
    }

    @discardableResult
    static func assertStarts(_ tokens: inout Lexer.TokenCollection, with kinds: Set<Lexer.TokenKind>) throws -> Lexer.Token {
        let first = tokens.first
        guard let first, kinds.contains(first.kind) else {
            throw UnexpectedToken(found: first, expected: kinds)
        }
        return first
    }

    static func parseOptionalNonNested(
        _ tokens: inout Lexer.TokenCollection,
        from startToken: Lexer.TokenKind,
        to endTokens: Set<Lexer.TokenKind>
    ) throws -> [Lexer.Token] {
        tokens.discardLeadingTrivia()
        var tkn = try assertStarts(&tokens, with: endTokens.union([.colon]))
        var refiningList = Array<Lexer.Token>()
        if tkn.kind == startToken {
            while true {
                guard let next = tokens.popFirst() else {
                    throw UnexpectedEOF()
                }
                tkn = next
                if endTokens.contains(tkn.kind) {
                    break
                }
                refiningList.append(tkn)
            }
        }

        // Off-by-one error
        tokens = CollectionOfOne(tkn) + tokens

        return refiningList
    }

    private static let cannotStartStatement: Set<Lexer.TokenKind> = [
        .else, .equals, .notEquals, .and, .or, .coalesce, .exponent, .lessEqual, .greaterEqual,
        .assign, .star, .slash, .percent, .comma, .colon, .greater, .less, .dot, .closeBrace,
        .closeParen, .rightBracket, .openBrace
    ]

    private static func parseIfElse(_ tokens: inout Lexer.TokenCollection) throws -> PartiallyParsedStatement {
        tokens.removeFirst() // 'if'
        let condition = try parseParenGroup(&tokens)
        let trueBodyTokens = try parseBraceGroup(&tokens)
        var falseBody = Array<PartiallyParsedStatement>()

        tokens.discardLeadingTrivia()
        if tokens.first?.kind == .else {
            tokens.removeFirst()
            tokens.discardLeadingTrivia()
            if tokens.first?.kind == .if {
                falseBody = [try parseIfElse(&tokens)]
            } else {
                let falseBodyTokens = try parseBraceGroup(&tokens)
                falseBody = try pass1(.init(falseBodyTokens))
            }
        }

        let trueBody = try pass1(.init(trueBodyTokens))

        return .ifElse(condition: condition, trueBody: trueBody, falseBody: falseBody)
    }

    static func pass1(_ tokens: __owned Lexer.TokenCollection) throws -> [PartiallyParsedStatement] {
        var tokens = tokens
        var result = Array<PartiallyParsedStatement>()

        while let first = tokens.first {
            switch first.kind {
            case .whitespace, .lineComment, .blockComment:
                tokens.discardLeadingTrivia()
            case .whileLoop:
                tokens.removeFirst() // 'while'
                
                let condition = try parseParenGroup(&tokens)
                let bodyTokens = try parseBraceGroup(&tokens)
                let body = try pass1(.init(bodyTokens))

                result.append(.whileLoop(condition: condition, body: body))
            case .trait:
                tokens.removeFirst() // 'trait'
                tokens.discardLeadingTrivia()

                let name = try assertStarts(&tokens, with: [.identifier]).text
                let refiningList = try parseOptionalNonNested(&tokens, from: .colon, to: [.openBrace])

                let bodyTokens = try parseBraceGroup(&tokens)
                let body = try pass1(.init(bodyTokens))

                result.append(.traitDecl(name: String(name), refining: refiningList, body: body))
            case .productType:
                tokens.removeFirst() // 'struct'
                tokens.discardLeadingTrivia()

                let name = try assertStarts(&tokens, with: [.identifier]).text

                let bodyTokens = try parseBraceGroup(&tokens)
                let body = try pass1(.init(bodyTokens))

                result.append(.structDecl(name: String(name), body: body))
            case .impl:
                tokens.removeFirst() // 'impl'
                tokens.discardLeadingTrivia()

                let name = try assertStarts(&tokens, with: [.identifier]).text
                let traitList = try parseOptionalNonNested(&tokens, from: .colon, to: [.openBrace])

                let bodyTokens = try parseBraceGroup(&tokens)
                let body = try pass1(.init(bodyTokens))

                result.append(.implBlock(type: String(name), traits: traitList, body: body))
            case .sumType:
                tokens.removeFirst() // 'enum'
                tokens.discardLeadingTrivia()

                let name = try assertStarts(&tokens, with: [.identifier]).text
                let body = try parseBraceGroup(&tokens)

                result.append(.enumDecl(name: String(name), body: body))
            case .funcDecl:
                tokens.removeFirst() // 'func'
                tokens.discardLeadingTrivia()

                let name = try assertStarts(&tokens, with: [.identifier]).text
                let params = try parseParenGroup(&tokens)
                let returnType = try parseOptionalNonNested(&tokens, from: .colon, to: [.openBrace])

                let bodyTokens = try parseBraceGroup(&tokens)
                let body = try pass1(.init(bodyTokens))

                result.append(.funcDecl(
                    name: String(name),
                    parameters: params,
                    returnType: returnType,
                    body: body
                ))
            case .varDecl:
                tokens.removeFirst() // 'var'
                tokens.discardLeadingTrivia()

                let name = try assertStarts(&tokens, with: [.identifier]).text
                let type = try parseOptionalNonNested(&tokens, from: .colon, to: [.semicolon, .assign])
                let initialValue = try parseOptionalNonNested(&tokens, from: .assign, to: [.semicolon])

                result.append(.varDecl(name: String(name), type: type, initialValue: initialValue))
            case .if:
                result.append(try parseIfElse(&tokens))
            case .return:
                tokens.removeFirst() // 'return'

                var exprTokens = Array<Lexer.Token>()
                while tokens.first?.kind != .semicolon {
                    guard let next = tokens.popFirst() else {
                        throw UnexpectedEOF()
                    }
                    exprTokens.append(next)
                }
                tokens.removeFirst() // ';'

                result.append(.return(exprTokens))
            case cannotStartStatement:
                throw UnexpectedToken(
                    found: first,
                    expected: Set(Lexer.TokenKind.allCases).subtracting(cannotStartStatement)
                )
            default:
                var exprTokens = Array<Lexer.Token>()
                while tokens.first?.kind != .semicolon {
                    guard let next = tokens.popFirst() else {
                        throw UnexpectedEOF()
                    }
                    exprTokens.append(next)
                }
                tokens.removeFirst() // ';'
                result.append(.unparsedExpr(exprTokens))
            }
        }

        return result
    }
}