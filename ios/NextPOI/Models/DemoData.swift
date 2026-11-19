import Foundation

struct CheckIn: Decodable, Identifiable {
    let venueID: Int
    let name: String
    let category: String
    let city: String
    let latitude: Double
    let longitude: Double
    let time: String

    var id: String { "\(venueID)-\(time)" }

    enum CodingKeys: String, CodingKey {
        case venueID = "venueid"
        case time = "timestamp"
        case name, category, city, latitude, longitude
    }
}

struct Recommendation: Decodable, Identifiable {
    let id: Int
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case id = "venueid"
        case name, category, latitude, longitude
    }
}

struct DemoTrip: Decodable, Identifiable {
    let id: Int
    let title: String
    let destination: String
    var checkIns: [CheckIn]
    let recommendation: Recommendation

    var destinationCheckIns: [CheckIn] {
        // 原版地图聚焦于最近一段同地区的签到。
        Array(checkIns.reversed().prefix { $0.city == destination }.reversed())
    }

    enum CodingKeys: String, CodingKey {
        case id, title, destination, recommendation
        case checkIns = "check_ins"
    }
}

struct DemoData: Decodable {
    let userID: Int
    let trips: [DemoTrip]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case trips
    }
}
