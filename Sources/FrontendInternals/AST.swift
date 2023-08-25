public struct AST: Codable {
    var declarations: [String: _Declaration] = [
        "Void": .struct(body: [:]),
        "Number": .struct(body: [:]),
        "String": .struct(body: [:]),
        "Bool": .enum(body: ["true", "false"])
        // TODO: Type[T], Optional[T], Func[Args..., Return]
    ]
    var topLevelStatements: [_TopLevelStatement] = []
    var impls: [_Impl] = []

    public struct _Impl: Codable {}

    public enum _Declaration: Codable {
        case trait(refining: [ParseTree.TypeName], body: [String: _Declaration])
        case `struct`(body: [String: _Declaration])
        case `enum`(body: [String])
        case `func`(parameters: [ParseTree.NameAndType], returnType: ParseTree.TypeName, body: [ParseTree.Statement])
        case `var`(type: ParseTree.TypeName)
    }

    public enum _TopLevelStatement: Codable {
        public typealias Expression = ParseTree.Expression

        case whileLoop(condition: Expression, body: [ParseTree.Statement])
        case ifElse(condition: Expression, trueBody: [ParseTree.Statement], falseBody: [ParseTree.Statement])
        case expression(Expression)
    }

    internal static func transformDeclList(_ decls: [ParseTree._Declaration]) throws -> [String: _Declaration] {
        var result = Dictionary<String, _Declaration>()

        for decl in decls {
            switch decl {
            case .trait(name: let name, refining: let refining, body: let body):
                guard !result.keys.contains(name) else {
                    notImplemented()
                }
                result[name] = .trait(refining: refining, body: try transformDeclList(body))
            case .struct(name: let name, body: let body):
                guard !result.keys.contains(name) else {
                    notImplemented()
                }
                result[name] = .struct(body: try transformDeclList(body))
            case .enum(name: let name, body: let body):
                guard !result.keys.contains(name) else {
                    notImplemented()
                }
                result[name] = .enum(body: body)
            case .func(name: let name, parameters: let parameters, returnType: let returnType, body: let body):
                guard !result.keys.contains(name) else {
                    notImplemented()
                }
                result[name] = .func(
                    parameters: parameters,
                    returnType: returnType ?? .identifier("Void"),
                    body: body
                )
            case .var(name: let name, type: let type, initialValue: let initialValue):
                guard !result.keys.contains(name) else {
                    notImplemented()
                }
                result[name] = .var(type: type ?? .placeholder)
                if let initialValue {
                    notImplemented()
                }
            }
        }

        return result
    }

    public static func group(statements: [ParseTree.Statement]) throws -> AST {
        var result = AST()

        for statement in statements {
            switch statement {
            case .whileLoop(condition: let condition, body: let body):
                result.topLevelStatements.append(.whileLoop(condition: condition, body: body))
            case .declaration(let decl):
                let newDecl = try transformDeclList([decl])
                result.declarations.merge(newDecl) { _, _ in notImplemented() }
            case .ifElse(condition: let condition, trueBody: let trueBody, falseBody: let falseBody):
                result.topLevelStatements.append(
                    .ifElse(condition: condition, trueBody: trueBody, falseBody: falseBody)
                )
            case .return(_):
                notImplemented()
            case .expression(let expr):
                result.topLevelStatements.append(.expression(expr))
            case .implBlock(type: _, traits: _, body: _):
                result.impls.append(.init())
            }
        }

        try result.inferTypes()

        return result
    }

    /// Replace any placeholders with inferred types.
    internal mutating func inferTypes() throws {
        // must be eager for the loop below to work correctly
        let initialValues = topLevelStatements.compactMap { 
            if case .expression(.binOp(.assign, lhs: .indivisible(.identifier(let lhs)), rhs: let rhs)) = $0,
               case .var(type: .placeholder) = declarations[lhs] {
                return (lhs, rhs)
            }
            return nil
        }

        for (name, expr) in initialValues {
            let type = try determineType(expr: expr)
            declarations[name] = .var(type: type)
        }

        guard !declarations.values.contains(where: {
            if case .var(type: .placeholder) = $0 {
                return true
            }
            return false
        }) else {
            notImplemented()
        }
    }

    internal static func getDeclType(
        _ name: String,
        scope: [String: _Declaration],
        path: ParseTree.TypeName?
    ) throws -> ParseTree.TypeName {
        switch scope[name] {
        case nil:
            notImplemented()
        case .trait(refining: _, body: _):
            notImplemented()
        case .struct(body: _), .enum(body: _):
            if let path {
                return .generic(.identifier("Type"), [.dot(path, name)])
            }
            return .generic(.identifier("Type"), [.identifier(name)])
        case .func(parameters: let params, returnType: let returnType, body: _):
            return .generic(.identifier("Func"), params.map(\.type) + CollectionOfOne(returnType))
        case .var(type: let type):
            return type
        }
    }

    internal func determineType(expr: ParseTree.Expression) throws -> ParseTree.TypeName {
        switch expr {
        case .binOp(let op, lhs: _, rhs: let rhs):
            switch op {
            case .equals, .notEquals, .and, .or, .lessEqual, .greaterEqual, .greater, .less:
                return .identifier("Bool")
            case .coalesce:
                return try determineType(expr: rhs)
            case .exponent, .plus, .minus, .star, .slash, .percent:
                return .identifier("Number")
            case .assign:
                return .identifier("Void")
            }
        case .unaryOp(let op, let base):
            switch op {
            case .bang:
                assert((try? determineType(expr: base)) == .identifier("Bool"))
                return .identifier("Bool")
            case .plus, .minus:
                assert((try? determineType(expr: base)) == .identifier("Number"))
                return .identifier("Number")
            }
        case .indivisible(let i):
            switch i {
            case .stringLiteral(_):
                return .identifier("String")
            case .numberLiteral(_):
                return .identifier("Number")
            case .identifier(let name):
                return try AST.getDeclType(name, scope: declarations, path: nil)
            case .booleanLiteral(_):
                return .identifier("Bool")
            case .null:
                notImplemented()
            }
        case .indexAccess(base: _, index: _):
            notImplemented()
        case .propertyAccess(base: let base, property: let property):
            guard case .identifier(let typename) = try determineType(expr: base),
                  let typedef = declarations[typename] else {
                notImplemented()
            }
            switch typedef {
            case .struct(body: let body):
                return try AST.getDeclType(property, scope: body, path: .identifier(typename))
            default:
                notImplemented()
            }
        case .functionCall(function: let function, arguments: _):
            switch try determineType(expr: function) {
            case .generic(.identifier("Func"), let typeArgs):
                guard let last = typeArgs.last else { notImplemented() }
                return last
            case .generic(.identifier("Type"), let typeArgs):
                guard typeArgs.count == 1 else { notImplemented() }
                return typeArgs[0]
            default:
                notImplemented()
            }
        }
    }
}
