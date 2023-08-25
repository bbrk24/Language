import ArgumentParser
import LanguageFrontendInternals
import Foundation

@main
public struct Main: ParsableCommand {
    @Flag var mode: OperationMode

    @Argument(help: "The file to open. If not given, read from stdin.")
    var sourceFile: String?

    public init() {}

    public mutating func run() throws {
        var sourceText = ""
        if let sourceFile {
            sourceText = try String(contentsOfFile: sourceFile)
        } else {
            while let line = readLine(strippingNewline: false) {
                sourceText += line
            }
        }

        let tokens = try Lexer.lex(source: sourceText, fileName: sourceFile ?? "<stdin>")

        if mode == .dumpTokens {
            let result = try JSONEncoder().encode(tokens)
            try FileHandle.standardOutput.write(contentsOf: result)
            print()
            return
        }

        let statements = try ParseTree.parse(tokens)
        let result = try JSONEncoder().encode(statements)
        try FileHandle.standardOutput.write(contentsOf: result)
        print()
    }
}
