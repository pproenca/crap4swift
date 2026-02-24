import SwiftParser
import SwiftSyntax
import XCTest
@testable import crap4swift

final class FunctionFinderTests: XCTestCase {

    private func findFunctions(in source: String) -> [FunctionInfo] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: "test.swift", tree: tree)
        let finder = FunctionFinder(converter: converter)
        finder.walk(tree)
        return finder.functions
    }

    func testSimpleFunction() {
        let source = """
        func hello() {
            print("hello")
        }
        """
        let funcs = findFunctions(in: source)
        XCTAssertEqual(funcs.count, 1)
        XCTAssertEqual(funcs[0].name, "hello()")
        XCTAssertEqual(funcs[0].startLine, 1)
        XCTAssertEqual(funcs[0].endLine, 3)
    }

    func testFunctionWithParameters() {
        let source = """
        func add(_ a: Int, to b: Int) -> Int {
            return a + b
        }
        """
        let funcs = findFunctions(in: source)
        XCTAssertEqual(funcs.count, 1)
        XCTAssertEqual(funcs[0].name, "add(_:to:)")
    }

    func testMultipleFunctions() {
        let source = """
        func first() { }
        func second() { }
        func third() { }
        """
        let funcs = findFunctions(in: source)
        XCTAssertEqual(funcs.count, 3)
        XCTAssertEqual(funcs.map { $0.name }, ["first()", "second()", "third()"])
    }

    func testInit() {
        let source = """
        class Foo {
            init(value: Int) {
                self.value = value
            }
            var value: Int
        }
        """
        let funcs = findFunctions(in: source)
        XCTAssertEqual(funcs.count, 1)
        XCTAssertEqual(funcs[0].name, "init(value:)")
    }

    func testFailableInit() {
        let source = """
        class Foo {
            init?(value: Int) {
                guard value > 0 else { return nil }
                self.value = value
            }
            var value: Int
        }
        """
        let funcs = findFunctions(in: source)
        XCTAssertEqual(funcs.count, 1)
        XCTAssertEqual(funcs[0].name, "init?(value:)")
    }

    func testDeinit() {
        let source = """
        class Foo {
            deinit {
                cleanup()
            }
            func cleanup() { }
        }
        """
        let funcs = findFunctions(in: source)
        let deinitFunc = funcs.first { $0.name == "deinit" }
        XCTAssertNotNil(deinitFunc)
    }

    func testAccessModifiers() {
        let source = """
        public func publicFunc() { }
        internal func internalFunc() { }
        private func privateFunc() { }
        """
        let funcs = findFunctions(in: source)
        XCTAssertEqual(funcs.count, 3)
        XCTAssertEqual(funcs.map { $0.name }, ["publicFunc()", "internalFunc()", "privateFunc()"])
    }

    func testComputedProperty() {
        let source = """
        struct Foo {
            var x: Int = 0
            var doubled: Int {
                get { return x * 2 }
                set { x = newValue / 2 }
            }
        }
        """
        let funcs = findFunctions(in: source)
        XCTAssertEqual(funcs.count, 2)
        let names = Set(funcs.map { $0.name })
        XCTAssertTrue(names.contains("doubled.get"))
        XCTAssertTrue(names.contains("doubled.set"))
    }

    func testProtocolRequirementSkipped() {
        let source = """
        protocol Foo {
            func bar() -> Int
        }
        """
        let funcs = findFunctions(in: source)
        XCTAssertEqual(funcs.count, 0)
    }

    func testLineRanges() {
        let source = """
        func short() { }
        func multiline(
            a: Int,
            b: Int
        ) {
            let c = a + b
            print(c)
        }
        """
        let funcs = findFunctions(in: source)
        XCTAssertEqual(funcs.count, 2)

        let short = funcs.first { $0.name == "short()" }!
        XCTAssertEqual(short.startLine, 1)
        XCTAssertEqual(short.endLine, 1)

        let multi = funcs.first { $0.name == "multiline(a:b:)" }!
        XCTAssertEqual(multi.startLine, 2)
        XCTAssertEqual(multi.endLine, 8)
    }
}
