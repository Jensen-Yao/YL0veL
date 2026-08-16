import XCTest
@testable import YL0veL

final class CSVParserTests: XCTestCase {

    func testSimpleRows() {
        let csv = "a,b,c\n1,2,3\n4,5,6"
        let table = CSVParser.parse(csv)
        XCTAssertEqual(table.count, 3)
        XCTAssertEqual(table[0], ["a", "b", "c"])
        XCTAssertEqual(table[1], ["1", "2", "3"])
    }

    func testQuotedFields() {
        let csv = "date,note\n2026-01-01,\"hello, world\"\n2026-01-02,\"say \"\"hi\"\"\""
        let table = CSVParser.parse(csv)
        XCTAssertEqual(table[1][1], "hello, world")
        XCTAssertEqual(table[2][1], "say \"hi\"")
    }

    func testCRLFLineEndings() {
        let csv = "a,b\r\n1,2\r\n3,4"
        let table = CSVParser.parse(csv)
        XCTAssertEqual(table.count, 3)
        XCTAssertEqual(table[2], ["3", "4"])
    }

    func testDripStyleCSV() {
        let csv = """
        date,bleeding.value,pain.cramps,pain.headache
        2026-07-01,2,true,false
        2026-07-02,1,true,true
        2026-07-03,0,false,false
        """
        let table = CSVParser.parse(csv)
        XCTAssertEqual(table.count, 4)
        XCTAssertEqual(table[1][0], "2026-07-01")
    }

    func testFlowValueParsing() {
        XCTAssertEqual(ImportService.importedFlowValue("2"), 2)
        XCTAssertEqual(ImportService.importedFlowValue("heavy"), 3)
        XCTAssertEqual(ImportService.importedFlowValue("light"), 1)
        XCTAssertEqual(ImportService.importedFlowValue("none"), 0)
    }
}
