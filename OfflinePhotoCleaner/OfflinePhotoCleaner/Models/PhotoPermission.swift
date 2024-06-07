import Foundation
import SwiftData
import SwiftUI
import Photos
import Network

@Observable
class PhotoPermission{
    var authorizationStatus: PHAuthorizationStatus = .notDetermined

    init() {
        checkPhotoLibraryPermission()
    }

    func checkPhotoLibraryPermission() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus()
    }

    func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
            }
        }
    }

    func openSettings() {
        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettings)
        }
    }
}

@Observable
class NetworkMonitor{
    private var monitor: NWPathMonitor
    private var queue = DispatchQueue.global(qos: .background)
    
    var isConnected: Bool = false
    
    init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}
