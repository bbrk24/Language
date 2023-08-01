@available(*, deprecated)
func notImplemented(
    function: StaticString = #function,
    file: StaticString = #fileID,
    line: UInt = #line
) -> Never {
    fatalError("Not implemented: \(function)", file: file, line: line)
}