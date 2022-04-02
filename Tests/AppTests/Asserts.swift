import XCTest
import Vapor

func XCTAssertThrowsAbortError<T>(
	_ status: HTTPResponseStatus,
	_ fn: @autoclosure () async throws -> T,
	file: StaticString = #filePath,
	line: UInt = #line
) async {
	do {
		_ = try await fn()
		XCTFail("Should have thrown", file: file, line: line)
	} catch {
		if let error = error as? AbortError {
			XCTAssertEqual(error.status, status, file: file, line: line)
		} else {
			XCTFail("Unexpected error: \(error)", file: file, line: line)
		}
	}
}
