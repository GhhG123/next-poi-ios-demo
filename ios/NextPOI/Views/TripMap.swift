import MapKit
import SwiftUI

struct TripMap: View {
    let trip: DemoTrip
    let recommendation: Recommendation?

    @State private var camera: MapCameraPosition = .automatic
    @State private var selection: Selection?
    @State private var showsEntireTrip = false

    private enum Selection: Hashable {
        case checkIn(String)
        case recommendation(Int)
    }

    private var visibleCheckIns: [CheckIn] {
        let destinationCheckIns = trip.destinationCheckIns
        return showsEntireTrip || destinationCheckIns.isEmpty ? trip.checkIns : destinationCheckIns
    }

    private var selectedPlaceName: String? {
        switch selection {
        case let .checkIn(id):
            visibleCheckIns.first { $0.id == id }?.name
        case .recommendation:
            recommendation?.name
        case nil:
            nil
        }
    }

    var body: some View {
        let checkIns = visibleCheckIns
        Map(position: $camera, selection: $selection) {
            if checkIns.count > 1 {
                MapPolyline(coordinates: checkIns.map(\.coordinate))
                    .stroke(.blue.opacity(0.5), lineWidth: 3)
            }
            ForEach(checkIns) { place in
                Marker(place.name, systemImage: "mappin", coordinate: place.coordinate)
                    .tint(.blue)
                    .tag(Selection.checkIn(place.id))
            }
            if let recommendation {
                Marker(recommendation.name, systemImage: "star.fill", coordinate: recommendation.coordinate)
                    .tint(.teal)
                    .tag(Selection.recommendation(recommendation.id))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .overlay(alignment: .top) {
            HStack {
                if let selectedPlaceName {
                    Text(selectedPlaceName)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                }
                Spacer()
                Button(showsEntireTrip ? "看目的地" : "看全程") {
                    showsEntireTrip.toggle()
                    selection = nil
                    focusMap()
                }
                .buttonStyle(.bordered)
                .background(.regularMaterial, in: Capsule())
            }
            .padding(12)
        }
        .onChange(of: recommendation?.id, initial: true) { _, id in
            if let id {
                showsEntireTrip = false
                selection = .recommendation(id)
            }
            focusMap()
        }
    }

    private func focusMap() {
        var coordinates = visibleCheckIns.map(\.coordinate)
        if let recommendation { coordinates.append(recommendation.coordinate) }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.018, (maxLat - minLat) * 1.85),
            longitudeDelta: max(0.025, (maxLon - minLon) * 1.85)
        )
        withAnimation { camera = .region(MKCoordinateRegion(center: center, span: span)) }
    }
}

private extension CheckIn {
    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
}

private extension Recommendation {
    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
}
