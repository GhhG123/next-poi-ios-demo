import Combine
import Foundation

@MainActor
final class MapViewModel: ObservableObject {
    @Published var source: DataSource = .bundled
    @Published private(set) var trips: [DemoTrip] = []
    @Published private(set) var selectedTripID: Int?
    @Published private(set) var recommendation: Recommendation?
    @Published private(set) var isRecommending = false
    @Published private(set) var errorMessage: String?

    private var recommendationTask: Task<Void, Never>?

    var selectedTrip: DemoTrip? {
        trips.first { $0.id == selectedTripID }
    }

    func loadTrips() async {
        let selectedSource = source
        let previousTripID = selectedTripID
        clearRecommendation()
        trips = []
        do {
            let trips = try await POIService.bundled().trips(source: selectedSource)
            guard !Task.isCancelled, source == selectedSource else { return }
            self.trips = trips
            selectedTripID = trips.first(where: { $0.id == previousTripID })?.id ?? trips.first?.id
        } catch {
            guard !Task.isCancelled, source == selectedSource else { return }
            errorMessage = message(for: error)
        }
    }

    func selectTrip(_ id: Int) {
        guard id != selectedTripID, trips.contains(where: { $0.id == id }) else { return }
        clearRecommendation()
        selectedTripID = id
    }

    func recommend() {
        guard let trip = selectedTrip, !isRecommending else { return }
        let selectedSource = source
        errorMessage = nil
        isRecommending = true
        recommendationTask = Task {
            do {
                let place = try await POIService.bundled().recommend(trip: trip, source: selectedSource)
                guard !Task.isCancelled, source == selectedSource else { return }
                recommendation = place
            } catch {
                guard !Task.isCancelled, source == selectedSource else { return }
                errorMessage = message(for: error)
            }
            isRecommending = false
            recommendationTask = nil
        }
    }

    private func clearRecommendation() {
        recommendationTask?.cancel()
        recommendationTask = nil
        recommendation = nil
        isRecommending = false
        errorMessage = nil
    }

    private func message(for error: Error) -> String {
        guard !(error is URLError) else {
            return "无法连接本地 Flask。启动端口 5000 的服务，或切回内置演示。"
        }
        return error.localizedDescription
    }
}
