import RegexBuilder

extension Lexer {
    enum TokenKind: String, CaseIterable, Codable, Hashable {
        // Trivia
        case whitespace
        case lineComment
        case blockComment
        // Keywords
        case `return`
        case whileLoop
        case `false`
        case trait
        case productType
        case impl
        case sumType
        case `else`
        case null
        case `true`
        case funcDecl
        case varDecl
        case `if`
        // Identifiers
        case identifier
        // Literals
        case number
        case string
        // Punctuation
        case equals
        case notEquals
        case and
        case or
        case coalesce
        case exponent
        case lessEqual
        case greaterEqual
        case leftBracket
        case rightBracket
        case openParen
        case closeParen
        case openBrace
        case closeBrace
        case assign
        case semicolon
        case plus
        case minus
        case star
        case slash
        case percent
        case comma
        case bang
        case colon
        case greater
        case less
        case dot

        static func ~= (lhs: Set<Lexer.TokenKind>, rhs: Lexer.TokenKind) -> Bool {
            return lhs.contains(rhs)
        }

        fileprivate static let digits = Regex {
            CharacterClass.digit
            ZeroOrMore(.digit.union(.anyOf("_")))
        }
    }
}

extension Lexer.TokenKind {
    var matcher: Regex<Substring> {
        switch self {
        case .whitespace:
            return .init {
                OneOrMore(.whitespace)
            }
        case .lineComment:
            return .init {
                "//"
                ZeroOrMore(.newlineSequence.inverted)
            }
        case .blockComment:
            return .init {
                "/*"
                ZeroOrMore(ChoiceOf {
                    CharacterClass.anyOf("*").inverted
                    Regex {
                        "*"
                        CharacterClass.anyOf("/").inverted
                    }
                })
                "*/"
            }
        case .return:
            return .init {
                Anchor.wordBoundary
                "return"
                Anchor.wordBoundary
            }
        case .whileLoop:
            return .init {
                Anchor.wordBoundary
                "while"
                Anchor.wordBoundary
            }
        case .false:
            return .init {
                Anchor.wordBoundary
                "false"
                Anchor.wordBoundary
            }
        case .trait:
            return .init {
                Anchor.wordBoundary
                "trait"
                Anchor.wordBoundary
            }
        case .productType:
            return .init {
                Anchor.wordBoundary
                "struct"
                Anchor.wordBoundary
            }
        case .impl:
            return .init {
                Anchor.wordBoundary
                "impl"
                Anchor.wordBoundary
            }
        case .sumType:
            return .init {
                Anchor.wordBoundary
                "enum"
                Anchor.wordBoundary
            }
        case .else:
            return .init {
                Anchor.wordBoundary
                "else"
                Anchor.wordBoundary
            }
        case .true:
            return .init {
                Anchor.wordBoundary
                "true"
                Anchor.wordBoundary
            }
        case .null:
            return .init {
                Anchor.wordBoundary
                "null"
                Anchor.wordBoundary
            }
        case .funcDecl:
            return .init {
                "fun"
                Anchor.wordBoundary
            }
        case .varDecl:
            return .init {
                Anchor.wordBoundary
                "let"
                Anchor.wordBoundary
            }
        case .if:
            return .init {
                Anchor.wordBoundary
                "if"
                Anchor.wordBoundary
            }
        case .identifier:
            return .init {
                CharacterClass.word.subtracting(.digit)
                ZeroOrMore(CharacterClass.word)
            }
        case .number:
            return .init {
                Optionally(.anyOf("+-"))
                ChoiceOf {
                    Regex {
                        ChoiceOf {
                            Regex {
                                Self.digits
                                Optionally(".")
                                Optionally(Self.digits)
                            }
                            Regex {
                                Optionally(Self.digits)
                                Optionally(".")
                                Self.digits
                            }
                        }
                        Optionally {
                            "e"
                            Optionally(.anyOf("+-"))
                            Self.digits
                        }
                    }
                    Regex {
                        "0x"
                        CharacterClass.hexDigit
                        ZeroOrMore(.hexDigit.union(.anyOf("_")))
                        Optionally(".")
                        ZeroOrMore(.hexDigit.union(.anyOf("_")))
                        Optionally {
                            "p"
                            Optionally(.anyOf("+-"))
                            Self.digits
                        }
                    }
                    Regex {
                        "0b"
                        CharacterClass.anyOf("01")
                        ZeroOrMore(.anyOf("01_"))
                    }
                }
            }.ignoresCase()
        case .string:
            return .init {
                "\""
                ZeroOrMore(ChoiceOf {
                    CharacterClass.anyOf("\"\\").union(.newlineSequence).inverted
                    Regex {
                        "\\"
                        CharacterClass.any
                    }
                })
                "\""
            }
        case .equals:
            return Regex(verbatim: "==")
        case .notEquals:
            return Regex(verbatim: "!=")
        case .and:
            return Regex(verbatim: "&&")
        case .or:
            return Regex(verbatim: "||")
        case .coalesce:
            return Regex(verbatim: "??")
        case .exponent:
            return Regex(verbatim: "**")
        case .lessEqual:
            return Regex(verbatim: "<=")
        case .greaterEqual:
            return Regex(verbatim: ">=")
        case .leftBracket:
            return Regex(verbatim: "[")
        case .rightBracket:
            return Regex(verbatim: "]")
        case .openParen:
            return Regex(verbatim: "(")
        case .closeParen:
            return Regex(verbatim: ")")
        case .openBrace:
            return Regex(verbatim: "{")
        case .closeBrace:
            return Regex(verbatim: "}")
        case .assign:
            return Regex(verbatim: "=")
        case .semicolon:
            return Regex(verbatim: ";")
        case .plus:
            return Regex(verbatim: "+")
        case .minus:
            return Regex(verbatim: "-")
        case .star:
            return Regex(verbatim: "*")
        case .slash:
            return Regex(verbatim: "/")
        case .percent:
            return Regex(verbatim: "%")
        case .comma:
            return Regex(verbatim: ",")
        case .bang:
            return Regex(verbatim: "!")
        case .colon:
            return Regex(verbatim: ":")
        case .greater:
            return Regex(verbatim: ">")
        case .less:
            return Regex(verbatim: "<")
        case .dot:
            return Regex(verbatim: ".")
        }
    }
}