//
//  APIService.swift
//  LSE Now
//
//  Created by Pietro Canovari on 9/17/25.
//


import Foundation

class APIService {
    static let shared = APIService()
    let baseURL = URL(string: "https://your-backend.lsehub.app")!   // change later

    func fetchPosts(completion: @escaping (Result<[Post], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/posts")
        let task = URLSession.shared.dataTask(with: url) { data, resp, err in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "", code:-1, userInfo: nil)))
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

    // functions for saving post, login, etc.
}
