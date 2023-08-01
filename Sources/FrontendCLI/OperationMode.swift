import ArgumentParser

enum OperationMode: String, EnumerableFlag {
    case dumpTokens

    static func help(for value: OperationMode) -> ArgumentHelp? {
        switch value {
        case .dumpTokens:
            return "Dump the tokens as JSON, instead of compiling."
        }
    }
}
