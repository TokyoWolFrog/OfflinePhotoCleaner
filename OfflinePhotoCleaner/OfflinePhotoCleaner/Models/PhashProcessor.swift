import Photos
import SwiftUI
import SwiftData
import SwiftImageHash
import SwiftPhashBKtree

@Observable
class PhashProcessor {
    var progress: Double = 0
    var phashBKtree = BKtreeInMemory()
    
    func loadBKTree(bktree: String) {
        if let json = convertStringToJSON(bktree){
            phashBKtree.bkTree = SwiftPhashBKTree.fromJSON(json: json)
        }
    }
    
    func processPhotos(modelContext: ModelContext) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var index = 0
        let total = assets.count

        assets.enumerateObjects { (asset, count, stop) in
            self.getFullSizeImage(asset: asset) { image in
                if let phash = self.calculatePHash(image: image) {
                    let id = asset.localIdentifier
                    let date = asset.creationDate!
                    
                    let emptyFlag = self.checkPhotoID(id: id, modelContext: modelContext)
                    if emptyFlag {
                        let existPhash = self.checkPhash(phash: phash, modelContext: modelContext)
            
                        if existPhash.isEmpty {
                            let tempPhashMap = PhashMap(phash: phash)
                            modelContext.insert(tempPhashMap)
                            
                            let tempPhotoInfo = PhotoInfo(id: id, timestamp: date)
                            modelContext.insert(tempPhotoInfo)
                            tempPhotoInfo.phash = tempPhashMap
                            self.phashBKtree.bkTree.insert(value: phash, metadata: ["phash" : phash, "key" : id])
                        } else {
                            let tempPhotoInfo = PhotoInfo(id: id, timestamp: date)
                            modelContext.insert(tempPhotoInfo)
                            tempPhotoInfo.phash = existPhash[0]
                        }
                    }
                }

                // Update progress
                DispatchQueue.main.async {
                    index += 1
                    self.progress = Double(index) / Double(total)
                    if self.progress == Double(1) {
                        let existBKTree = self.getBKTree(modelContext: modelContext)
                        if existBKTree.isEmpty {
                            let json = self.phashBKtree.bkTree.toJSON()
                            if let jsonString = convertJSONToString(json){
                                let tempBKtree = BKtreePersistent(bktree: jsonString)
                                modelContext.insert(tempBKtree)
                            }
                        } else {
                            let json = self.phashBKtree.bkTree.toJSON()
                            if let jsonString = convertJSONToString(json){
                                existBKTree[0].bkTree = jsonString
                            }
                        }
                    }
                }
            }
        }
    }

    private func getFullSizeImage(asset: PHAsset, completion: @escaping (UIImage) -> Void) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.version = .original
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat

        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
            if let img = image {
                completion(img)
            }
        }
    }

    func calculatePHash(image: UIImage) -> String? {
        return SwiftImageHash.phash(image: image)
    }
    
    private func checkPhotoID(id: String, modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<PhotoInfo>(
            predicate: #Predicate { $0.localID == id }
        )
        
        var idEmptyFlag = true
        do {
            let existPhoto = try modelContext.fetch(descriptor)
            idEmptyFlag = existPhoto.isEmpty
        } catch {
            fatalError(error.localizedDescription)
        }
        
        return idEmptyFlag
    }
    
    private func checkPhash(phash: String, modelContext: ModelContext) -> [PhashMap] {
        let descriptor = FetchDescriptor<PhashMap>(
            predicate: #Predicate { $0.phash == phash }
        )
        
        do {
            let existPhash = try modelContext.fetch(descriptor)
            return existPhash
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    private func getBKTree(modelContext: ModelContext) -> [BKtreePersistent] {
        do {
            let existBKtree = try modelContext.fetch(FetchDescriptor<BKtreePersistent>())
            return existBKtree
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

func convertJSONToString(_ json: [String: Any]) -> String? {
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8)
        return jsonString
    } catch {
        print("Error converting dictionary to JSON string: \(error)")
        return nil
    }
}

func convertStringToJSON(_ jsonString: String) -> [String: Any]? {
    guard let jsonData = jsonString.data(using: .utf8) else {
        print("Error: Cannot convert string to data")
        return nil
    }

    do {
        if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            return json
        } else {
            print("Error: JSON is not a dictionary")
            return nil
        }
    } catch {
        print("Error converting string to JSON: \(error)")
        return nil
    }
}
