#if !os(watchOS)
import XCTest
import Foundation
import os.log
import UnitTesting
@testable import RollbarNotifier

final class RollbarNotifierConfigurationTests: XCTestCase {
    
    override func setUp() {
        
        super.setUp();
        
        RollbarTestUtil.deleteLogFiles();
        RollbarTestUtil.deletePayloadsStoreFile();
        RollbarTestUtil.clearTelemetryFile();
        
        let config = RollbarMutableConfig();
        config.developerOptions.transmit = false;
        config.developerOptions.logIncomingPayloads = true;
        config.developerOptions.logTransmittedPayloads = true;
        config.developerOptions.logDroppedPayloads = true;
        config.loggingOptions.enableOomDetection = false;
        Rollbar.initWithConfiguration(config);
    }
    
    override func tearDown() {
        
        super.tearDown();
    }
    
    func testDefaultRollbarConfiguration() {
        
        let rc = RollbarMutableConfig();
        NSLog("%@", rc);
    }

    func testTelemetryEnabled() {

        var expectedFlag = false;
        
        let config = Rollbar.configuration().mutableCopy();
        config.telemetry.enabled = expectedFlag;
        Rollbar.update(withConfiguration: config);

        XCTAssertTrue(RollbarTelemetry.sharedInstance().enabled == expectedFlag,
                      "RollbarTelemetry.sharedInstance.enabled is expected to be NO."
                      );
        let max = UInt(5);
        let testCount = max;
        for _ in 0..<testCount {
            Rollbar.recordErrorEvent(for: .debug, message: "test");
        }

        config.loggingOptions.maximumReportsPerMinute = max;
        Rollbar.update(withConfiguration: config);

        var telemetryCollection = RollbarTelemetry.sharedInstance().getAllData()!;
        XCTAssertTrue(telemetryCollection.count == 0,
                      "Telemetry count is expected to be \(0). Actual is \(telemetryCollection.count)"
                      );

        expectedFlag = true;
        config.telemetry.enabled = expectedFlag;
        Rollbar.update(withConfiguration: config);

        XCTAssertTrue(RollbarTelemetry.sharedInstance().enabled == expectedFlag,
                      "RollbarTelemetry.sharedInstance.enabled is expected to be YES."
                      );
        for _ in 0..<testCount {
            Rollbar.recordErrorEvent(for: .debug, message: "test");
        }

        config.loggingOptions.maximumReportsPerMinute = max;
        Rollbar.update(withConfiguration: config);

        telemetryCollection = RollbarTelemetry.sharedInstance().getAllData()!;
        XCTAssertTrue(telemetryCollection.count == max,
                      "Telemetry count is expected to be \(max). Actual is \(telemetryCollection.count)"
                      );
        RollbarTelemetry.sharedInstance().clearAllData();
    }

    func testMaximumTelemetryEvents() {
        
        let config = Rollbar.configuration().mutableCopy();
        config.telemetry.enabled = true;
        Rollbar.update(withConfiguration: config);

        let testCount = 10;
        let max:UInt = 5;
        for _ in 0..<testCount {
            Rollbar.recordErrorEvent(for: .debug, message: "test");
        }
        config.telemetry.maximumTelemetryData = max;
        Rollbar.update(withConfiguration: config);

        Rollbar.debugMessage("Test");
        RollbarLogger .flushRollbarThread();
        
        let logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        let logItem = logItems[logItems.count - 1];
        let payload = RollbarPayload(jsonString: logItem);
        let telemetry = payload.data.body.telemetry!;
        XCTAssertTrue(telemetry.count == max,
                      "Telemetry item count is \(telemetry.count), should be \(max)"
        );
    }
    
    func testScrubViewInputsTelemetryConfig() {

        var expectedFlag = false;
        let config = Rollbar.configuration().mutableCopy();
        config.telemetry.viewInputsScrubber.enabled = expectedFlag;
        Rollbar.update(withConfiguration: config);
        XCTAssertTrue(RollbarTelemetry.sharedInstance().scrubViewInputs == expectedFlag,
                      "RollbarTelemetry.sharedInstance.scrubViewInputs is expected to be NO."
                      );
        
        expectedFlag = true;
        config.telemetry.viewInputsScrubber.enabled = expectedFlag;
        Rollbar.update(withConfiguration: config);
        XCTAssertTrue(RollbarTelemetry.sharedInstance().scrubViewInputs == expectedFlag,
                      "RollbarTelemetry.sharedInstance.scrubViewInputs is expected to be YES."
                      );
    }

