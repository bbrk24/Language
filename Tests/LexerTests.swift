@testable import LanguageFrontendInternals
import XCTest

public final class LexerTests: XCTestCase {
    public func test_veryBasic() throws {
        let arr = try Lexer.lex(source: " 0 ", fileName: "filename")

        XCTAssertEqual(arr.count, 3)
        XCTAssertEqual(arr[0].kind, .whitespace)
        XCTAssertEqual(arr[1].kind, .number)
        XCTAssertEqual(arr[2].kind, .whitespace)
        XCTAssertEqual(arr[1].text, "0")
    }
}
