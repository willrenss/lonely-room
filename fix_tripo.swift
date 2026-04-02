import Foundation
let p = "lonely-room/Models/GenerativeAIService.swift"
var c = try! String(contentsOfFile: p)

c = c.replacingOccurrences(of: "private let apiKey = \"TARUH_API_KEY_MESHY_KAMU_DISINI\"", with: "private let apiKey = \"tsk_Ur4Lqo_N3gdYpg8nuVtcfzZJYbnj-yw5cPZzI-5yTnS\"")

c = c.replacingOccurrences(of: """
    /// Fungsi untuk meminta AI membuatkan model 3D berdasarkan teks deskripsi (Prompt)
    func generate3DModel(from prompt: String, progressHandler: @escaping (Int) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        print("Mulai membuat model dari Meshy AI dengan prompt: '\\(prompt)'")
        
        let apiUrl = URL(string: "https://api.meshy.ai/v2/text-to-3d")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \\(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Meshy AI parameters
        let body: [String: Any] = [
            "mode": "preview", // Mode proxy untuk render cepat (~30 detik)
            "prompt": prompt,
            "art_style": "realistic",
            "should_remesh": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // 1. Buat Task di Meshy
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
            guard let data = data else { return }
            
            if let responseStr = String(data: data, encoding: .utf8) {
                print("Respons awal Meshy: \\(responseStr)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Cek ID antrean
                    if let taskId = json["result"] as? String {
                        // 2. Jika sukses mendapatkan ID, mulai memantau (polling)
                        self.pollMeshyTask(taskId: taskId, progressHandler: progressHandler, completion: completion)
                    }
                    else if let message = json["message"] as? String {
                        let err = NSError(domain: "MeshyAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Meshy Membalas: \\(message)"])
                        DispatchQueue.main.async { completion(.failure(err)) }
                    } else {
                        let err = NSError(domain: "MeshyAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gagal membuat antrean di Meshy."])
                        DispatchQueue.main.async { completion(.failure(err)) }
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    private func pollMeshyTask(taskId: String, progressHandler: @escaping (Int) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        let apiUrl = URL(string: "https://api.meshy.ai/v2/text-to-3d/\\(taskId)")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "GET"
        request.setValue("Bearer \\(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 3. Cek Status pengerjaan AI
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                   
                    if let p = json["progress"] as? Int {
                        DispatchQueue.main.async { progressHandler(p) }
                    }
                   
                    if status == "SUCCEEDED" {
                       // Meshy otomatis memberikan file khusus Apple .usdz!
                       if let modelUrls = json["model_urls"] as? [String: Any],
                          let usdzUrlString = modelUrls["usdz"] as? String,
                          let modelUrl = URL(string: usdzUrlString) {
                           
                           print("Berhasil menemukan link usdz model: \\(usdzUrlString)")
                           // 4. Bila selesai, unduh file USDZ-nya!
                           self.downloadFile(from: modelUrl, completion: completion)
                           
                       } else {
                           let err = NSError(domain: "MeshyAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gagal menemukan URL USDZ."])
                           DispatchQueue.main.async { completion(.failure(err)) }
                       }
                        
                    } else if status == "FAILED" {
                        let err = NSError(domain: "MeshyAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Meshy gagal membuat model."])
                        DispatchQueue.main.async { completion(.failure(err)) }
                    } else {
                        // Bila belum selesai (IN_PROGRESS / PENDING), ulangi cek tiap 4 detik
                        DispatchQueue.global().asyncAfter(deadline: .now() + 4.0) {
                            self.pollMeshyTask(taskId: taskId, progressHandler: progressHandler, completion: completion)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }""", with: """
    /// Fungsi untuk meminta AI membuatkan model 3D berdasarkan teks deskripsi (Prompt)
    func generate3DModel(from prompt: String, progressHandler: @escaping (Int) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        print("Mulai membuat model dari Tripo3D dengan prompt: '\\(prompt)'")
        
        let apiUrl = URL(string: "https://api.tripo3d.ai/v2/openapi/task")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \\(apiKey)", forHTTPHeaderField: "Authorization")
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
        let apiUrl = URL(string: "https://api.tripo3d.ai/v2/openapi/task/\\(taskId)")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "GET"
        request.setValue("Bearer \\(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any],
                   let status = dataDict["status"] as? String {
                   
                    if let p = dataDict["progress"] as? Int {
                        // Limit progress shown from 0 to 80% to reserve 20% for conversion
                        DispatchQueue.main.async { progressHandler(Int(Double(p) * 0.8)) }
                    }
                   
                    if status == "success" {
                        self.convertTripoTaskToUSDZ(originalTaskId: taskId, progressHandler: progressHandler, completion: completion)
                    } else if status == "failed" {
                        let err = NSError(domain: "TripoAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tripo gagal membuat model."])
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
        print("Teks ke Model sukses! Meminta Tripo melakukan konversi ke USDZ (Format iOS)...")
        let apiUrl = URL(string: "https://api.tripo3d.ai/v2/openapi/task")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \\(apiKey)", forHTTPHeaderField: "Authorization")
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
        let apiUrl = URL(string: "https://api.tripo3d.ai/v2/openapi/task/\\(convertId)")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "GET"
        request.setValue("Bearer \\(apiKey)", forHTTPHeaderField: "Authorization")
        
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
                       } else if let output = dataDict["output"] as? [String: Any],
                                 let urlStr = output["model"] as? String,
                                 let modelUrl = URL(string: urlStr) {
                           self.downloadFile(from: modelUrl, completion: completion)
                       }
                    } else if status == "failed" {
                        let err = NSError(domain: "TripoAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Konversi ke format iOS (USDZ) gagal."])
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
    }""")

try! c.write(toFile: p, atomically: true, encoding: .utf8)
