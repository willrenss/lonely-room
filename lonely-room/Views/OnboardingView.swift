import SwiftUI

// MARK: - Onboarding
/// Tutorial singkat saat pertama buka. Halaman terakhir meminta izin lokasi
/// dengan penjelasan dulu (bukan langsung pop-up sistem saat app dibuka).
struct OnboardingView: View {
    /// `true` bila user memilih cuaca sesuai lokasi.
    var onFinish: (_ useLocation: Bool) -> Void

    @State private var page = 0

    private struct Page {
        let icon: String
        let tint: Color
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(icon: "house.fill", tint: .orange,
             title: "Selamat datang di Kost Simulator",
             body: "Kamar kost kecil milikmu sendiri. Santai, dekorasi sesukamu, dan temani waktu belajarmu."),
        Page(icon: "gamecontroller.fill", tint: .blue,
             title: "Jalan-jalan",
             body: "Geser joystick di kiri bawah untuk berjalan. Geser di sisi kanan layar untuk memutar kamera."),
        Page(icon: "hand.tap.fill", tint: .purple,
             title: "Interaksi",
             body: "Dekati kasur, kursi, jendela, pintu, radio, atau tanaman — tombol aksi muncul di kanan bawah. Ketuk kucing atau anjing untuk bermain."),
        Page(icon: "lock.open.fill", tint: .yellow,
             title: "Dekorasi kamar",
             body: "Tekan tombol gembok untuk mode edit. Tambah furnitur dengan +, geser dengan jari, putar, atau tumpuk barang."),
        Page(icon: "timer", tint: .red,
             title: "Fokus & mood",
             body: "Duduk di kursi untuk memulai sesi Pomodoro. Jaga energi, mood, dan tanamanmu tetap sehat setiap hari."),
    ]

    private var isLastPage: Bool { page == pages.count }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i]).tag(i)
                    }
                    locationPage.tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxWidth: 620, maxHeight: 260)

                HStack(spacing: 12) {
                    if isLastPage {
                        Button("Pakai lokasi default") { finish(useLocation: false) }
                            .buttonStyle(SecondaryPillStyle())
                        Button("Izinkan lokasi") { finish(useLocation: true) }
                            .buttonStyle(PrimaryPillStyle())
                    } else {
                        Button("Lewati") { withAnimation { page = pages.count } }
                            .buttonStyle(SecondaryPillStyle())
                        Button("Lanjut") {
                            Haptics.select()
                            withAnimation { page += 1 }
                        }
                        .buttonStyle(PrimaryPillStyle())
                    }
                }
            }
            .padding(24)
            .background(Color.hudFill, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
        }
    }

    private func pageView(_ p: Page) -> some View {
        HStack(spacing: 28) {
            Image(systemName: p.icon)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(p.tint)
                .frame(width: 120, height: 120)
                .background(p.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 30))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                Text(p.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(p.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 30)
    }

    private var locationPage: some View {
        pageView(Page(icon: "cloud.sun.rain.fill", tint: .cyan,
                      title: "Cuaca asli di luar jendela",
                      body: "Izinkan lokasi supaya hujan, cerah, atau mendung di luar jendela sama dengan kotamu. Lokasi tidak disimpan. Bisa diubah kapan saja di Pengaturan."))
    }

    private func finish(useLocation: Bool) {
        Haptics.success()
        onFinish(useLocation)
    }
}

// MARK: - Button Styles
struct PrimaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 26).padding(.vertical, 12)
            .background(Color.orange, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct SecondaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(Color.white.opacity(0.15), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
