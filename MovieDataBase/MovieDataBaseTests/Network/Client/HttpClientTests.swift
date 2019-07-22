//
//  HttpClientTests.swift
//  MovieDataBaseTests
//
//  Created by Judar Lima on 20/07/19.
//  Copyright © 2019 Judar Lima. All rights reserved.
//

import XCTest
@testable import MovieDataBase

struct MockEntity: Decodable {
    let title: String
    let subtitle: String
}

class MockDataTask: URLSessionDataTaskProtocol {
    func resume() { }
}

enum MockClientSetup: ClientSetup {
    case none
    case some

    var endpoint: String {
        switch self {
        case .none:
            return ""
        case .some:
            return "https://www.google.com"
        }
    }
}

class MockURLSession: URLSessionProtocol {
    var nextDataTask = MockDataTask()
    var statusCode: Int = 200
    var nextData: Data?
    var nextError: Error?
    var isInvalidResponse: Bool = false
    private (set) var lastURL: URL?

    func dataTask(with request: URL,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTaskProtocol {
        lastURL = request
        if isInvalidResponse {
            completionHandler(nextData, nil, nextError)
        } else {
            completionHandler(nextData, httpURLResponse(request: request, statusCode: statusCode), nextError)
        }
        nextDataTask.resume()
        return nextDataTask
    }

    func httpURLResponse(request: URL, statusCode: Int) -> URLResponse {
        return HTTPURLResponse(url: request, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
    }
}

class HttpClientTests: XCTestCase {
    var sut: HttpClient!
    var sessionMock: MockURLSession!

    override func setUp() {
        sessionMock = MockURLSession()
        sut = HttpClient(urlSession: sessionMock)
    }

    func test_requestData_whenReceiveInvalidURL_thenReturnUrlNotFound() {
        let expectedError = ClientError.urlNotFound
        let clientExpectation = expectation(description: #function)
        var resultError: ClientError?

        sut.requestData(with: MockClientSetup.none) { (result: Result<MockEntity>) in
            if case let .failure(error) = result {
                resultError = error
            } else {
                XCTFail("Result value is different from \(ClientError.urlNotFound.localizedDescription)")
            }
            clientExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.3) { (_) in
            XCTAssertEqual(resultError, expectedError)
        }
    }

    func test_requestData_whenReceiveErrorFromDataTask_thenReturnUnknownError() {
        let clientExpectation = expectation(description: #function)
        var clientResult: ClientError?

        sessionMock.nextError = ClientError.unknown("_")
        sut.requestData(with: MockClientSetup.some) { (result: Result<MockEntity>) in
            if case let .failure(error) = result {
                clientResult = error
            } else {
                XCTFail("Result value is different from \(ClientError.unknown(""))")
            }
            clientExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.3) { (_) in
            XCTAssertEqual(clientResult?.localizedDescription, self.sessionMock.nextError?.localizedDescription)
        }
    }

    func test_requestData_whenReceiveInvalidData_thenReturnBrokenDataError() {
        let clientExpectation = expectation(description: #function)
        let expectedError = ClientError.brokenData
        var clientResult: ClientError?

        sessionMock.nextData = nil
        sut.requestData(with: MockClientSetup.some) { (result: Result<MockEntity>) in
            if case let .failure(error) = result {
                clientResult = error
            } else {
                XCTFail("Result value is different from \(ClientError.unknown(""))")
            }
            clientExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.3) { (_) in
            XCTAssertEqual(expectedError, clientResult)
        }
    }

    func test_requestData_whenReceiveInvalidHttpResponse_thenReturnInvalidHttpResponseError() {
        let clientExpectation = expectation(description: #function)
        let expectedError = ClientError.invalidHttpResponse
        var clientResult: ClientError?
        sessionMock.nextData = Data(base64Encoded: "someData")
        sessionMock.isInvalidResponse = true

        sut.requestData(with: MockClientSetup.some) { (result: Result<MockEntity>) in
            if case let .failure(error) = result {
                clientResult = error
            } else {
                XCTFail("Result value is different from \(ClientError.invalidHttpResponse)")
            }
            clientExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.3) { (_) in
            XCTAssertEqual(expectedError, clientResult)
        }
    }

    func test_requestData_whenResponseCantBeParsed_thenReturnCouldNotParseObjectError() {
        let clientExpectation = expectation(description: #function)
        let expectedError = ClientError.couldNotParseObject
        var clientResult: ClientError?
        sessionMock.nextData = Data(base64Encoded: "someData")

        sut.requestData(with: MockClientSetup.some) { (result: Result<MockEntity>) in
            if case let .failure(error) = result {
                clientResult = error
            } else {
                XCTFail("Result value is different from \(ClientError.couldNotParseObject)")
            }
            clientExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.3) { (_) in
            XCTAssertEqual(expectedError, clientResult)
        }
    }

    func test_requestData_whenReceiveStatusCode403_thenReturnAuthenticationRequiredError() {
        let clientExpectation = expectation(description: #function)
        let expectedError = ClientError.authenticationRequired
        var clientResult: ClientError?

        sessionMock.nextData = Data(base64Encoded: "someData")
        sessionMock.statusCode = 403

        sut.requestData(with: MockClientSetup.some) { (result: Result<MockEntity>) in
            if case let .failure(error) = result {
                clientResult = error
            } else {
                XCTFail("Result value is different from \(ClientError.authenticationRequired)")
            }
            clientExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.3) { (_) in
            XCTAssertEqual(expectedError, clientResult)
        }
    }

    func test_requestData_whenReceiveStatusCode404_thenReturnAuthenticationRequiredError() {
        let clientExpectation = expectation(description: #function)
        let expectedError = ClientError.couldNotFindHost
        var clientResult: ClientError?
        sessionMock.nextData = Data(base64Encoded: "someData")
        sessionMock.statusCode = 404

        sut.requestData(with: MockClientSetup.some) { (result: Result<MockEntity>) in
            if case let .failure(error) = result {
                clientResult = error
            } else {
                XCTFail("Result value is different from \(ClientError.couldNotParseObject)")
            }
            clientExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.3) { (_) in
            XCTAssertEqual(expectedError, clientResult)
        }
    }

    func test_requestData_whenReceiveStatusCode500_thenReturnAuthenticationRequiredError() {
        let clientExpectation = expectation(description: #function)
        let expectedError = ClientError.badRequest
        var clientResult: ClientError?
        sessionMock.nextData = Data(base64Encoded: "someData")
        sessionMock.statusCode = 500

        sut.requestData(with: MockClientSetup.some) { (result: Result<MockEntity>) in
            if case let .failure(error) = result {
                clientResult = error
            } else {
                XCTFail("Result value is different from \(ClientError.badRequest)")
            }
            clientExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.3) { (_) in
            XCTAssertEqual(expectedError, clientResult)
        }
    }

    func test_requestData_whenReceiveUnknownStatusCode_thenReturnAuthenticationRequiredError() {
        let clientExpectation = expectation(description: #function)
        let expectedError = ClientError.unknown("Unexpected Error.")
        var clientResult: ClientError?
        sessionMock.nextData = Data(base64Encoded: "someData")
        sessionMock.statusCode = -1004

        sut.requestData(with: MockClientSetup.some) { (result: Result<MockEntity>) in
            if case let .failure(error) = result {
                clientResult = error
            } else {
                XCTFail("Result value is different from \(ClientError.unknown("Unexpected Error."))")
            }
            clientExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.3) { (_) in
            XCTAssertEqual(expectedError.localizedDescription, clientResult?.localizedDescription)
        }
    }
}
