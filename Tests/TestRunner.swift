import AppKit

@main
enum TestRunner {
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)

        runSuite(name: "Geometry",    tests: geometryTests())
        runSuite(name: "WindowMover", tests: windowMoverTests())

        print("─────────────────────────────────────")
        let total = _passed + _failed
        print("Results: \(_passed)/\(total) passed", _failed > 0 ? "(\(_failed) failed)" : "✓")
        exit(_failed > 0 ? 1 : 0)
    }
}
