import XCTest
import QuayCore

final class VersionTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testVersionFileMatchesConstant() throws {
        let text = try String(contentsOf: repositoryRoot.appendingPathComponent("VERSION"), encoding: .utf8)
        XCTAssertEqual(text.trimmingCharacters(in: .whitespacesAndNewlines), QuayVersion.marketing)
        XCTAssertEqual(QuayVersion.build, 2)
    }

    func testProjectMetadata() throws {
        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Quay.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        XCTAssertTrue(project.contains("MARKETING_VERSION = 0.1.1;"))
        XCTAssertTrue(project.contains("CURRENT_PROJECT_VERSION = 2;"))
        XCTAssertTrue(project.contains("PRODUCT_BUNDLE_IDENTIFIER = com.kirill.quay;"))
        XCTAssertTrue(project.contains("MACOSX_DEPLOYMENT_TARGET = 14.0;"))

        let info = try String(contentsOf: repositoryRoot.appendingPathComponent("App/Info.plist"), encoding: .utf8)
        XCTAssertTrue(info.contains("NSAppleEventsUsageDescription"))
        XCTAssertTrue(info.contains("NSCalendarsFullAccessUsageDescription"))
        XCTAssertTrue(info.contains("NSRemindersFullAccessUsageDescription"))
        XCTAssertTrue(info.contains("<key>LSUIElement</key>"))

        let entitlements = try String(
            contentsOf: repositoryRoot.appendingPathComponent("App/Quay.entitlements"),
            encoding: .utf8
        )
        XCTAssertTrue(entitlements.contains("com.apple.security.automation.apple-events"))
    }
}
