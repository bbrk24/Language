import ArgumentParser

enum OperationMode: String, EnumerableFlag {
    case dumpTokens
    case dumpAst

    static func help(for value: OperationMode) -> ArgumentHelp? {
        switch value {
        case .dumpTokens:
            return "Dump the tokens as JSON, instead of compiling."
        case .dumpAst:
            return "Dump the AST as JSON, instead of compiling."
        }
    }
}
