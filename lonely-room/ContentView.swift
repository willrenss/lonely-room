import SwiftUI
import SceneKit
import Combine
import AVFoundation

// MARK: - Splash View
struct SplashView: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Warna sama dengan launch screen supaya transisinya mulus.
            Color("LaunchBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "house.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                Text("Kost Simulator")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                ProgressView()
                    .tint(.white)
                    .padding(.top, 8)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}

// MARK: - Wardrobe Customizer View
struct WardrobeCustomizerView: View {
    @ObservedObject var vm: KostViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Lemari Pakaian")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            // Gender Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Gender").font(.caption).foregroundStyle(.white.opacity(0.7))
                Picker("Gender", selection: $vm.characterGender) {
                    Text("Laki-laki").tag("Male")
                    Text("Perempuan").tag("Perempuan")
                }
                .pickerStyle(.segmented)
                .colorScheme(.dark)
                .onChange(of: vm.characterGender) {
                    vm.rebuildCharacterAppearance()
                }
            }
            
            // Style Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Gaya Pakaian").font(.caption).foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 12) {
                    ForEach(0..<3) { i in
                        Button {
                            Haptics.select()
                            vm.characterStyleIndex = i
                            vm.rebuildCharacterAppearance()
                        } label: {
                            Circle()
                                .fill(styleColor(for: i))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().stroke(vm.characterStyleIndex == i ? Color.white : Color.clear, lineWidth: 3)
                                )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.hudFill, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 32)
    }
    
    func styleColor(for index: Int) -> Color {
        if vm.characterGender == "Perempuan" {
            switch index {
            case 0: return Color(red: 0.85, green: 0.35, blue: 0.45)
            case 1: return Color(red: 0.4, green: 0.2, blue: 0.6)
            default: return Color(red: 0.9, green: 0.8, blue: 0.2)
            }
        } else {
            switch index {
            case 0: return Color(red: 0.25, green: 0.45, blue: 0.80)
            case 1: return Color(red: 0.2, green: 0.6, blue: 0.3)
            default: return Color(red: 0.8, green: 0.2, blue: 0.2)
            }
        }
    }
}

