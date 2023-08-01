struct SourceLocation: CustomStringConvertible, Codable {
    var file: String
    var line: UInt
    var col: UInt

    var description: String {
        "\(file):\(line):\(col)"
    }
}