    func testViewInputTelemetrScrubFieldsConfig() {

        let element1 = "password";
        let element2 = "pin";
        
        let config = Rollbar.configuration().mutableCopy();
        config.telemetry.viewInputsScrubber.scrubFields.add(element1);
        config.telemetry.viewInputsScrubber.scrubFields.add(element2);
        
        Rollbar.update(withConfiguration: config);

        XCTAssertTrue(
            RollbarTelemetry.sharedInstance().viewInputsToScrub!.count == (RollbarMutableScrubbingOptions().scrubFields.count + 2),
            "RollbarTelemetry.sharedInstance.viewInputsToScrub is expected to count = 2"
            );
        XCTAssertTrue(
            RollbarTelemetry.sharedInstance().viewInputsToScrub!.contains(element1),
            "RollbarTelemetry.sharedInstance.viewInputsToScrub is expected to conatin \(element1)"
            );
        XCTAssertTrue(
            RollbarTelemetry.sharedInstance().viewInputsToScrub!.contains(element2),
            "RollbarTelemetry.sharedInstance.viewInputsToScrub is expected to conatin \(element2)"
            );
        
        config.telemetry.viewInputsScrubber.removeScrubField(element1);
        config.telemetry.viewInputsScrubber.removeScrubField(element2);
        
        Rollbar.update(withConfiguration: config);

        XCTAssertTrue(
            RollbarTelemetry.sharedInstance().viewInputsToScrub!.count == RollbarMutableScrubbingOptions().scrubFields.count,
            "RollbarTelemetry.sharedInstance.viewInputsToScrub is expected to count = 0"
            );
    }
    
    func testEnabled() {
        
        var logItems = RollbarTestUtil.readTransmittedPayloadsAsStrings();
        XCTAssertTrue(logItems.count == 0,
                      "logItems count is expected to be 0. Actual value is \(logItems.count)"
                      );


        let config = Rollbar.configuration().mutableCopy();
        config.developerOptions.enabled = false;
        Rollbar.update(withConfiguration: config);
        RollbarLogger.flushRollbarThread();
        RollbarTestUtil.deleteLogFiles();

        Rollbar.debugMessage("Test1");
        RollbarLogger.flushRollbarThread();
        logItems = RollbarTestUtil.readTransmittedPayloadsAsStrings();
        XCTAssertTrue(logItems.count == 0,
                      "logItems count is expected to be 0. Actual value is \(logItems.count)"
                      );

        config.developerOptions.enabled = true;
        Rollbar.update(withConfiguration: config);
        RollbarLogger.flushRollbarThread();

        Rollbar.debugMessage("Test2");
        RollbarLogger.flushRollbarThread();
        logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        XCTAssertTrue(logItems[logItems.count - 1].contains("Test2"));

        config.developerOptions.enabled = false;
        Rollbar.update(withConfiguration: config);
        RollbarLogger.flushRollbarThread();

        Rollbar.debugMessage("Test3");
        RollbarLogger.flushRollbarThread();
        logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        XCTAssertTrue(!logItems[logItems.count - 1].contains("Test3"));
    }

    func testCheckIgnore() {

        Rollbar.configuration();

        RollbarTestUtil.wait();
        var expectedIncomingCount = RollbarTestUtil.readIncomingPayloadsAsStrings().count;
        var expectedDroppedCount = RollbarTestUtil.readDroppedPayloadsAsStrings().count;

        Rollbar.debugMessage("Don't ignore this");
        expectedIncomingCount+=1;
        RollbarTestUtil.wait();
        var logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        XCTAssertTrue(logItems.count == expectedIncomingCount,
                      "Log item count should be \(expectedIncomingCount) but actual is \(logItems.count)"
        );

        let config = Rollbar.configuration().mutableCopy();
        config.checkIgnoreRollbarData = {
            rollbarData in return true;
            
        };
        Rollbar.update(withConfiguration: config);
        Rollbar.debugMessage("Ignore this");
        expectedIncomingCount+=1;
        expectedDroppedCount+=1;
        RollbarTestUtil.wait();
        logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        XCTAssertTrue(logItems.count == expectedIncomingCount,
                      "Log item count should be \(expectedIncomingCount) but actual is \(logItems.count)"
        );
        logItems = RollbarTestUtil.readDroppedPayloadsAsStrings();
        XCTAssertTrue(logItems.count == expectedDroppedCount,
                      "Log item count should be \(expectedIncomingCount) but actual is \(logItems.count)"
        );
    }

