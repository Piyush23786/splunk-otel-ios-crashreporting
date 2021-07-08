//
/*
Copyright 2021 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

@testable import SplunkRumCrashReporting
import SplunkRum
import Foundation
import XCTest
import OpenTelemetryApi
import OpenTelemetrySdk

var localSpans: [SpanData] = []

class TestSpanExporter: SpanExporter {
    var exportSucceeds = true

    func export(spans: [SpanData]) -> SpanExporterResultCode {
        if exportSucceeds {
            localSpans.append(contentsOf: spans)
            return .success
        } else {
            return .failure
        }
    }

    func flush() -> SpanExporterResultCode { return .success }
    func shutdown() { }
}

class CrashTests: XCTestCase {
    func testBasics() throws {
        let crashPath = Bundle(for: CrashTests.self).url(forResource: "sample", withExtension: "plcrash")!
        let crashData = try Data(contentsOf: crashPath)

        SplunkRum.initialize(beaconUrl: "http://127.0.0.1:8989/v1/traces", rumAuth: "FAKE", options: SplunkRumOptions(allowInsecureBeacon: true, debug: true))
        OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(SimpleSpanProcessor(spanExporter: TestSpanExporter()))
        localSpans.removeAll()

        SplunkRumCrashReporting.start()
        try loadPendingCrashReport(crashData)

        // FIXME port over testing helpers and validate data
        XCTAssertEqual(localSpans.count, 1)
        let crashReport = localSpans[0]
        XCTAssertEqual(crashReport.name, "crash.report")
        XCTAssertNotEqual(crashReport.attributes["splunk.rumSessionId"], crashReport.attributes["crash.rumSessionId"])
        XCTAssertEqual(crashReport.attributes["crash.rumSessionId"]?.description, "355ecc42c29cf0b56c411f1eab9191d0")
        XCTAssertEqual(crashReport.attributes["crash.address"]?.description, "140733995048756")
        XCTAssertEqual(crashReport.attributes["component"]?.description, "error")
        XCTAssertEqual(crashReport.attributes["error"]?.description, "true")
        XCTAssertEqual(crashReport.attributes["exception.type"]?.description, "SIGILL")
        XCTAssertTrue(crashReport.attributes["exception.stacktrace"]?.description.contains("UIKitCore") ?? false)
    }
}
