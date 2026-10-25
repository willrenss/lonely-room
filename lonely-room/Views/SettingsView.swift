import SwiftUI
import CoreLocation

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    let vm: KostViewModel
    let weather: WeatherService
    var onReplayTutorial: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmResetLayout = false
    @State private var confirmResetStats  = false

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    sliderRow("Musik radio", icon: "music.note", value: $settings.musicVolume)
                    sliderRow("Efek suara", icon: "speaker.wave.2.fill", value: $settings.sfxVolume)
                }

                Section {
                    Picker(selection: $settings.graphicsQuality) {
                        ForEach(GraphicsQuality.allCases) { q in Text(q.label).tag(q) }
                    } label: {
                        Label("Kualitas grafis", systemImage: "sparkles.tv")
                    }
                    .pickerStyle(.segmented)
                    Toggle(isOn: $settings.hapticsEnabled) {
                        Label("Getaran (haptic)", systemImage: "iphone.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Grafis & umpan balik")
                } footer: {
                    Text(settings.graphicsQuality.detail)
                }

                Section("Fokus (Pomodoro)") {
                    Stepper(value: $settings.focusMinutes, in: 5...90, step: 5) {
                        Label("Durasi fokus: \(settings.focusMinutes) menit", systemImage: "timer")
                    }
                    Stepper(value: $settings.breakMinutes, in: 1...30) {
                        Label("Istirahat: \(settings.breakMinutes) menit", systemImage: "cup.and.saucer.fill")
                    }
                    Toggle(isOn: $settings.autoLofiOnFocus) {
                        Label("Putar lofi saat fokus", systemImage: "radio.fill")
                    }
                }

                Section {
                    Toggle(isOn: $settings.showNeedsHUD) {
                        Label("Tampilkan status energi & mood", systemImage: "heart.text.square.fill")
                    }
                    Toggle(isOn: Binding(
                        get: { settings.useLocationWeather },
                        set: { on in
                            settings.useLocationWeather = on
                            weather.fetch()
                        })) {
                        Label("Cuaca sesuai lokasi", systemImage: "location.fill")
                    }
                } header: {
                    Text("Tampilan & cuaca")
                } footer: {
                    Text(settings.useLocationWeather
                         ? "Lokasi perkiraan dipakai hanya untuk mengambil cuaca dan tidak disimpan."
                         : "Saat mati, cuaca memakai lokasi default (Tangerang Selatan).")
                }

                Section("Kamar") {
                    Button {
                        onReplayTutorial()
                        dismiss()
                    } label: {
                        Label("Lihat tutorial lagi", systemImage: "questionmark.circle")
                    }
                    Button(role: .destructive) {
                        confirmResetLayout = true
                    } label: {
                        Label("Reset tata letak kamar", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive) {
                        confirmResetStats = true
                    } label: {
                        Label("Reset statistik & streak", systemImage: "chart.bar.xaxis")
                    }
                }

                Section("Tentang") {
                    LabeledContent("Versi", value: appVersion)
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Kebijakan privasi", systemImage: "hand.raised.fill")
                    }
                    NavigationLink {
                        CreditsView()
                    } label: {
                        Label("Kredit musik & data", systemImage: "music.quarternote.3")
                    }
                }
            }
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") { dismiss() }
                }
            }
            .confirmationDialog("Reset tata letak kamar ke awal?", isPresented: $confirmResetLayout, titleVisibility: .visible) {
                Button("Reset Kamar", role: .destructive) {
                    vm.resetLayout()
                    Haptics.warning()
                    dismiss()
                }
            } message: {
                Text("Semua furnitur yang sudah kamu tata akan kembali ke susunan default.")
            }
            .confirmationDialog("Reset statistik?", isPresented: $confirmResetStats, titleVisibility: .visible) {
                Button("Reset Statistik", role: .destructive) {
                    vm.needs.resetAll()
                    Haptics.warning()
                }
            } message: {
                Text("Energi, mood, tanaman, streak, dan total menit fokus akan diulang dari awal.")
            }
        }
    }

    private func sliderRow(_ title: String, icon: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...1)
        }
    }
}

// MARK: - Privacy Policy
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Kebijakan Privasi").font(.title2.bold())
                Text("Kost Simulator tidak mengumpulkan, menyimpan di server, atau menjual data pribadi apa pun. Tidak ada akun, iklan, maupun pelacakan.")
                Group {
                    Text("Lokasi").font(.headline)
                    Text("Jika kamu mengaktifkan \"Cuaca sesuai lokasi\", lokasi perkiraan perangkat dipakai sekali-sekali untuk meminta data cuaca ke Open-Meteo (api.open-meteo.com). Koordinat dibulatkan dan tidak disimpan oleh aplikasi.")
                    Text("Foto").font(.headline)
                    Text("Foto kamar dibuat di perangkat. Aplikasi hanya meminta izin menambah foto ke galeri saat kamu memilih untuk menyimpannya.")
                    Text("Notifikasi").font(.headline)
                    Text("Notifikasi lokal dipakai untuk memberi tahu saat sesi fokus atau istirahat selesai. Tidak ada push notification dari server.")
                    Text("Data di perangkat").font(.headline)
                    Text("Tata letak kamar, pengaturan, dan statistik disimpan secara lokal di perangkat dan terhapus bila aplikasi dihapus.")
                }
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .navigationTitle("Privasi")
    }
}

// MARK: - Credits
struct CreditsView: View {
    var body: some View {
        List {
            Section("Musik radio") {
                Text("Lofi Study — FASSounds")
                Text("One Step Closer — jumadiharyanto07")
                Text("Quiet Peaks — pasajdijital")
                Text("Deep Breathing — TopFlow")
                Text("Lofi Chill — watermello")
                Text("Musik dari Pixabay, digunakan sesuai Pixabay Content License.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Data cuaca") {
                Link("Weather data by Open-Meteo.com (CC BY 4.0)",
                     destination: URL(string: "https://open-meteo.com/")!)
            }
        }
        .navigationTitle("Kredit")
    }
}