// MARK: - Action Capsule
/// Tombol aksi kontekstual (pintu, jendela, kasur, dst). Dulu ditulis ulang 7x di ContentView.
private struct ActionCapsule: View {
    let icon: String
    let title: String
    var width: CGFloat = 130
    var iconTint: Color = .white
    var strokeTint: Color = Color.white.opacity(0.3)
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconTint)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: width, minHeight: 40)
            .padding(.horizontal, 6)
            .background(Color.hudFill, in: Capsule())
            .overlay(Capsule().stroke(strokeTint, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

// MARK: - Round HUD Button
private struct RoundHUDButton: View {
    let icon: String
    let label: String
    var size: CGFloat = 40
    var fill: AnyShapeStyle = AnyShapeStyle(Color.hudFill)
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var vm             = KostViewModel()
    @StateObject private var weatherService = WeatherService()
    @ObservedObject private var settings    = AppSettings.shared

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var camLastDragX: CGFloat = 0

    @State private var showCatalog      = false
    @State private var catalogWasOpen   = false
    @State private var showWardrobe     = false
    @State private var showFocusStart   = false
    @State private var showSettings     = false
    @State private var showOnboarding   = false
    @State private var splashTimedOut   = false
    @State private var photo: UIImage?
    @State private var flashOpacity: Double = 0

    private var showSplash: Bool {
        settings.hasOnboarded && weatherService.isLoading && !splashTimedOut
    }

    private var isBusy: Bool { vm.isLyingDown || vm.isSitting }

    var body: some View {
        ZStack {
            mainContent

            if showSplash {
                SplashView().transition(.opacity)
            }

            if showOnboarding {
                OnboardingView { useLocation in
                    settings.useLocationWeather = useLocation
                    settings.hasOnboarded = true
                    weatherService.fetch()
                    withAnimation(.easeInOut(duration: 0.4)) { showOnboarding = false }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: showSplash)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            AudioSessionManager.useAmbient()
            vm.onSelectionChanged = { item in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    if item != nil {
                        catalogWasOpen = showCatalog
                        showCatalog = false
                    } else {
                        showCatalog = catalogWasOpen
                    }
                }
            }
            if settings.hasOnboarded {
                weatherService.fetch()
            } else {
                showOnboarding = true
            }
            // Jangan tahan user di splash kalau jaringan lambat.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { splashTimedOut = true }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                weatherService.refreshIfStale()
                vm.focus.refresh()
                vm.startAmbientTicker()
            case .background:
                vm.releaseJoystick()
                vm.stopAmbientTicker()
                vm.saveFurniture()
            default:
                break
            }
        }
        .onChange(of: vm.isSitting) { _, sitting in
            // Berdiri = jeda sesi fokus, duduk lagi = lanjut.
            guard vm.focus.phase == .focus else { return }
            sitting ? vm.focus.resume() : vm.focus.pause()
        }
        .onReceive(weatherService.$condition.compactMap { $0 }) { w in
            vm.applyWeather(w)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(vm: vm, weather: weatherService) {
                showOnboarding = true
            }
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ZStack {
            // ── Scene ──
            KostSceneView(vm: vm)
                .ignoresSafeArea()

            // ── Weather Overlays ──
            if settings.graphicsQuality.showsRainOverlay && !reduceMotion {
                RainOverlayView(condition: vm.weather)
                    .ignoresSafeArea()
            }

            // ── Focus panel: tengah atas ──
            if vm.focus.isActive {
                VStack {
                    // FocusPanel mengobservasi timer sendiri → hitung mundur tidak me-render ulang ContentView.
                    FocusPanel(focus: vm.focus, isSitting: vm.isSitting)
                        .padding(.top, 14)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Action Bubbles + D-Pad: kanan bawah, di atas tombol + ──
            if let sel = vm.selectedFurniture, vm.pendingType == nil {
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 0) {
                        Spacer()
                        FurnitureActionBubbles(
                            vm: vm,
                            selected: sel,
                            onRotateLeft:  { vm.rotateSelected(by: -.pi/4) },
                            onRotateRight: { vm.rotateSelected(by:  .pi/4) },
                            onDelete: {
                                Haptics.warning()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    vm.deleteSelected()
                                }
                            },
                            onStack: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    vm.startStacking()
                                }
                            }
                        )
                        .padding(.trailing, 24)
                        .padding(.bottom, 110)   // di atas tombol + (58+32=90, lebih 20)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottomTrailing)))
            }

            // ── Stack Mode Banner: kanan tengah, compact ──
            if vm.pendingStackSource != nil {
                HStack(spacing: 0) {
                    Spacer()
                    StackModeBanner {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            vm.cancelStacking()
                        }
                    }
                    .padding(.trailing, 20)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // ── Catalog Panel: atas, di bawah HUD ──
            VStack(spacing: 0) {
                if showCatalog && vm.pendingType == nil && vm.selectedFurniture == nil {
                    FurnitureCatalogView(vm: vm, onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showCatalog = false
                            vm.pendingType = nil
                            vm.selectFurniture(nil)
                        }
                    })
                    .padding(.leading, 24)
                    .padding(.trailing, 8)
                    .padding(.top, 72)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }

            // ── Camera rotate: drag area di kanan layar ──
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .position(x: geo.size.width * 0.75, y: geo.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { v in
                                let curX = v.location.x
                                if camLastDragX != 0 {
                                    vm.rotateCamera(by: Float(curX - camLastDragX) * 0.007)
                                }
                                camLastDragX = curX
                            }
                            .onEnded { _ in camLastDragX = 0 }
                    )
            }
            .allowsHitTesting(vm.pendingType == nil && vm.selectedFurniture == nil && !showCatalog)

            // Top bar di atas area drag kamera supaya tombol foto/pengaturan bisa ditekan.
            topBar

            // ── Joystick (kiri bawah) + Tombol aksi (kanan bawah) ──
            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom) {
                    JoystickView(size: 130) { dx, dy in
                        vm.setJoystick(dx: Float(dx), dy: Float(dy))
                    } onEnd: {
                        vm.releaseJoystick()
                    }
                    .opacity(isBusy ? 0.35 : 1.0)
                    .allowsHitTesting(!isBusy)
                    .padding(.leading, 24)
                    .accessibilityLabel("Joystick gerak")

                    Spacer()

                    actionColumn
                        .padding(.trailing, 24)
                }
                .padding(.bottom, 32)
            }

            // ── Panel Saklar Lampu ──
            if vm.isNearSwitch && !vm.isLyingDown {
                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        Spacer()
                        LightSwitchPanel(vm: vm)
                            .padding(.trailing, 20)
                            .padding(.bottom, 192)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.isNearSwitch)
            }

            // ── Panel Musik — muncul saat dekat radio ──
            if vm.isNearMusicPlayer && !vm.isLyingDown {
                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        MusicPlayerPanel()
                            .padding(.leading, 20)
                            .padding(.bottom, 192)
                        Spacer()
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.isNearMusicPlayer)
            }

            // ── Wardrobe Panel Overlay ──
            if showWardrobe {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showWardrobe = false } }

                WardrobeCustomizerView(vm: vm) {
                    withAnimation { showWardrobe = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Focus start card ──
            if showFocusStart {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showFocusStart = false } }

                FocusStartCard { minutes in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showFocusStart = false
                        vm.focus.startFocus(minutes: minutes)
                    }
                    if settings.autoLofiOnFocus && !MusicPlayer.shared.isPlaying {
                        MusicPlayer.shared.play()
                    }
                } onCancel: {
                    withAnimation { showFocusStart = false }
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            // ── Photo flash + preview ──
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if let photo {
                PhotoPreviewView(image: photo) {
                    withAnimation(.easeOut(duration: 0.25)) { self.photo = nil }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    WeatherBadgeView(condition: vm.weather,
                                     error: weatherService.errorMessage,
                                     placeName: weatherService.placeName)
                        .allowsHitTesting(false)
                    if settings.showNeedsHUD && !vm.isEditMode {
                        NeedsHUDView(needs: vm.needs,
                                     hasPlant: vm.furnitureItems.contains { $0.type == .plant })
                            .transition(.opacity)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    ClockView()
                        .allowsHitTesting(false)
                    HStack(spacing: 8) {
                        RoundHUDButton(icon: "camera.fill", label: "Foto kamar") { takePhoto() }
                        RoundHUDButton(icon: "gearshape.fill", label: "Pengaturan") { showSettings = true }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            Spacer()
        }
    }

    // MARK: - Action Column
    @ViewBuilder
    private var actionColumn: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if vm.isNearWardrobe && !isBusy {
                ActionCapsule(icon: "tshirt.fill", title: "Ganti Baju") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showWardrobe = true }
                }
            }

            if vm.isNearDoor && !isBusy {
                ActionCapsule(icon: vm.isDoorOpen ? "door.left.hand.open" : "door.left.hand.closed",
                              title: vm.isDoorOpen ? "Tutup Pintu" : "Buka Pintu") {
                    vm.toggleDoor()
                }
            }

            if vm.isNearWindow && !isBusy {
                ActionCapsule(icon: vm.isWindowOpen ? "window.casement.closed" : "window.casement",
                              title: vm.isWindowOpen ? "Tutup Jendela" : "Buka Jendela") {
                    vm.toggleWindow()
                }
            }

            if vm.isNearLamp && !isBusy {
                ActionCapsule(icon: vm.isLampOn ? "lamp.floor.fill" : "lamp.floor",
                              title: vm.isLampOn ? "Matikan Lampu" : "Nyalakan Lampu",
                              iconTint: vm.isLampOn ? .yellow : .white,
                              strokeTint: vm.isLampOn ? Color.yellow.opacity(0.6) : Color.white.opacity(0.3)) {
                    vm.toggleLamp()
                }
            }

            if vm.isSitting && !vm.focus.isActive {
                ActionCapsule(icon: "timer", title: "Mulai Fokus",
                              iconTint: .orange, strokeTint: Color.orange.opacity(0.6)) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showFocusStart = true }
                }
            }

            if vm.isNearChair || vm.isSitting {
                ActionCapsule(icon: vm.isSitting ? "figure.stand" : "chair.lounge.fill",
                              title: vm.isSitting ? "Berdiri" : "Duduk", width: 110) {
                    if vm.isSitting { vm.standUpChair() } else { vm.sitDown() }
                }
            }

            if vm.isNearBed || vm.isLyingDown {
                ActionCapsule(icon: vm.isLyingDown ? "figure.stand" : "bed.double.fill",
                              title: vm.isLyingDown ? "Berdiri" : "Rebahan", width: 110) {
                    if vm.isLyingDown { vm.standUp() } else { vm.layDown() }
                }
            }

            if vm.isNearPlant || vm.isWatering {
                ActionCapsule(icon: vm.isWatering ? "drop.fill" : "drop",
                              title: vm.isWatering ? "Menyiram..." : "Siram Tanaman",
                              iconTint: vm.isWatering ? .cyan : .white,
                              strokeTint: vm.isWatering ? Color.cyan.opacity(0.6) : Color.white.opacity(0.3)) {
                    vm.waterPlant()
                }
                .disabled(vm.isWatering)
            }

            if !isBusy {
                HStack(spacing: 10) {
                    if vm.isEditMode {
                        RoundHUDButton(icon: showCatalog ? "xmark" : "plus",
                                       label: showCatalog ? "Tutup katalog" : "Tambah furnitur",
                                       size: 58) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showCatalog.toggle()
                                if !showCatalog {
                                    vm.pendingType = nil
                                    vm.selectFurniture(nil)
                                }
                            }
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                    RoundHUDButton(icon: vm.isEditMode ? "lock.open.fill" : "lock.fill",
                                   label: vm.isEditMode ? "Selesai edit" : "Mode edit",
                                   size: 58,
                                   fill: vm.isEditMode ? AnyShapeStyle(Color.orange.opacity(0.9))
                                                       : AnyShapeStyle(Color.hudFill)) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            vm.toggleEditMode()
                            if !vm.isEditMode {
                                showCatalog = false
                                vm.pendingType = nil
                                vm.selectFurniture(nil)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Photo
    private func takePhoto() {
        guard let shot = vm.captureRoomSnapshot() else { return }
        Haptics.thump()
        flashOpacity = 0.85
        withAnimation(.easeOut(duration: 0.45)) { flashOpacity = 0 }
        let composed = RoomPhoto.compose(shot)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.15)) {
            photo = composed
        }
    }
}

#Preview {
    ContentView()
}
