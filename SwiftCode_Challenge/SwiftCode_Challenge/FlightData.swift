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

/// A simple row view that displays a flight detail label and its corresponding value.
///
/// `FlightDetailsRow` presents two pieces of text horizontally:
/// a leading title and a trailing value. The title is rendered in a
/// bold style to distinguish it from the value. A spacer is used to
/// push the two elements to opposite sides of the row.
///
/// This view is typically used in summary or detail screens where
/// multiple rows present structured information, such as flight time,
/// departure gate, terminal, or flight number.
///
/// Example:
/// ```swift
/// FlightDetailsRow(title: "Gate", value: "A12")
/// ```
///
/// The row does not impose specific layout constraints on its parent,
/// allowing it to adapt naturally to the surrounding container.
struct FlightDetailsRow: View {
    /// The descriptive label displayed at the leading edge of the row.
    let title: String
    /// The value shown at the trailing edge of the row.
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

/// A service that provides access to flight status information.
///
/// Conforming types are responsible for retrieving and maintaining the
/// status of a specific flight. The service exposes the most recently
/// available `FlightStatusData` and offers a method for initiating a
/// status fetch based on a flight identifier.
protocol FlightDataService {
    /// The latest status information for the requested flight.
    ///
    /// This value is `nil` until a status request has been performed or
    /// if the service has not yet received any data. Conforming types may
    /// update this property asynchronously after a call to ``loadStatus(for:)``.
    var flightStatus: FlightStatusData? { get }
    
    /// Requests the status of the specified flight.
    ///
    /// Implementations determine how and when the request is fulfilled.
    /// This method may perform asynchronous work, such as network calls
    /// or database lookups, and update ``flightStatus`` upon completion.
    ///
    /// - Parameter flightID:
    ///   A string that uniquely identifies the flight whose status
    ///   information should be fetched. Implementations may normalize or
    ///   validate this identifier as needed.
    func loadStatus(for flightID: String)
}

// MARK: - ViewModel

/// Initiates an asynchronous request to retrieve the latest flight status.
///
/// Calling this method sets `isLoading` to `true` and clears any existing
/// `errorMessage`, allowing the view to reflect a new loading cycle.
/// The method simulates a network delay before completing, and is intended
/// to be replaced with the actual flight-status fetching logic.
///
/// Use this method when you want to explicitly refresh the flight status
/// outside of the automatic updates performed in the initializer.
///
/// - Note: This method does not currently perform a real network request.
///   Replace the placeholder implementation with a call to `FlightDataService`
///   when backend integration is available.
///
/// - SeeAlso: ``FlightDataService``, ``flightStatus``, ``isLoading``
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
