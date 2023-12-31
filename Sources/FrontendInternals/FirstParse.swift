import DequeModule

extension RangeReplaceableCollection
where Element == Lexer.Token {
    mutating func discardLeadingTrivia() {
        let triviaTokens = self.prefix {
            $0.kind == .whitespace || $0.kind == .lineComment || $0.kind == .blockComment
        }
        self.removeFirst(triviaTokens.count)
    }
}

extension ParseTree {
    /// A statement that is partially parsed based on its first token.
    enum PartiallyParsedStatement {
        typealias Token = Lexer.Token

        case whileLoop(condition: Deque<Token>, body: [PartiallyParsedStatement])
        case traitDecl(name: String, refining: Deque<Token>, body: [PartiallyParsedStatement])
        case structDecl(name: String, body: [PartiallyParsedStatement])
        case implBlock(type: String, traits: Deque<Token>, body: [PartiallyParsedStatement])
        case enumDecl(name: String, body: Deque<Token>)
        case ifElse(condition: Deque<Token>, trueBody: [PartiallyParsedStatement], falseBody: [PartiallyParsedStatement])
        case funcDecl(name: String, parameters: Deque<Token>, returnType: Deque<Token>, body: [PartiallyParsedStatement])
        case varDecl(name: String, type: Deque<Token>, initialValue: Deque<Token>)
        case `return`(Deque<Token>)
        case unparsedExpr(Deque<Token>)
    }

    struct UnexpectedToken: Error, CustomStringConvertible {
        var found: Lexer.Token
        var expected: Set<Lexer.TokenKind>

        var description: String {
            "\(found.startLoc): Unexpected \(found.kind) token (expected one of: \(expected))"
        }
    }

    @discardableResult
    static func assertStarts(_ tokens: inout Deque<Lexer.Token>, with kinds: Set<Lexer.TokenKind>) throws -> Lexer.Token {
        let first = tokens.popFirst()
        guard let first else {
            throw UnexpectedEOF()
        }
        guard kinds.contains(first.kind) else {
            throw UnexpectedToken(found: first, expected: kinds)
        }
        return first
    }

    static func parseOptionalNonNested(
        _ tokens: inout Deque<Lexer.Token>,
        from startToken: Lexer.TokenKind,
        to endTokens: Set<Lexer.TokenKind>
    ) throws -> Deque<Lexer.Token> {
        tokens.discardLeadingTrivia()
        var tkn = try assertStarts(&tokens, with: endTokens.union([.colon]))
        var refiningList = Deque<Lexer.Token>()
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
        tokens.prepend(tkn)

        return refiningList
    }

    static let cannotStartStatement: Set<Lexer.TokenKind> = [
        .else, .equals, .notEquals, .and, .or, .coalesce, .exponent, .lessEqual, .greaterEqual,
        .assign, .star, .slash, .percent, .comma, .colon, .greater, .less, .dot, .closeBrace,
        .closeParen, .rightBracket, .openBrace
    ]

    static func parseIfElse(_ tokens: inout Deque<Lexer.Token>) throws -> PartiallyParsedStatement {
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
                falseBody = try pass1(falseBodyTokens)
            }
        }

        let trueBody = try pass1(trueBodyTokens)

        return .ifElse(condition: condition, trueBody: trueBody, falseBody: falseBody)
    }

    static func pass1(_ tokens: __owned Deque<Lexer.Token>) throws -> [PartiallyParsedStatement] {
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
                let body = try pass1(bodyTokens)

                result.append(.whileLoop(condition: condition, body: body))
            case .trait:
                tokens.removeFirst() // 'trait'
                tokens.discardLeadingTrivia()

                let name = try assertStarts(&tokens, with: [.identifier]).text
                let refiningList = try parseOptionalNonNested(&tokens, from: .colon, to: [.openBrace])

                let bodyTokens = try parseBraceGroup(&tokens)
                let body = try pass1(bodyTokens)

                result.append(.traitDecl(name: String(name), refining: refiningList, body: body))
            case .productType:
                tokens.removeFirst() // 'struct'
                tokens.discardLeadingTrivia()

                let name = try assertStarts(&tokens, with: [.identifier]).text

                let bodyTokens = try parseBraceGroup(&tokens)
                let body = try pass1(bodyTokens)

                result.append(.structDecl(name: String(name), body: body))
            case .impl:
                tokens.removeFirst() // 'impl'
                tokens.discardLeadingTrivia()

                let name = try assertStarts(&tokens, with: [.identifier]).text
                let traitList = try parseOptionalNonNested(&tokens, from: .colon, to: [.openBrace])

                let bodyTokens = try parseBraceGroup(&tokens)
                let body = try pass1(bodyTokens)

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
                let body = try pass1(bodyTokens)

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
                let file = tokens.removeFirst() // 'return'
                    .startLoc.file

                var exprTokens = Deque<Lexer.Token>()
                while tokens.first?.kind != .semicolon {
                    guard let next = tokens.popFirst() else {
                        throw UnexpectedEOF(file: file)
                    }
                    exprTokens.append(next)
                }
                tokens.removeFirst() // ';'

                result.append(.return(exprTokens))
            case cannotStartStatement:
                throw UnexpectedToken(
                    found: first,
                    expected: Set(Lexer.TokenKind.allCases).subtracting(cannotStartStatement)
                        .subtracting([.whitespace, .lineComment, .blockComment])
                )
            default:
                let file = first.startLoc.file
                var exprTokens = Deque<Lexer.Token>()
                while tokens.first?.kind != .semicolon {
                    guard let next = tokens.popFirst() else {
                        throw UnexpectedEOF(file: file)
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