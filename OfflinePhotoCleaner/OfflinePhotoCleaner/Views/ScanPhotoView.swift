import SwiftUI
import SwiftData
import Photos

struct ScanPhotoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PhashProcessor.self) private var phashProcessor
    
    @State private var reloadFlag = true
    @State private var networkMonitor = NetworkMonitor()
    
    @Query private var photoInfoList: [PhotoInfo]
    @Query private var phashMapList: [PhashMap]
    @Query private var bkTreeList: [BKtreePersistent]
    
    var body: some View {
        VStack {
            Text("フォトライブラリ内の画像を解析し、見た目が似ている画像を検出")
                .font(.largeTitle)
                .padding()

            ProgressView(value: phashProcessor.progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .padding()

            Button(action: {
                phashProcessor.processPhotos(modelContext: modelContext)
            }) {
                Text("画像の読み込みを開始")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            
            Spacer()
            
            if networkMonitor.isConnected {
                Text("インターネット接続中")
                    .foregroundColor(.green)
                    .cornerRadius(10)
                    .font(.largeTitle)
            } else {
                Text("インターネット未接続")
                    .foregroundColor(.red)
                    .cornerRadius(10)
                    .font(.largeTitle)
            }
            
            PhotoLibraryPermissionView()
            
            Button(action: {
                clearAllModel()
            }) {
                Text("計算結果をクリア")
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }
            .padding()

        }
        .padding()
        .onAppear(){
            if reloadFlag {
                reload()
                reloadFlag = false
            }
        }
    }

    private func reload() {
        if !bkTreeList.isEmpty {
            phashProcessor.loadBKTree(bktree: bkTreeList[0].bkTree)
        }
    }
    
    private func clearAllModel() {
        do {
            try modelContext.delete(model: PhashMap.self)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        do {
            try modelContext.delete(model: BKtreePersistent.self)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

struct PhotoLibraryPermissionView: View {
    @State private var photoManager = PhotoPermission()

    var body: some View {
        VStack {
            Text("すべての画像解析と処理はオフラインで行われ、データは外部に送信されません")
                .font(.headline)
                .padding()

            switch photoManager.authorizationStatus {
            case .authorized:
                Text("写真ライブラリへのアクセスが許可")
                    .foregroundColor(.green)
            case .denied:
                Text("写真ライブラリへのアクセスが拒否")
                    .foregroundColor(.red)
                Button(action: {
                    photoManager.openSettings()
                }) {
                    Text("設定を開く")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            case .notDetermined:
                Text("写真ライブラリへのアクセスが未定")
                    .foregroundColor(.orange)
                Button(action: {
                    photoManager.requestPhotoLibraryPermission()
                }) {
                    Text("アクセス許可をリクエストする")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            case .restricted:
                Text("写真ライブラリへのアクセスが制限")
                    .foregroundColor(.gray)
            case .limited:
                Text("写真ライブラリへのアクセスが制限")
                    .foregroundColor(.gray)
            @unknown default:
                Text("認証ステータスが不明")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .onAppear {
            photoManager.checkPhotoLibraryPermission()
        }
    }
}
