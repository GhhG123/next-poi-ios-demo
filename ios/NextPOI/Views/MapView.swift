import SwiftUI

struct MapView: View {
    @StateObject private var model = MapViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let trip = model.selectedTrip {
                    VStack(spacing: 0) {
                        tripPicker(for: trip)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        TripMap(trip: trip, recommendation: model.recommendation)
                            .id(trip.id)
                        RecommendationPanel(
                            trip: trip,
                            recommendation: model.recommendation,
                            isRecommending: model.isRecommending,
                            errorMessage: model.errorMessage,
                            recommend: model.recommend
                        )
                    }
                } else if let error = model.errorMessage {
                    ContentUnavailableView {
                        Label("无法读取行程", systemImage: "map")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("重试") {
                            Task { await model.loadTrips() }
                        }
                        if model.source == .flask {
                            Button("切回内置演示") { model.source = .bundled }
                        }
                    }
                } else {
                    ProgressView("正在读取行程")
                }
            }
            .navigationTitle("下一站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("数据源", selection: $model.source) {
                            ForEach(DataSource.allCases) { source in
                                Text(source.title).tag(source)
                            }
                        }
                    } label: {
                        Label("数据源", systemImage: "cylinder")
                    }
                    .accessibilityValue(model.source.title)
                }
            }
            .task(id: model.source) { await model.loadTrips() }
        }
        .tint(.teal)
    }

    private func tripPicker(for trip: DemoTrip) -> some View {
        Picker("行程", selection: Binding(
            get: { model.selectedTripID ?? trip.id },
            set: { model.selectTrip($0) }
        )) {
            ForEach(model.trips) { trip in
                Text(trip.title).tag(trip.id)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct RecommendationPanel: View {
    let trip: DemoTrip
    let recommendation: Recommendation?
    let isRecommending: Bool
    let errorMessage: String?
    let recommend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("合成签到 · 演示", systemImage: "map")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
                NavigationLink {
                    CheckInList(trip: trip)
                } label: {
                    Text("签到记录 (\(trip.checkIns.count))")
                        .font(.subheadline.weight(.medium))
                }
            }

            if let recommendation {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.name)
                            .font(.headline)
                        Text("\(recommendation.category) · 预设推荐")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.teal)
                }
                .accessibilityElement(children: .combine)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: recommend) {
                Group {
                    if isRecommending {
                        ProgressView()
                            .tint(.white)
                            .accessibilityLabel("正在获取推荐")
                    } else {
                        Label("推荐下一站", systemImage: "location.fill")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRecommending)
        }
        .padding(16)
        .background(.background)
    }
}

private struct CheckInList: View {
    let trip: DemoTrip

    var body: some View {
        List(trip.checkIns) { checkIn in
            HStack(spacing: 16) {
                Text(checkIn.time)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(checkIn.name)
                    Text("\(checkIn.city) · \(checkIn.category)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .navigationTitle(trip.title)
    }
}
