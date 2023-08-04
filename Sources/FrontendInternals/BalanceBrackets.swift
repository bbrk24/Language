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

        guard start.kind != .openBrace else {
            throw UnexpectedToken(found: start, expected: [.openParen, .leftBracket])
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
                case .closeBrace, .rightBracket, .closeParen:
                    throw UnexpectedToken(
                        found: token,
                        expected: [.comma, start.kind == .openParen ? .closeParen : .rightBracket]
                    )
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
        indirect case indexAccess(base: PartiallyParsedExpr, index: [[PartiallyParsedExpr]])
        indirect case propertyAccess(base: PartiallyParsedExpr, property: String)
    }

    static func parseCallsAndAccesses(_ expr: BalancedExpr) throws -> PartiallyParsedExpr {
        switch expr {
        case .token(let token):
            return .token(token)
        case .group(start: let start, body: let innerExprs):
            return .group(start: start, body: try parseCallsAndAccesses(innerExprs))
        }
    }

    static let operators: Set<Lexer.TokenKind> = [
        .equals, .notEquals, .and, .or, .coalesce, .exponent, .lessEqual, .greaterEqual, .assign, .semicolon, .plus,
        .minus, .star, .slash, .percent, .comma, .bang, .greater, .less
    ]

    static func parseCallsAndAccesses<T: RandomAccessCollection>(_ exprs: T) throws -> [PartiallyParsedExpr]
    where T.Element == BalancedExpr, T.Index == Int {
        let maybeCall: (BalancedExpr) -> Bool = {
            switch $0 {
            case .group(start: _, body: _):
                return true
            case .token(let token):
                return token.kind == .dot
            }
        }
        guard var idx = exprs.firstIndex(where: maybeCall) else {
            return try exprs.map(parseCallsAndAccesses)
        }

        var isCall: Bool
        if idx == exprs.startIndex {
            // Might start with a paren but then have a call after that, e.g. (print)(5)
            if exprs.count > 1 && maybeCall(exprs[idx + 1]) {
                idx += 1
                isCall = true
            } else {
                isCall = false
            }
        } else if case .token(let token) = exprs[idx - 1] {
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
            result = try exprs[..<(idx - 1)].map(parseCallsAndAccesses)
            var current = try parseCallsAndAccesses(exprs[idx - 1])
            loop: while idx < exprs.endIndex {
                switch exprs[idx] {
                case .group(start: let token, body: _):
                    switch token.kind {
                    case .openParen:
                        current = .functionApplication(
                            function: current,
                            args: try parseArgumentCallList(exprs[idx]).map(parseCallsAndAccesses)
                        )
                    case .leftBracket:
                        current = .indexAccess(
                            base: current,
                            index: try parseArgumentCallList(exprs[idx]).map(parseCallsAndAccesses)
                        )
                    default:
                        throw UnexpectedToken(found: token, expected: [.openParen, .leftBracket])
                    }
                    idx += 1
                case .token(let token):
                    guard token.kind == .dot else {
                        break loop
                    }
                    guard idx + 1 < exprs.endIndex,
                          case .token(let nextToken) = exprs[idx + 1] else {
                        // Some kind of syntax error, but what?
                        notImplemented()
                    }
                    guard nextToken.kind == .identifier else {
                        throw UnexpectedToken(found: nextToken, expected: [.identifier])
                    }
                    current = .propertyAccess(base: current, property: String(nextToken.text))
                    idx += 2
                }
            }
            result.append(current)
        } else {
            result = try exprs[..<idx].map(parseCallsAndAccesses)
        }
        result.append(contentsOf: try parseCallsAndAccesses(exprs[idx...]))

        return result
    }
}