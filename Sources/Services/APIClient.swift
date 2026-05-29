import Foundation

/// Generic URL-session-based HTTP client with JSON + multipart support.
/// Two backends share this:
///   - `FastAPIService`  → `https://api.altn.cloud/api/v3`  (no auth)
///   - `ConsentFormsAPI` → `https://admin-api.altn.cloud/api/v2`  (Bearer token)
struct APIClient {

    enum APIError: LocalizedError {
        case invalidURL
        case status(Int, String)
        case decoding(Error)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:               return "Bad URL."
            case .status(let code, let b):  return "HTTP \(code): \(b)"
            case .decoding(let e):          return "Decode error: \(e.localizedDescription)"
            case .transport(let e):         return e.localizedDescription
            }
        }
    }

    let baseURL: URL
    let defaultHeaders: [String: String]

    init(baseURL: URL, defaultHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
    }

    // MARK: - GET / JSON-body requests

    func get<T: Decodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        as _: T.Type = T.self
    ) async throws -> T {
        try await send(path: path, method: "GET", query: query, body: nil, as: T.self)
    }

    func post<T: Decodable>(
        _ path: String,
        jsonBody: Data?,
        timeout: TimeInterval? = nil,
        as _: T.Type = T.self
    ) async throws -> T {
        try await send(path: path, method: "POST", query: [], body: jsonBody, as: T.self, contentType: "application/json", timeout: timeout)
    }

    func post(_ path: String, jsonBody: Data?, timeout: TimeInterval? = nil) async throws {
        _ = try await sendRaw(path: path, method: "POST", query: [], body: jsonBody, contentType: "application/json", timeout: timeout)
    }

    func delete(_ path: String) async throws {
        _ = try await sendRaw(path: path, method: "DELETE", query: [], body: nil, contentType: nil)
    }

    // MARK: - Multipart

    /// POST a single file plus form fields. Returns the raw body on success.
    func uploadMultipart(
        _ path: String,
        fileField: String = "file",
        fileData: Data,
        fileName: String,
        fileMime: String = "application/pdf",
        fields: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> Data {
        let url = try buildURL(path: path, query: [])
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let timeout { req.timeoutInterval = timeout }
        for (k, v) in defaultHeaders { req.setValue(v, forHTTPHeaderField: k) }
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let nl = "\r\n"
        for (k, v) in fields {
            body.append("--\(boundary)\(nl)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(k)\"\(nl)\(nl)".data(using: .utf8)!)
            body.append("\(v)\(nl)".data(using: .utf8)!)
        }
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\(nl)".data(using: .utf8)!)
        body.append("Content-Type: \(fileMime)\(nl)\(nl)".data(using: .utf8)!)
        body.append(fileData)
        body.append(nl.data(using: .utf8)!)
        body.append("--\(boundary)--\(nl)".data(using: .utf8)!)
        req.httpBody = body

        return try await execute(req)
    }

    // MARK: - Raw data download

    func download(_ absoluteURL: URL) async throws -> Data {
        var req = URLRequest(url: absoluteURL)
        req.httpMethod = "GET"
        for (k, v) in defaultHeaders { req.setValue(v, forHTTPHeaderField: k) }
        return try await execute(req)
    }

    // MARK: - Core

    private func send<T: Decodable>(
        path: String,
        method: String,
        query: [URLQueryItem],
        body: Data?,
        as _: T.Type,
        contentType: String? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let data = try await sendRaw(path: path, method: method, query: query, body: body, contentType: contentType, timeout: timeout)
        do {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .custom { decoder in
                let c = try decoder.singleValueContainer()
                // Accept Unix-epoch integers (FastAPI /document) and ISO / MySQL datetime strings (PHP v2).
                if let i = try? c.decode(Double.self) {
                    return Date(timeIntervalSince1970: i)
                }
                let s = try c.decode(String.self)
                if let d = ISO8601DateFormatter.altn.date(from: s) { return d }
                for f in DateFormatter.altnFormats {
                    if let d = f.date(from: s) { return d }
                }
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unrecognized date: \(s)")
            }
            return try dec.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func sendRaw(
        path: String,
        method: String,
        query: [URLQueryItem],
        body: Data?,
        contentType: String?,
        timeout: TimeInterval? = nil
    ) async throws -> Data {
        let url = try buildURL(path: path, query: query)
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let timeout { req.timeoutInterval = timeout }
        for (k, v) in defaultHeaders { req.setValue(v, forHTTPHeaderField: k) }
        if let ct = contentType { req.setValue(ct, forHTTPHeaderField: "Content-Type") }
        req.httpBody = body
        return try await execute(req)
    }

    private func execute(_ req: URLRequest) async throws -> Data {
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw APIError.status(0, "Missing HTTPURLResponse")
            }
            if (200..<300).contains(http.statusCode) { return data }
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.status(http.statusCode, body)
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.transport(error)
        }
    }

    private func buildURL(path: String, query: [URLQueryItem]) throws -> URL {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { comps?.queryItems = query }
        guard let url = comps?.url else { throw APIError.invalidURL }
        return url
    }
}

// MARK: - Date formatters

private extension DateFormatter {
    static let altnFormats: [DateFormatter] = {
        let fmts = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        return fmts.map { pattern in
            let f = DateFormatter()
            f.dateFormat = pattern
            f.timeZone = TimeZone(identifier: "America/Chicago")
            f.locale   = Locale(identifier: "en_US_POSIX")
            return f
        }
    }()
}

private extension ISO8601DateFormatter {
    static let altn: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
