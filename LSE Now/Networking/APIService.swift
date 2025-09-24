//
//  APIService.swift
//  LSE Now
//
//  Created by Pietro Canovari on 9/17/25.
//

import Foundation

final class APIService {
    static let shared = APIService()

    private let baseURL = URL(string: "https://www.beavr.net/api")!
    private let urlSession: URLSession

    enum MessageFolder: String {
        case received
        case sent
    }

    init(session: URLSession = .shared) {
        self.urlSession = session
    }

    // MARK: - Posts
    func fetchPosts(completion: @escaping (Result<[Post], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("posts")
        let task = urlSession.dataTask(with: url) { data, resp, err in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let data = data else {
                completion(.failure(APIServiceError.invalidResponse))
                return
            }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let posts = try decoder.decode([Post].self, from: data)
                completion(.success(posts))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Auth
    func requestLoginCode(for email: String) async throws {
        let endpoint = baseURL.appendingPathComponent("request_code.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeFormBody(["email": email])
        _ = try await perform(request: request)
    }

    func verifyLoginCode(email: String, code: String) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("verify_code.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeFormBody(["email": email, "code": code])

        let data = try await perform(request: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(VerifyResponse.self, from: data)

        guard response.success, let token = response.token, !token.isEmpty else {
            throw APIServiceError.invalidResponse
        }
        return token
    }

    // MARK: - Events
    func submitEvent(draft: PostDraft, token: String) async throws {
        let endpoint = baseURL.appendingPathComponent("events.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        setAuthorizationHeader(on: &request, token: token)

        let payload = EventSubmissionPayload(
            title: draft.title,
            startTime: draft.startTime,
            endTime: draft.endTime,
            location: draft.location,
            room: draft.room,
            description: draft.description,
            organization: draft.organization,
            category: draft.category,
            contact: draft.contact,
            link: draft.link,
            latitude: draft.latitude,
            longitude: draft.longitude,
            creator: draft.creator
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)
        _ = try await perform(request: request)
    }

    func fetchMyEvents(token: String) async throws -> [Post] {
        var components = URLComponents(url: baseURL.appendingPathComponent("events.php"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "mine", value: "1")]

        guard let url = components?.url else { throw APIServiceError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        setAuthorizationHeader(on: &request, token: token)

        let data = try await perform(request: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Post].self, from: data)
    }

    func fetchLikedEvents(token: String) async throws -> [Post] {
        var components = URLComponents(url: baseURL.appendingPathComponent("events.php"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "liked", value: "1")]

        guard let url = components?.url else { throw APIServiceError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        setAuthorizationHeader(on: &request, token: token)

        let data = try await perform(request: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Post].self, from: data)
    }

    func likeEvent(id: Int, token: String) async throws {
        let endpoint = baseURL.appendingPathComponent("event_likes.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuthorizationHeader(on: &request, token: token)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(EventLikePayload(eventId: id))
        _ = try await perform(request: request)
    }

    func unlikeEvent(id: Int, token: String) async throws {
        let endpoint = baseURL.appendingPathComponent("event_likes.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuthorizationHeader(on: &request, token: token)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(EventLikePayload(eventId: id))
        _ = try await perform(request: request)
    }

    func cancelEvent(id: Int, token: String) async throws {
        let endpoint = baseURL.appendingPathComponent("events.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuthorizationHeader(on: &request, token: token)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(CancelEventPayload(id: id))
        _ = try await perform(request: request)
    }

    // MARK: - Deals
    func submitDeal(payload: DealSubmissionPayload, token: String, creatorEmail: String) async throws {
        let endpoint = baseURL.appendingPathComponent("deals.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        setAuthorizationHeader(on: &request, token: token)

        let requestPayload = DealSubmissionRequest(
            name: payload.name,
            type: payload.type,
            discount: payload.discount,
            description: payload.description,
            location: payload.location,
            link: payload.link,
            startDate: payload.startDate,
            endDate: payload.endDate,
            creator: creatorEmail
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(requestPayload)
        _ = try await perform(request: request)
    }

    // MARK: - Location (email instead of token)
    func updateUserLocation(email: String, latitude: Double, longitude: Double, timestamp: Date) async throws {
        let endpoint = baseURL.appendingPathComponent("user_location.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = LocationUpdatePayload(
            email: email,
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)
        _ = try await perform(request: request)
    }

    // MARK: - Pins
    func fetchPins(cacheBustingToken: String? = nil) async throws -> [WhiteboardPin] {
        var endpoint = baseURL.appendingPathComponent("pins.php")
        let trimmedToken = cacheBustingToken?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let token = trimmedToken, !token.isEmpty {
            var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "ts", value: token))
            components?.queryItems = queryItems
            if let urlWithQuery = components?.url {
                endpoint = urlWithQuery
            }
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        if let token = trimmedToken, !token.isEmpty {
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        }

        let data = try await perform(request: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([WhiteboardPin].self, from: data)
    }

    func createPin(request: CreatePinRequest, token: String) async throws -> WhiteboardPin {
        let endpoint = baseURL.appendingPathComponent("pins.php")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        setAuthorizationHeader(on: &urlRequest, token: token)

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let data = try await perform(request: urlRequest)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WhiteboardPin.self, from: data)
    }

    func deletePin(id: Int, token: String) async throws {
        let endpoint = baseURL.appendingPathComponent("pins.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        setAuthorizationHeader(on: &request, token: token)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(DeletePinRequest(id: id))

        _ = try await perform(request: request)
    }

    // MARK: - Messages
    func sendPinReply(payload: PinReplyPayload, token: String) async throws -> WhiteboardMessage {
        let endpoint = baseURL.appendingPathComponent("messages.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        setAuthorizationHeader(on: &request, token: token)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let data = try await perform(request: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(SendMessageResponse.self, from: data)
        return response.message
    }

    func fetchMessages(folder: MessageFolder, token: String) async throws -> [WhiteboardMessage] {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages.php"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "box", value: folder.rawValue)]

        guard let url = components?.url else { throw APIServiceError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        setAuthorizationHeader(on: &request, token: token)

        let data = try await perform(request: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([WhiteboardMessage].self, from: data)
    }

    // MARK: - Notifications
    func registerNotificationDevice(
        token deviceToken: String,
        environment: String,
        appVersion: String?,
        osVersion: String?,
        authToken: String
    ) async throws {
        let endpoint = baseURL.appendingPathComponent("notification_tokens.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        setAuthorizationHeader(on: &request, token: authToken)

        let payload = NotificationRegistrationPayload(
            deviceToken: deviceToken,
            platform: "ios",
            environment: environment,
            appVersion: appVersion,
            osVersion: osVersion
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)
        _ = try await perform(request: request)
    }

    func unregisterNotificationDevice(deviceToken: String, authToken: String) async throws {
        let endpoint = baseURL.appendingPathComponent("notification_tokens.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuthorizationHeader(on: &request, token: authToken)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(NotificationUnregisterPayload(deviceToken: deviceToken))
        _ = try await perform(request: request)
    }

    // MARK: - Internals
    private func perform(request: URLRequest) async throws -> Data {
        #if DEBUG
        debugLogRequest(request)
        #endif

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            if (error as? URLError)?.code == .cancelled {
                // Don’t log as ❌ — just quietly bubble up
                print("↩️ [API] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "<nil>") was cancelled")
                throw error
            }
            #if DEBUG
            debugLogNetworkFailure(for: request, error: error)
            #endif
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }

        #if DEBUG
        debugLogResponse(httpResponse, data: data)
        #endif

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let message = decodeErrorMessage(from: data) {
                throw APIServiceError.serverMessage(message)
            }
            throw APIServiceError.serverMessage("The server returned an unexpected error (\(httpResponse.statusCode)).")
        }
        return data
    }

    private func setAuthorizationHeader(on request: inout URLRequest, token: String) {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return }
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
    }

    private func makeFormBody(_ parameters: [String: String]) -> Data? {
        parameters
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(ErrorResponse.self, from: data).error
    }

    #if DEBUG
    private func debugLogRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "GET"
        let urlString = request.url?.absoluteString ?? "<nil>"
        var lines: [String] = ["➡️ [API] \(method) \(urlString)"]

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            let sanitized = headers.map { key, value -> String in
                if key.caseInsensitiveCompare("Authorization") == .orderedSame {
                    return "   \(key): <redacted>"
                }
                return "   \(key): \(value)"
            }.sorted()

            if !sanitized.isEmpty {
                lines.append("   Headers:")
                lines.append(contentsOf: sanitized)
            }
        }

        if let body = request.httpBody, !body.isEmpty {
            let bodyString = String(data: body, encoding: .utf8) ?? "<non-UTF8 body \(body.count) bytes>"
            lines.append("   Body: \(bodyString)")
        }

        print(lines.joined(separator: "\n"))
    }

    private func debugLogResponse(_ response: HTTPURLResponse, data: Data) {
        let urlString = response.url?.absoluteString ?? "<nil>"
        var lines: [String] = ["⬅️ [API] \(response.statusCode) \(urlString)"]

        if !data.isEmpty {
            let bodyString = String(data: data, encoding: .utf8) ?? "<non-UTF8 body \(data.count) bytes>"
            lines.append("   Response Body: \(bodyString)")
        }

        print(lines.joined(separator: "\n"))
    }

    private func debugLogNetworkFailure(for request: URLRequest, error: Error) {
        let method = request.httpMethod ?? "GET"
        let urlString = request.url?.absoluteString ?? "<nil>"
        print("❌ [API] \(method) \(urlString) failed: \(error.localizedDescription)")
    }
    #endif
}

// MARK: - Payloads
private struct VerifyResponse: Decodable {
    let success: Bool
    let token: String?
}

private struct EventSubmissionPayload: Encodable {
    let title: String
    let startTime: Date
    let endTime: Date?
    let location: String
    let room: String?
    let description: String
    let organization: String
    let category: String
    let contact: ContactInfo?
    let link: String?
    let latitude: Double
    let longitude: Double
    let creator: String
}

private struct CancelEventPayload: Encodable {
    let id: Int
}

private struct EventLikePayload: Encodable {
    let eventId: Int
}

struct DealSubmissionPayload: Encodable {
    let name: String
    let type: String
    let discount: String
    let description: String
    let location: String?
    let link: String?
    let startDate: Date
    let endDate: Date?
}

private struct DealSubmissionRequest: Encodable {
    let name: String
    let type: String
    let discount: String
    let description: String
    let location: String?
    let link: String?
    let startDate: Date
    let endDate: Date?
    let creator: String
}

private struct ErrorResponse: Decodable {
    let error: String
}

private struct LocationUpdatePayload: Encodable {
    let email: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

struct CreatePinRequest: Encodable {
    let emoji: String
    let text: String
    let author: String?
    let creatorEmail: String
    let gridRow: Int
    let gridCol: Int
}

private struct DeletePinRequest: Encodable {
    let id: Int
}

struct PinReplyPayload: Encodable {
    let pinId: Int
    let message: String
    let author: String?
}

private struct SendMessageResponse: Decodable {
    let success: Bool
    let message: WhiteboardMessage
}

private struct NotificationRegistrationPayload: Encodable {
    let deviceToken: String
    let platform: String
    let environment: String
    let appVersion: String?
    let osVersion: String?
}

private struct NotificationUnregisterPayload: Encodable {
    let deviceToken: String
}

enum APIServiceError: LocalizedError {
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from the server."
        case .serverMessage(let message):
            return message
        }
    }
}
