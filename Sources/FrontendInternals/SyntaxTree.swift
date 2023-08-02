public enum SyntaxTree {
    public indirect enum Expression: Codable {
        case binOp(_BinaryOperator, lhs: Expression, rhs: Expression)
        case unaryOp(_UnaryOperator, Expression)
        case assignment(identifier: String, newValue: Expression)
        case stringLiteral(String)
        case numberLiteral(Double)
        case identifier(String)
        case indexAccess(base: Expression, index: [Expression])
        case propertyAccess(base: Expression, property: String)
        case functionCall(function: String, arguments: [Expression])
    }

    public enum _BinaryOperator: String, Codable {
        case equals = "=="
        case notEquals = "!="
        case and = "&&"
        case or = "||"
        case coalesce = "??"
        case exponent = "**"
        case lessEqual = "<="
        case greaterEqual = ">="
        case plus = "+"
        case minus = "-"
        case star = "*"
        case slash = "/"
        case percent = "%"
        case greater = ">"
        case less = "<"
    }

    public enum _UnaryOperator: String, Codable {
        case plus = "+"
        case minus = "-"
        case bang = "!"
    }

    public enum Statement: Codable {
        case whileLoop(condition: Expression, body: [Statement])
        case declaration(_Declaration)
        case ifElse(condition: Expression, trueBody: [Statement], falseBody: [Statement])
        case `return`(Expression?)
        case expression(Expression)
        case implBlock(type: String, traits: [String], body: [_Declaration])
    }

    public enum _Declaration: Codable {
        case trait(name: String, refining: [String], body: [_Declaration])
        case `struct`(name: String, body: [_Declaration])
        case `enum`(name: String, body: [String])
        case `func`(name: String, parameters: [_NameAndType], returnType: Expression?, body: [Statement])
        case `var`(name: String, type: Expression?, initialValue: Expression?)
    }

    public struct _NameAndType: Codable {
        var name: String
        var type: Expression
    }

    public static func parse(_ tokens: __owned Lexer.TokenCollection) throws -> [Statement] {
        let file = tokens.first?.startLoc.file
        var partialResult: [PartiallyParsedStatement]
        do {
            partialResult = try pass1(tokens)
        } catch let error as UnexpectedEOF where error.file == nil {
            throw UnexpectedEOF(file: file)
        }
        return try pass2(partialResult)
    }

    static func pass2(_ statements: [PartiallyParsedStatement]) throws -> [Statement] {
        var result = Array<Statement>()

        for statement in statements {
            switch statement {
            case .whileLoop(condition: let condition, body: let body):
                result.append(.whileLoop(condition: try shuntingYard(condition), body: try pass2(body)))
            case .traitDecl(name: let name, refining: let refining, body: let body):
                result.append(.declaration(.trait(
                    name: name,
                    refining: try parseCommaSeparatedIdentifiers(refining),
                    body: try parseDeclsOnly(body)
                )))
            case .structDecl(name: let name, body: let body):
                result.append(.declaration(.struct(name: name, body: try parseDeclsOnly(body))))
            case .enumDecl(name: let name, body: let body):
                result.append(.declaration(.enum(name: name, body: try parseCommaSeparatedIdentifiers(body))))
            case .ifElse(condition: let condition, trueBody: let trueBody, falseBody: let falseBody):
                result.append(.ifElse(
                    condition: try shuntingYard(condition),
                    trueBody: try pass2(trueBody),
                    falseBody: try pass2(falseBody)
                ))
            case .funcDecl(name: let name, parameters: let parameters, returnType: let returnType, body: let body):
                result.append(.declaration(.func(
                    name: name,
                    parameters: try parseArgumentList(parameters),
                    returnType: returnType.isEmpty ? nil : try parseType(returnType),
                    body: try pass2(body)
                )))
            case .varDecl(name: let name, type: let type, initialValue: let initialValue):
                result.append(.declaration(.var(
                    name: name,
                    type: type.isEmpty ? nil : try parseType(type),
                    initialValue: initialValue.isEmpty ? nil : try shuntingYard(initialValue)
                )))
            case .return(let expr):
                if expr.isEmpty {
                    result.append(.return(nil))
                } else {
                    result.append(.return(try shuntingYard(expr)))
                }
            case .unparsedExpr(let expr):
                result.append(.expression(try shuntingYard(expr)))
            case .implBlock(type: let type, traits: let traits, body: let body):
                result.append(.implBlock(
                    type: type,
                    traits: try parseCommaSeparatedIdentifiers(traits),
                    body: try parseDeclsOnly(body)
                ))
            }
        }

        return result
    }

    struct UnexpectedStatement: Error, CustomStringConvertible {
        // TODO: Make this more helpful
        var saw: Statement

        var description: String {
            "Types may only contain declarations, not expressions."
        }
    }

    private static func parseDeclsOnly(_ statements: [PartiallyParsedStatement]) throws -> [_Declaration] {
        return try pass2(statements).map {
            switch $0 {
            case .declaration(let decl):
                return decl
            default:
                throw UnexpectedStatement(saw: $0)
            }
        }
    }
}
