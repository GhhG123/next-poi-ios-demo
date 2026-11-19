import Foundation

enum DataSource: String, CaseIterable, Identifiable {
    case bundled
    case flask

    var id: Self { self }

    var title: String {
        switch self {
        case .bundled: "内置演示"
        case .flask: "本地 Flask"
        }
    }
}

enum DemoError: LocalizedError {
    case missingData
    case invalidResponse
    case unavailable(Int)

    var errorDescription: String? {
        switch self {
        case .missingData: "找不到演示数据。"
        case .invalidResponse: "服务返回的数据格式不符合预期。"
        case let .unavailable(status): "本地服务暂不可用（HTTP \(status)）。"
        }
    }
}

struct POIService {
    let fixture: DemoData
    private let baseURL: URL

    init(fixture: DemoData, baseURL: URL = URL(string: "http://localhost:5000")!) {
        self.fixture = fixture
        self.baseURL = baseURL
    }

    static func bundled() throws -> POIService {
        guard let url = Bundle.main.url(forResource: "DemoData", withExtension: "json") else {
            throw DemoError.missingData
        }
        let fixture = try JSONDecoder().decode(DemoData.self, from: Data(contentsOf: url))
        return POIService(fixture: fixture)
    }

    func trips(source: DataSource) async throws -> [DemoTrip] {
        guard source == .flask else { return fixture.trips }
        let response: RecordsResponse = try await post(
            "get_records", body: Payload(userID: fixture.userID)
        )
        guard response.records.count == fixture.trips.count,
              response.records.allSatisfy({ !$0.isEmpty }) else {
            throw DemoError.invalidResponse
        }
        return zip(fixture.trips, response.records).map { trip, records in
            var updatedTrip = trip
            updatedTrip.checkIns = records
            return updatedTrip
        }
    }

    func recommend(trip: DemoTrip, source: DataSource) async throws -> Recommendation {
        guard source == .flask else { return trip.recommendation }
        let response: PredictionResponse = try await post(
            "predict_poi", body: Payload(userID: fixture.userID, sequence: trip.id)
        )
        guard response.mode == "demo" else { throw DemoError.invalidResponse }
        return response.predictedPOI
    }

    private func post<Response: Decodable>(_ path: String, body: Payload) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw DemoError.invalidResponse }
        guard (200...299).contains(response.statusCode) else {
            throw DemoError.unavailable(response.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private struct Payload: Encodable {
        let userID: Int
        var sequence: Int? = nil

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case sequence = "sequence_num"
        }
    }

    private struct RecordsResponse: Decodable {
        let records: [[CheckIn]]
    }

    private struct PredictionResponse: Decodable {
        let predictedPOI: Recommendation
        let mode: String

        enum CodingKeys: String, CodingKey {
            case predictedPOI = "predicted_poi"
            case mode
        }
    }
}
