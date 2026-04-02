import Foundation

/// Service to handle Text-to-3D or Image-to-3D generation using an external AI API (e.g., Meshy, Luma, Tripo3D).
class GenerativeAIService {
    static let shared = GenerativeAIService()
    
    // ⚠️ MASUKKAN API KEY KAMU DI SINI
    // 1. Daftar dan dapatkan API Key dari salah satu layanan ini:
    //    - Meshy AI (Rekomendasi Utama): https://app.meshy.ai/api
    //    - Tripo 3D: https://platform.tripo3d.ai/
    //    - Luma AI: https://lumalabs.ai/luma-api
    // 2. Salin kodenya dan ganti tulisan di bawah ini:
    private let apiKey = "tsk_GcTZVS_yRzEB7k_HNw48lVTwjkK9TzFaYzZB5YAWFvL"
    
    private init() {}
    
    /// Fungsi untuk meminta Grok / ChatGPT (LLM) menebak barang mana yang cocok dengan deskripsi pemain
    func mapPromptToExistingFurniture(prompt: String, grokAPIKey: String, completion: @escaping (Result<FurnitureType, Error>) -> Void) {
        print("Bertanya pada Grok/LLM untuk mencocokkan prompt: '\(prompt)'")
        
        let apiUrl = URL(string: "https://api.x.ai/v1/chat/completions")! // Ganti ke api.openai.com jika pakai ChatGPT
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(grokAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let validItems = FurnitureType.allCases
            .filter { $0 != .customImage && $0 != .custom3D && $0 != .aiGenerated }
            .map { $0.rawValue }
            .joined(separator: ", ")
            
        let systemPrompt = """
        Kamu adalah sistem AI pintar dalam game Kost Simulator.
        Tugasmu hanya satu: Mencocokkan benda yang diketik pemain dengan SATU barang yang paling relevan dari daftar furnitur yang tersedia.
        Daftar barang yang tersedia: [\(validItems)].
        
        Jika pemain mengatakan: "Aku ingin tempat untuk merebahkan tubuh", kamu membalas: "Kasur".
        Jika ada yang tidak masuk akal, respon dengan barang yang fungsinya mirip (misal laptop = "Meja" atau "Radio").
        HANYA jawab dengan SATU kata/frase yang ada di dalam daftar. DILARANG keras menambahkan spasi/titik/penjelasan apapun.
        """
        
        let body: [String: Any] = [
            "model": "grok-beta", // atau gpt-3.5-turbo (jika OpenAI)
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    let aiAnswer = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("Grok/LLM Memilih Barang: \(aiAnswer)")
                    
                    // Cocokkan string balasan AI dengan enum FurnitureType kita
                    if let matchedType = FurnitureType.allCases.first(where: { $0.rawValue.lowercased() == aiAnswer.lowercased() }) {
                        DispatchQueue.main.async { completion(.success(matchedType)) }
                    } else {
                        let err = NSError(domain: "LLM", code: 404, userInfo: [NSLocalizedDescriptionKey: "AI Gagal menebak barang yang tepat. Balasannya: \(aiAnswer)"])
                        DispatchQueue.main.async { completion(.failure(err)) }
                    }
                    
                } else {
                    let err = NSError(domain: "LLM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Respons LLM tidak sesuai: \(String(data: data, encoding: .utf8) ?? "")"])
                    DispatchQueue.main.async { completion(.failure(err)) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    /// Fungsi untuk meminta AI membuatkan model 3D berdasarkan teks deskripsi (Prompt)
    func generate3DModel(from prompt: String, progressHandler: @escaping (Int) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        print("Mulai membuat model dari Tripo3D dengan prompt: '\(prompt)'")
        
        let apiUrl = URL(string: "https://api.tripo3d.ai/v2/openapi/task")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "type": "text_to_model",
            "prompt": prompt
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // 1. Buat Task di Tripo
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let dataDict = json["data"] as? [String: Any], let taskId = dataDict["task_id"] as? String {
                        self.pollTripoTask(taskId: taskId, progressHandler: progressHandler, completion: completion)
                    } else if let msg = json["message"] as? String {
                        let err = NSError(domain: "TripoAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tripo Error: \(msg)"])
                        DispatchQueue.main.async { completion(.failure(err)) }
                    } else {
                        let err = NSError(domain: "TripoAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gagal membuat antrean di Tripo."])
                        DispatchQueue.main.async { completion(.failure(err)) }
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    private func pollTripoTask(taskId: String, progressHandler: @escaping (Int) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        let apiUrl = URL(string: "https://api.tripo3d.ai/v2/openapi/task/\(taskId)")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any],
                   let status = dataDict["status"] as? String {
                   
                    if let p = dataDict["progress"] as? Int {
                        // Limit progress 0-80 for text_to_model
                        DispatchQueue.main.async { progressHandler(Int(Double(p) * 0.8)) }
                    }
                   
                    if status == "success" {
                        self.convertTripoTaskToUSDZ(originalTaskId: taskId, progressHandler: progressHandler, completion: completion)
                    } else if status == "failed" {
                        let err = NSError(domain: "TripoAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tripo gagal membuat model GLB."])
                        DispatchQueue.main.async { completion(.failure(err)) }
                    } else {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 4.0) {
                            self.pollTripoTask(taskId: taskId, progressHandler: progressHandler, completion: completion)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private func convertTripoTaskToUSDZ(originalTaskId: String, progressHandler: @escaping (Int) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        print("Teks ke Model GLB sukses! Meminta Tripo mengonversi ke format iOS (USDZ)...")
        DispatchQueue.main.async { progressHandler(85) }
        
        let apiUrl = URL(string: "https://api.tripo3d.ai/v2/openapi/task")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "type": "convert_model",
            "format": "USDZ",
            "original_model_task_id": originalTaskId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any], let convertId = dataDict["task_id"] as? String {
                    self.pollTripoConvertTask(convertId: convertId, progressHandler: progressHandler, completion: completion)
                } else {
                    let err = NSError(domain: "TripoAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gagal meminta konversi USDZ."])
                    DispatchQueue.main.async { completion(.failure(err)) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private func pollTripoConvertTask(convertId: String, progressHandler: @escaping (Int) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        let apiUrl = URL(string: "https://api.tripo3d.ai/v2/openapi/task/\(convertId)")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any],
                   let status = dataDict["status"] as? String {
                   
                    if let _ = dataDict["progress"] as? Int {
                        DispatchQueue.main.async { progressHandler(90) }
                    }
                   
                    if status == "success" {
                       DispatchQueue.main.async { progressHandler(100) }
                       if let result = dataDict["result"] as? [String: Any],
                          let modelInfo = result["model"] as? [String: Any],
                          let urlStr = modelInfo["url"] as? String,
                          let modelUrl = URL(string: urlStr) {
                           print("Link USDZ berhasi didapat! Mengunduh...")
                           self.downloadFile(from: modelUrl, completion: completion)
                       } else {
                           let err = NSError(domain: "TripoAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Format USDZ tidak ditemukan di server."])
                           DispatchQueue.main.async { completion(.failure(err)) }
                       }
                    } else if status == "failed" {
                        let err = NSError(domain: "TripoAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Konversi USDZ gagal."])
                        DispatchQueue.main.async { completion(.failure(err)) }
                    } else {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                            self.pollTripoConvertTask(convertId: convertId, progressHandler: progressHandler, completion: completion)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    private func downloadFile(from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
            guard let localURL = localURL else { return }
            
            do {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                // Tripo umumnya mengembalikan format file .glb atau .usdz
                let expectedExtension = url.pathExtension.isEmpty ? "glb" : url.pathExtension
                let savedURL = documentsURL.appendingPathComponent("Tripo-\(UUID().uuidString).\(expectedExtension)")
                
                try FileManager.default.moveItem(at: localURL, to: savedURL)
                
                DispatchQueue.main.async {
                    completion(.success(savedURL))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        task.resume()
    }
}