    func testServerData() {
        
        let config = Rollbar.configuration().mutableCopy();

        let host = "testHost";
        let root = "testRoot";
        let branch = "testBranch";
        let codeVersion = "testCodeVersion";
        config.setServerHost(host, root: root, branch: branch, codeVersion: codeVersion);
        Rollbar .update(withConfiguration: config);
        
        Rollbar.debugMessage("test");

        RollbarTestUtil.wait();

        let logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        let logItem = logItems[logItems.count - 1];
        let payload = RollbarPayload(jsonString: logItem);
        let server = payload.data.server!;

        XCTAssertTrue(host.compare(server.host!) == .orderedSame,
                      "host is \(server.host!), should be \(host)"
                      );
        XCTAssertTrue(root.compare(server.root!) == .orderedSame,
                      "root is \(server.root!), should be \(root)"
                      );
        XCTAssertTrue(branch.compare(server.branch!) == .orderedSame,
                      "branch is \(server.branch!), should be \(branch)"
                      );
        XCTAssertTrue(codeVersion.compare(server.codeVersion!) == .orderedSame,
                      "code_version is \(server.codeVersion!), should be \(codeVersion)"
                      );
    }

    func testPayloadModification() {
        
        let config = Rollbar.configuration().mutableCopy();

        let newMsg = "Modified message";
        config.modifyRollbarData = {rollbarData in
            rollbarData.body.message?.body = newMsg;
            rollbarData.body.message?.addKeyed("body2", string: newMsg)
            return rollbarData;
        };
        Rollbar.update(withConfiguration: config);
        Rollbar.debugMessage("test");

        RollbarTestUtil.wait();
        let logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        let logItem = logItems[logItems.count - 1];
        let payload = RollbarPayload(jsonString: logItem);
        let msg1 = payload.data.body.message!.body;
        let msg2 = payload.data.body.message!.getDataByKey("body2") as! String;

        XCTAssertTrue(msg1.compare(newMsg) == .orderedSame,
                      "body.message.body is \(msg1), should be \(newMsg)"
                      );
        XCTAssertTrue(msg2.compare(newMsg) == .orderedSame,
                      "body.message.body2 is \(msg2), should be \(newMsg)"
                      );
    }

    func testScrublistFields() {
        
        let config = Rollbar.configuration().mutableCopy();

        let scrubedContent = "*****";
        let keys = ["client.ios.app_name", "client.ios.os_version", "body.message.body"];
        
        // define scrub fields:
        for key in keys {
            config.dataScrubber.addScrubField(key);
        }
        Rollbar.update(withConfiguration: config);
        RollbarLogger.flushRollbarThread();
        
        Rollbar.debugMessage("test");
        RollbarLogger.flushRollbarThread();

        // verify the fields were scrubbed:
        var logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        var logItem = logItems[logItems.count - 1];
        var payload = RollbarPayload(jsonString: logItem);
        for key in keys {
            let content = payload.data.jsonFriendlyData.value(forKeyPath: key) as! String;
            XCTAssertTrue(
                content.compare(scrubedContent) == .orderedSame,
                "\(key) is \(content), should be \(scrubedContent)"
            );
        }
        RollbarTestUtil.deleteLogFiles();

        // define scrub whitelist fields (the same as the scrub fields - to counterbalance them):
        for key in keys {
            config.dataScrubber.addScrubSafeListField(key);
        }
        Rollbar.update(withConfiguration: config);
        RollbarLogger.flushRollbarThread();

        Rollbar.debugMessage("test");
        RollbarLogger.flushRollbarThread();

        // verify the fields were not scrubbed:
        logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        logItem = logItems[logItems.count - 1];
        payload = RollbarPayload(jsonString: logItem);
        for key in keys {
            let content = payload.data.jsonFriendlyData.value(forKeyPath: key) as! String;
            XCTAssertTrue(
                content.compare(scrubedContent) != .orderedSame,
                "\(key) is \(content), should not be \(scrubedContent)"
            );
        }
    }

    func testPersonDataAttachment() {
        
        XCTAssertNotNil(Rollbar.configuration());
        
        let config = Rollbar.configuration().mutableCopy();
        let person = config.person;
        XCTAssertNotNil(person);
        
        person.id = "ID";
        person.username = "USERNAME";
        person.email = "EMAIL";
        
        let personJson =
        config.person.serializeToJSONString();
        XCTAssertNotNil(personJson, "Json serialization works.");
        let expectedPersonJson =
        "{\n  \"email\" : \"EMAIL\",\n  \"id\" : \"ID\",\n  \"username\" : \"USERNAME\"\n}";
        XCTAssertTrue(
            .orderedSame == personJson!.compare(expectedPersonJson),
            "Properly serialized person attributes."
        );
        Rollbar.update(withConfiguration: config);
        RollbarLogger.flushRollbarThread();

        Rollbar.debugMessage("test");
        RollbarLogger.flushRollbarThread();
        // verify the fields were scrubbed:
        let logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        let payload = RollbarPayload(jsonString: logItems[logItems.count - 1]);
        XCTAssertTrue(
            .orderedSame == payload.data.person!.serializeToJSONString()!.compare(expectedPersonJson),
            "Properly serialized person in payload."
        );
        let payloadJson = payload.serializeToJSONString();
        XCTAssertTrue(
            ((payloadJson?.contains(expectedPersonJson)) != nil),
            "Properly serialized person in payload."
        );
    }

