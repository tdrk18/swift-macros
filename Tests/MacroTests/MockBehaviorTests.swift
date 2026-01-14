import Macro
import XCTest

@Mockable
protocol Calculator {
    func add(_ x: Int, _ y: Int) -> Int
    func fail() throws
}

final class MockBehaviorTests: XCTestCase {
    func testCallCountAndArguments() {
        let mock = MockCalculator()
        mock.addReturnValue = 3

        let result = mock.add(1, 2)

        XCTAssertEqual(result, 3)
        XCTAssertEqual(mock.addCallCount, 1)
        XCTAssertEqual(mock.addReceivedArguments.first?.x, 1)
        XCTAssertEqual(mock.addReceivedArguments.first?.y, 2)
    }

    func testThrowing() {
        enum TestError: Error { case sample }

        let mock = MockCalculator()
        mock.failError = TestError.sample

        XCTAssertThrowsError(try mock.fail())
    }
}
