import Foundation

// MARK: - Save Data Model

struct FurnitureSaveData: Codable {
    let id:           String   // UUID karakter asli item
    let type:         String   // FurnitureType.rawValue
    let x:            Float
    let y:            Float
    let z:            Float
    let yaw:          Float
    let stackedOnID:  String?  // UUID item yang di-stack di bawahnya
    let stackedItemID: String? // UUID item yang di atas item ini
    var customImagePath: String? = nil
    var custom3DPath: String? = nil
}

// MARK: - Persistence Manager

enum FurniturePersistence {
    private static let key = "furniture_layout_v4"

    static func migrateIfNeeded() {
        // Hapus semua versi lama
        ["furniture_layout_v1",
         "furniture_layout_v2",
         "furniture_layout_v3"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }

    static func save(_ items: [FurnitureSaveData]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> [FurnitureSaveData]? {
        guard
            let data  = UserDefaults.standard.data(forKey: key),
            let items = try? JSONDecoder().decode([FurnitureSaveData].self, from: data),
            !items.isEmpty
        else { return nil }

        // Filter hanya item dengan type yang valid (ada di FurnitureType enum)
        let validTypes = Set(FurnitureType.allCases.map { $0.rawValue })
        let filtered = items.filter { validTypes.contains($0.type) }

        return filtered.isEmpty ? nil : filtered
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
