import SwiftUI
import RealityKit
import os

@available(iOS 17.0, *)
struct ObjectScannerView: View {
    var onCancel: () -> Void
    var onComplete: (URL) -> Void

    @State private var session: ObjectCaptureSession?
    @State private var isProcessing = false
    @State private var progress: Double = 0.0
    @State private var errorText: String?

    // Keep reference so it doesn't deallocate
    @State private var photogrammetrySession: PhotogrammetrySession?

    var body: some View {
        ZStack {
            if let session = session, !isProcessing {
                ObjectCaptureView(session: session)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Button {
                            session.cancel()
                            onCancel()
                        } label: {
                            Image(systemName: "xmark")
                                .padding()
                                .background(.ultraThinMaterial, in: Circle())
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)
                        .padding(.leading, 20)
                        Spacer()
                    }
                    Spacer()
                    
                    if session.state == .ready {
                        Button("Mulai Scan") {
                            let imagesFolder = getDocumentsDir().appendingPathComponent("Scans", isDirectory: true)
                            var config = ObjectCaptureSession.Configuration()
                            session.start(imagesDirectory: imagesFolder, configuration: config)
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.bottom, 40)
                    } else if session.state == .detecting {
                        Text("Arahkan kamera ke objek dan gerakkan pelan.")
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.bottom, 40)
                    } else if session.state == .capturing {
                        VStack(spacing: 20) {
                            Text("Pengambilan Gambar Aktif")
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            
                            Button("Selesai & Buat 3D") {
                                session.finish()
                                Task { await processModel() }
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.bottom, 40)
                    } else if session.state == .finishing {
                        ProgressView("Menyimpan Pindai...")
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.bottom, 40)
                    }
                }
            } else if isProcessing {
                VStack(spacing: 20) {
                    Image(systemName: "cube.transparent.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                    Text("Membuat Model 3D AI...")
                        .font(.headline)
                    ProgressView(value: progress)
                        .frame(width: 200)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                    Text("Proses ini bisa memakan waktu hingga 5 Menit.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if errorText != nil {
                 VStack(spacing: 20) {
                     Text("Error: \(errorText!)").foregroundColor(.red)
                     Button("Kembali") { onCancel() }
                         .buttonStyle(.borderedProminent)
                 }
                 .padding()
            } else {
                VStack(spacing: 20) {
                    Text("Perangkat Kamu Tidak Mendukung 3D Scanner (Butuh iPhone dengan LiDAR / A14+)")
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Kembali") { onCancel() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            setupSession()
        }
    }
    
    private func getDocumentsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func setupSession() {
        if ObjectCaptureSession.isSupported {
            let imagesFolder = getDocumentsDir().appendingPathComponent("Scans", isDirectory: true)
            try? FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
            
            // Clean up old scans
            try? FileManager.default.removeItem(at: imagesFolder)
            try? FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
            
            var config = ObjectCaptureSession.Configuration()
            config.checkpointDirectory = imagesFolder
            let newSession = ObjectCaptureSession()
            // we skip checkpoint config for simplicity: newSession.start(...)
            self.session = newSession
        }
    }
    
    private func processModel() async {
        isProcessing = true
        let imagesFolder = session!.configuration.checkpointDirectory ?? getDocumentsDir().appendingPathComponent("Scans")
        let outputUSDZ = getDocumentsDir().appendingPathComponent("CustomScan-\(UUID().uuidString).usdz")
        
        do {
            photogrammetrySession = try PhotogrammetrySession(
                input: imagesFolder,
                configuration: PhotogrammetrySession.Configuration()
            )
            
            try photogrammetrySession!.process(requests: [
                PhotogrammetrySession.Request.modelFile(url: outputUSDZ, detail: .reduced)
            ])
            
            for try await result in photogrammetrySession!.outputs {
                switch result {
                case .processingComplete:
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.onComplete(outputUSDZ)
                    }
                case .requestError(_, let error):
                    DispatchQueue.main.async {
                        self.errorText = error.localizedDescription
                        self.isProcessing = false
                    }
                case .requestProgress(_, let frac):
                    DispatchQueue.main.async {
                        self.progress = frac
                    }
                default:
                    break
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorText = error.localizedDescription
                self.isProcessing = false
            }
        }
    }
}
