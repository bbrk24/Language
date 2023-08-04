import ArgumentParser

enum OperationMode: String, EnumerableFlag {
    case dumpTokens
    case dumpParseTree

    static func help(for value: OperationMode) -> ArgumentHelp? {
        switch value {
        case .dumpTokens:
            return "Dump the tokens as JSON, instead of compiling."
        case .dumpParseTree:
            return "Dump the parse tree as JSON, instead of compiling."
        }
    }
}
