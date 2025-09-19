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

private struct ErrorResponse: Decodable {
    let error: String
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
