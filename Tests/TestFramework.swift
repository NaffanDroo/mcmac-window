import Foundation

var _failures: [String] = []
var _passed   = 0
var _failed   = 0

struct Test {
    let name: String
    let run:  () throws -> Void

    init(_ name: String, run: @escaping () throws -> Void) {
        self.name = name
        self.run  = run
    }
}

enum Skip: Error { case because(String) }

func runSuite(name: String, tests: [Test]) {
    print("─────────────────────────────────────")
    print("Suite: \(name)")
    for test in tests {
        _failures = []
        do {
            try test.run()
        } catch Skip.because(let reason) {
            print("  ⏭  \(test.name) [SKIPPED: \(reason)]")
            continue
        } catch {
            _failures.append("Unexpected error: \(error)")
        }
        if _failures.isEmpty {
            print("  ✓  \(test.name)")
            _passed += 1
        } else {
            print("  ✗  \(test.name)")
            for f in _failures { print("       \(f)") }
            _failed += 1
        }
    }
}

func assertEq(_ a: CGFloat, _ b: CGFloat, tol: CGFloat = 0.001,
              _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    if abs(a - b) > tol {
        record("assertEq failed: \(a) ≠ \(b) (tol \(tol))\(label(msg))", file: file, line: line)
    }
}

func assertEq(_ a: CGRect, _ b: CGRect, _ msg: String = "",
              file: StaticString = #file, line: UInt = #line) {
    if a != b {
        record("assertEq(CGRect) failed:\n         got  \(a)\n         want \(b)\(label(msg))", file: file, line: line)
    }
}

func assertEq<T: Equatable>(_ a: T, _ b: T, _ msg: String = "",
                             file: StaticString = #file, line: UInt = #line) {
    if a != b {
        record("assertEq failed: \(a) ≠ \(b)\(label(msg))", file: file, line: line)
    }
}

func assertTrue(_ cond: Bool, _ msg: String = "",
                file: StaticString = #file, line: UInt = #line) {
    if !cond { record("assertTrue failed\(label(msg))", file: file, line: line) }
}

func skip(_ reason: String) throws -> Never { throw Skip.because(reason) }

private func label(_ msg: String) -> String { msg.isEmpty ? "" : " — \(msg)" }
private func record(_ msg: String, file: StaticString, line: UInt) {
    _failures.append("\(file):\(line): \(msg)")
}
