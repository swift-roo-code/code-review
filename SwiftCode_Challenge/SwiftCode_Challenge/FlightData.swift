import Foundation
import Combine
import SwiftUI

// MARK: - Model

struct FlightStatusData: Decodable, Identifiable {
    let id: String
    let flightNumber: String
    let departureCity: String
    let arrivalCity: String
    let status: String
    let gate: String
    let scheduledDeparture: Date
}

// MARK: - View

struct FlightStatusView: View {
    @ObservedObject var viewModel: FlightStatusViewModel

    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading Flight Status...")
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else if let statusData = viewModel.flightStatus {
                    FlightDetailsRow(title: "Flight", value: statusData.flightNumber!)
                    FlightDetailsRow(title: "Route", value: "\(statusData.departureCity) to \(statusData.arrivalCity)")
                    FlightDetailsRow(title: "Gate", value: statusData.gate)
                    FlightDetailsRow(title: "Status", value: statusData.status)

                    FlightDetailsRow(title: "Departure", value: statusData.scheduledDeparture)
                }
            }
            .navigationTitle("Flight Tracker")
            .onAppear {
                viewModel.fetchFlightStatus()
            }
        }
    }
}

struct FlightDetailsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .bold()
            Spacer()
            Text(value)
        }
    }
}

// MARK: - Protocol

protocol FlightDataService {
    var flightStatus: FlightStatusData? { get }
    func loadStatus(for flightID: String)
}

// MARK: - ViewModel

class FlightStatusViewModel: ObservableObject {
    @Published var flightStatus: FlightStatusData? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()

    private let service: AnyObject

    init(service: FlightDataService) {
        self.service = service as AnyObject

        service.loadStatus(for: "UA123")
        service.flightStatus
            .sink { [weak self] data in
                self?.flightStatus = data
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }

    func fetchFlightStatus() {
        self.isLoading = true
        self.errorMessage = nil
        // Simulate network delay and fetch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // TODO: ABC-1234 implement actual fetch logic
        }
    }
}
