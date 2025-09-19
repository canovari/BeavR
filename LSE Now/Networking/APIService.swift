//
//  APIService.swift
//  LSE Now
//
//  Created by Pietro Canovari on 9/17/25.
//

import Foundation

final class APIService {
    static let shared = APIService()

    private let baseURL = URL(string: "https://www.canovari.com/api")!
    private let urlSession: URLSession

    enum MessageFolder: String {
        case received
        case sent
    }

    init(session: URLSession = .shared) {
        self.urlSession = session
    }

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

    func submitEvent(draft: PostDraft, token: String) async throws {
        let endpoint = baseURL.appendingPathComponent("events.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let payload = EventSubmissionPayload(
            title: draft.title,
            startTime: draft.startTime,
            endTime: draft.endTime,
            location: draft.location,
            description: draft.description,
            organization: draft.organization,
            category: draft.category,
            contact: draft.contact,
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

        guard let url = components?.url else {
            throw APIServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try await perform(request: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Post].self, from: data)
    }

    func cancelEvent(id: Int, token: String) async throws {
        let endpoint = baseURL.appendingPathComponent("events.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(CancelEventPayload(id: id))

        _ = try await perform(request: request)
    }

    func fetchPins() async throws -> [WhiteboardPin] {
        let endpoint = baseURL.appendingPathComponent("pins.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let data = try await perform(request: urlRequest)

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WhiteboardPin.self, from: data)
        } catch {
            let fallbackDecoder = JSONDecoder()
            fallbackDecoder.dateDecodingStrategy = .iso8601
            if let envelope = try? fallbackDecoder.decode(CreatePinEnvelope.self, from: data),
               let pin = envelope.resolvedPin {
                return pin
            }

            throw error
        }
    }

    func sendPinReply(payload: PinReplyPayload, token: String) async throws -> WhiteboardMessage {
        let endpoint = baseURL.appendingPathComponent("messages.php")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

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

        guard let url = components?.url else {
            throw APIServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try await perform(request: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([WhiteboardMessage].self, from: data)
    }

    private func perform(request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let message = decodeErrorMessage(from: data) {
                throw APIServiceError.serverMessage(message)
            }
            throw APIServiceError.serverMessage("The server returned an unexpected error (\(httpResponse.statusCode)).")
        }

        return data
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
}

private struct VerifyResponse: Decodable {
    let success: Bool
    let token: String?
}

private struct EventSubmissionPayload: Encodable {
    let title: String
    let startTime: Date
    let endTime: Date?
    let location: String
    let description: String
    let organization: String
    let category: String
    let contact: ContactInfo
    let latitude: Double
    let longitude: Double
    let creator: String
}

private struct CancelEventPayload: Encodable {
    let id: Int
}

private struct ErrorResponse: Decodable {
    let error: String
}

struct CreatePinRequest: Encodable {
    let emoji: String
    let text: String
    let author: String?
    let gridRow: Int
    let gridCol: Int
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

private struct CreatePinEnvelope: Decodable {
    let success: Bool?
    let pin: WhiteboardPin?
    let data: WhiteboardPin?

    var resolvedPin: WhiteboardPin? {
        pin ?? data
    }
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
