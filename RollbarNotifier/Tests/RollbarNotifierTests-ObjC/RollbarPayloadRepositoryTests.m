//
//  RollbarPayloadRepositoryTests.m
//  
//
//  Created by Andrey Kornich on 2022-07-28.
//

#import <XCTest/XCTest.h>
#import "../../Sources/RollbarNotifier/RollbarPayloadRepository.h"

@import UnitTesting;

@interface RollbarPayloadRepositoryTests : XCTestCase

@end

@implementation RollbarPayloadRepositoryTests

- (void)setUp {

    [super setUp];
    
    [RollbarTestUtil deletePayloadsStoreFile];
    XCTAssertFalse([RollbarTestUtil checkPayloadsStoreFileExists]);
}

- (void)tearDown {

    //[RollbarTestUtil deletePayloadsStoreFile];

    [super tearDown];
}

- (void)testRepoInitialization {
    
    XCTAssertFalse([RollbarTestUtil checkPayloadsStoreFileExists]);
    RollbarPayloadRepository *repo = [RollbarPayloadRepository new];
    XCTAssertTrue([RollbarTestUtil checkPayloadsStoreFileExists]);
    
    XCTAssertFalse([repo checkIfTableExists_Unknown]);
    XCTAssertTrue ([repo checkIfTableExists_Destinations]);
    XCTAssertTrue ([repo checkIfTableExists_Payloads]);

    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testInsertDestination {
    
    RollbarPayloadRepository *repo = [RollbarPayloadRepository new];
    [repo insertDestinationWithEndpoint:@"EP_001" andAccesToken:@"AC_001"];
    
    NSDictionary<NSString *, NSString *> * destination =
    [repo selectDestinationWithEndpoint:@"EP_001" andAccesToken:@"AC_001"];
    
    XCTAssertTrue([destination.allKeys containsObject:@"id"]);
    XCTAssertTrue([destination.allKeys containsObject:@"endpoint"]);
    XCTAssertTrue([destination.allKeys containsObject:@"access_token"]);
    
    XCTAssertTrue([destination.allValues containsObject:@"EP_001"]);
    XCTAssertTrue([destination.allValues containsObject:@"AC_001"]);

    XCTAssertTrue([destination[@"endpoint"] isEqualToString:@"EP_001"]);
    XCTAssertTrue([destination[@"access_token"] isEqualToString:@"AC_001"]);
}

- (void)testRepoInitializationPerformance {

    [self measureBlock:^{
        RollbarPayloadRepository *repo = [RollbarPayloadRepository new];
    }];
}

@end
