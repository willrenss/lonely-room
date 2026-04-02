import SwiftUI

struct AIGeneratorView: View {
    @ObservedObject var vm: KostViewModel
    var onDismiss: () -> Void

    @State private var prompt: String = ""
    @State private var isLoading: Bool = false
    @State private var progressPercent: Int = 0
    @State private var statusMessage: String = "Masukkan Deksripsi Barang"

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Buat AI 3D ✨").font(.headline).bold()
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.gray)
                }
            }

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView(value: Double(progressPercent), total: 100.0)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                    Text("\(progressPercent)%")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text(statusMessage).font(.subheadline).foregroundColor(.secondary)
                }
                .padding()
            } else {
                TextField("Cth: Kursi gaming warna merah", text: $prompt)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button("Generate!") {
                    generate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.isEmpty)
                
                Text(statusMessage).font(.caption).foregroundColor(.red)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .frame(width: 320)
        .shadow(radius: 10)
    }

    private func generate() {
        guard !prompt.isEmpty else { return }
        isLoading = true
        progressPercent = 0
        statusMessage = "Mengirim ke AI (Tripo3D)..."

        GenerativeAIService.shared.generate3DModel(from: prompt, progressHandler: { p in
            self.progressPercent = p
            self.statusMessage = "Merender model 3D ... \(p)%"
        }) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    self.isLoading = false
                    self.onDismiss()
                    
                    // Karena Apple SceneKit tidak bisa melihat file .glb secara otomatis, 
                    // kita akan memberikan alert jika file tersebut formatnya GLB
                    if url.pathExtension.lowercased() == "glb" {
                        print("File terunduh: \(url.path). SceneKit tidak mendukung format ini.")
                    }
                    
                    vm.startPlacing(type: .aiGenerated, path3D: url.lastPathComponent)
                case .failure(let error):
                    self.isLoading = false
                    self.statusMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
