import Foundation

let path = "lonely-room/Views/FurnitureCatalogView.swift"
var c = try! String(contentsOfFile: path)

c = c.replacingOccurrences(of: "import SwiftUI", with: "import SwiftUI\nimport PhotosUI")

c = c.replacingOccurrences(of: "struct FurnitureCatalogView: View {\n    @ObservedObject var vm: KostViewModel\n    var onDismiss: (() -> Void)? = nil\n", with: "struct FurnitureCatalogView: View {\n    @ObservedObject var vm: KostViewModel\n    var onDismiss: (() -> Void)? = nil\n    var onOpenScanner: (() -> Void)? = nil\n\n    @State private var isShowingPhotoPicker = false\n")

c = c.replacingOccurrences(of: "                        FurnitureTile(ft: ft, vm: vm)", with: "                        FurnitureTile(ft: ft, vm: vm) {\n                            if ft == .customImage {\n                                isShowingPhotoPicker = true\n                            } else if ft == .custom3D {\n                                onOpenScanner?()\n                            } else {\n                                vm.startPlacing(type: ft)\n                            }\n                        }")

c = c.replacingOccurrences(of: "        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)\n    }", with: "        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)\n        .sheet(isPresented: $isShowingPhotoPicker) {\n            CustomPhotoPickerView { img in\n                isShowingPhotoPicker = false\n                guard let image = img else { return }\n                let filename = UUID().uuidString + \".jpg\"\n                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)\n                if let data = image.jpegData(compressionQuality: 0.8) {\n                    try? data.write(to: url)\n                    vm.startPlacing(type: .customImage, imagePath: filename)\n                }\n            }\n        }\n    }")

c = c.replacingOccurrences(of: "private struct FurnitureTile: View {\n    let ft: FurnitureType\n    @ObservedObject var vm: KostViewModel", with: "private struct FurnitureTile: View {\n    let ft: FurnitureType\n    @ObservedObject var vm: KostViewModel\n    let action: () -> Void")

c = c.replacingOccurrences(of: "            if !isOwned { vm.startPlacing(type: ft) }", with: "            if !isOwned { action() }")

try! c.write(toFile: path, atomically: true, encoding: .utf8)
