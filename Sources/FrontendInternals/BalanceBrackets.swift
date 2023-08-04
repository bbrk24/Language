import DequeModule

extension SyntaxTree {
    struct UnexpectedEOF: Error, CustomStringConvertible {
        var file: String?

        var description: String {
            if let file {
                return "\(file): Unexpected EOF"
            } else {
                return "Unexpected EOF"
            }
        }
    }

    static func parseGroup(
        _ tokens: inout Deque<Lexer.Token>,
        open: Lexer.TokenKind,
        close: Lexer.TokenKind
    ) throws -> Deque<Lexer.Token> {
        tokens.discardLeadingTrivia()
        try assertStarts(&tokens, with: [open])

        var parenCount = 1
        var expr = Deque<Lexer.Token>()
        loop: while true {
            guard let next = tokens.popFirst() else {
                throw UnexpectedEOF()
            }

            switch next.kind {
            case open:
                parenCount += 1
            case close:
                parenCount -= 1
                if parenCount == 0 {
                    break loop
                }
            default:
                break
            }
            
            expr.append(next)
        }

        return expr
    }

    static func parseParenGroup(_ tokens: inout Deque<Lexer.Token>) throws -> Deque<Lexer.Token> {
        return try parseGroup(&tokens, open: .openParen, close: .closeParen)
    }

    static func parseBraceGroup(_ tokens: inout Deque<Lexer.Token>) throws -> Deque<Lexer.Token> {
        return try parseGroup(&tokens, open: .openBrace, close: .closeBrace)
    }

    static func parseBracketGroup(_ tokens: inout Deque<Lexer.Token>) throws -> Deque<Lexer.Token> {
        return try parseGroup(&tokens, open: .leftBracket, close: .rightBracket)
    }

    enum BalancedExpr {
        case token(Lexer.Token)
        case group(start: Lexer.Token, body: [BalancedExpr])
    }

    static func parseBalancedExpr(_ tokens: __owned Deque<Lexer.Token>) throws -> [BalancedExpr] {
        var result = Array<BalancedExpr>()
        var tokens = tokens

        while let next = tokens.first {
            switch next.kind {
            case .openParen:
                let slice = try parseParenGroup(&tokens)
                result.append(.group(start: next, body: try parseBalancedExpr(slice)))
            case .leftBracket:
                let slice = try parseBracketGroup(&tokens)
                result.append(.group(start: next, body: try parseBalancedExpr(slice)))
            case .openBrace:
                let slice = try parseBraceGroup(&tokens)
                result.append(.group(start: next, body: try parseBalancedExpr(slice)))
            default:
                result.append(.token(next))
                tokens.removeFirst()
            }
        }

        return result
    }

    private static func parseArgumentCallList(_ expr: BalancedExpr) throws -> [[BalancedExpr]] {
        guard case .group(start: let start, body: let body) = expr else {
            preconditionFailure()
        }

        guard start.kind == .openParen else {
            throw UnexpectedToken(found: start, expected: [.openParen])
        }

        var result: [[BalancedExpr]] = [[]]
        for item in body {
            if case .token(let token) = item {
                switch token.kind {
                case .whitespace, .lineComment, .blockComment:
                    continue
                case .comma:
                    result.append([])
                    continue
                case .closeBrace, .rightBracket:
                    throw UnexpectedToken(found: token, expected: [.closeParen, .comma])
                default:
                    break
                }
            }
            result[result.count - 1].append(item)
        }
        if result.last!.isEmpty {
            result.removeLast()
        }

        return result
    }

    enum PartiallyParsedExpr {
        case token(Lexer.Token)
        case group(start: Lexer.Token, body: [PartiallyParsedExpr])
        indirect case functionApplication(function: PartiallyParsedExpr, args: [[PartiallyParsedExpr]])
    }

    static func parseFunctionApplications(_ expr: BalancedExpr) throws -> PartiallyParsedExpr {
        switch expr {
        case .token(let token):
            return .token(token)
        case .group(start: let start, body: let innerExprs):
            return .group(start: start, body: try parseFunctionApplications(innerExprs))
        }
    }

    static let operators: Set<Lexer.TokenKind> = [
        .equals, .notEquals, .and, .or, .coalesce, .exponent, .lessEqual, .greaterEqual, .assign, .semicolon, .plus,
        .minus, .star, .slash, .percent, .comma, .bang, .greater, .less
    ]

    static func parseFunctionApplications<T: RandomAccessCollection>(_ exprs: T) throws -> [PartiallyParsedExpr]
    where T.Element == BalancedExpr, T.Index == Int {
        guard let firstOpenParenIdx = exprs.firstIndex(where: {
            if case .group(start: let start, body: _) = $0 {
                return start.kind == .openParen
            }
            return false
        }) else {
            return try exprs.map(parseFunctionApplications)
        }

        var isCall: Bool
        if firstOpenParenIdx == exprs.startIndex {
            isCall = false
        } else if case .token(let token) = exprs[firstOpenParenIdx - 1] {
            switch token.kind {
            case .whitespace, .lineComment, .blockComment, .leftBracket, .openParen, .openBrace:
                preconditionFailure("Token \(token) should have been filtered out during bracket balancing")
            case .identifier:
                isCall = true
            case operators:
                isCall = false
            default:
                throw UnexpectedToken(found: token, expected: operators.union([.identifier]))
            }
        } else {
            isCall = true
        }

        var result: [PartiallyParsedExpr]
        if isCall {
            result = try exprs[..<(firstOpenParenIdx - 1)].map(parseFunctionApplications)
            result.append(
                PartiallyParsedExpr.functionApplication(
                    function: try parseFunctionApplications(exprs[firstOpenParenIdx - 1]),
                    args: try parseArgumentCallList(exprs[firstOpenParenIdx]).map(parseFunctionApplications)
                )
            )
        } else {
            result = try exprs[...firstOpenParenIdx].map(parseFunctionApplications)
        }
        result.append(contentsOf: try parseFunctionApplications(exprs[(firstOpenParenIdx + 1)...]))

        return result
    }
}