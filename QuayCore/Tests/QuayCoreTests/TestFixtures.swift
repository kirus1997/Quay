import Foundation
import QuayCore
import XCTest

enum TestFixtures {
    static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quay-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func app(id: Int, name: String, path: String) -> DockApp {
        DockApp(id: uuid(id), name: name, bundleIdentifier: "test.\(name)", path: path)
    }
}