    func testRollbarSetPersonDataAttachment() {
        
        XCTAssertNotNil(Rollbar.configuration());
        
        let config = Rollbar.configuration().mutableCopy();
        let person = config.person;
        XCTAssertNotNil(person);
        
        config.setPersonId("ID",
                           username: "USERNAME",
                           email: "EMAIL"
        );
        
        let personJson =
        config.person.serializeToJSONString();
        XCTAssertNotNil(personJson, "Json serialization works.");
        let expectedPersonJson =
        "{\n  \"email\" : \"EMAIL\",\n  \"id\" : \"ID\",\n  \"username\" : \"USERNAME\"\n}";
        XCTAssertTrue(
            .orderedSame == personJson!.compare(expectedPersonJson),
            "Properly serialized person attributes."
        );
        Rollbar.update(withConfiguration: config);
        RollbarLogger.flushRollbarThread();

        Rollbar.debugMessage("test");
        RollbarLogger.flushRollbarThread();
        // verify the fields were scrubbed:
        let logItems = RollbarTestUtil.readIncomingPayloadsAsStrings();
        let payload = RollbarPayload(jsonString: logItems[logItems.count - 1]);
        XCTAssertTrue(
            .orderedSame == payload.data.person!.serializeToJSONString()!.compare(expectedPersonJson),
            "Properly serialized person in payload."
        );
        let payloadJson = payload.serializeToJSONString();
        XCTAssertTrue(
            ((payloadJson?.contains(expectedPersonJson)) != nil),
            "Properly serialized person in payload."
        );
    }

    //NOTE: enable the test below after telemetry of os_log is added!!!
//    func testLogTelemetryAutoCapture() {
//
//        RollbarTestUtil.clearLogFile();
//        RollbarTestUtil.clearTelemetryFile();
//        RollbarTelemetry.sharedInstance().clearAllData();
//
//        let logMsg = "log-message-testing";
//        RollbarTelemetry.sharedInstance().clearAllData();
//        //Rollbar.currentConfiguration.accessToken = RollbarUnitTestSettings.deploysWriteAccessToken;
//        Rollbar.currentConfiguration().telemetryEnabled = true;
//        Rollbar.currentConfiguration().captureLogAsTelemetryEvents = true;
//        // The following line ensures the captureLogAsTelemetryData setting is flushed through the internal queue
//        RollbarTelemetry.sharedInstance().getAllData();
//        NSLog(logMsg);
//        Rollbar.debug("test");
//        RollbarTestUtil.waitForPesistenceToComplete();
//
//        let logItem = RollbarTestUtil.readFirstItemStringsFromLogFile()!;
//        let payload = RollbarPayload(jsonString: logItem);
//        let telemetryData = payload.data.body.telemetry!;
//        XCTAssertEqual(telemetryData.count, 1);
//        XCTAssertEqual(telemetryData[0].type, .log);
//        let telemetryMsg = (telemetryData[0].body as! RollbarTelemetryLogBody).message;
//        XCTAssertTrue(logMsg.compare(telemetryMsg) == .orderedSame,
//                      "body.telemetry[0].body.message is \(telemetryMsg), should be \(logMsg)"
//                      );
//    }

    static var allTests = [
        ("testDefaultRollbarConfiguration", testDefaultRollbarConfiguration),
        ("testTelemetryEnabled", testTelemetryEnabled),
        ("testScrubViewInputsTelemetryConfig", testScrubViewInputsTelemetryConfig),
        ("testViewInputTelemetrScrubFieldsConfig", testViewInputTelemetrScrubFieldsConfig),
        ("testEnabled", testEnabled),
        ("testMaximumTelemetryEvents", testMaximumTelemetryEvents),
        ("testCheckIgnore", testCheckIgnore),
        ("testServerData", testServerData),
        ("testPayloadModification", testPayloadModification),
        ("testScrublistFields", testScrublistFields),
        ("testPersonDataAttachment", testPersonDataAttachment),
//        ("testLogTelemetryAutoCapture", testLogTelemetryAutoCapture),
    ]
}
#endif
