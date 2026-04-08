import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var connectionType = NWInterface.InterfaceType.other
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type ?? .other
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}
