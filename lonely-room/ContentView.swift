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
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "house.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.primary)
                Text("Kost Simulator")
                    .font(.title.bold())
                ProgressView()
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
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

// MARK: - Content View
struct ContentView: View {
    @StateObject private var vm             = KostViewModel()
    @StateObject private var weatherService = WeatherService()

    @State private var moveDX: CGFloat   = 0
    @State private var moveDY: CGFloat   = 0
    @State private var camLastDragX: CGFloat = 0

    @State private var showCatalog      = false
    @State private var catalogWasOpen   = false
    @State private var showWardrobe     = false
    @State private var showScanner      = false

    @State private var currentTime = Date()
    @State private var lastTODHour = Calendar.current.component(.hour, from: Date())
    @State var job: Timer?
//    func startJob() {
//        job = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
//            print("Run job every 5 minutes")
//            weatherService.fetch()
//        }
//    }

    

    private let timer      = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    private let clockTimer = Timer.publish(every: 1,    on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if weatherService.isLoading {
                SplashView()
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: weatherService.isLoading)
        .onAppear {
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
            weatherService.fetch()
            lastTODHour = Calendar.current.component(.hour, from: Date())
        }
        .onReceive(timer) { _ in
            if abs(moveDX) > 0.02 || abs(moveDY) > 0.02 {
                vm.move(dx: Float(moveDX), dy: Float(moveDY))
            }
        }
        .onReceive(clockTimer) { date in
            currentTime = date
            let hour = Calendar.current.component(.hour, from: date)
            if hour != lastTODHour {
                lastTODHour = hour
                vm.applyTimeOfDay()
            }
        }
        .onReceive(weatherService.$condition.compactMap { $0 }) { w in
            vm.applyWeather(w)
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ZStack {
            // ── Scene ──
            KostSceneView(vm: vm)
                .ignoresSafeArea()

            // ── HUD: Weather (kiri atas) & Jam (kanan atas) ──
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    WeatherBadgeView(condition: vm.weather, error: weatherService.errorMessage)
                    Spacer()
                    ClockView(date: currentTime)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                Spacer()
            }
            .allowsHitTesting(false)

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
                .allowsHitTesting(true)
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
                .allowsHitTesting(true)
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
                    }, onOpenScanner: {
                        showCatalog = false
                        showScanner = true
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
                                    let delta = Float(curX - camLastDragX)
                                    vm.rotateCamera(by: delta * 0.007)
                                }
                                camLastDragX = curX
                            }
                            .onEnded { _ in camLastDragX = 0 }
                    )
            }
            .allowsHitTesting(vm.pendingType == nil && vm.selectedFurniture == nil && !showCatalog)

            // ── Joystick (kiri bawah) + Tombol + (kanan bawah) ──
            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom) {
                    // Joystick
                    ZStack {
                        JoystickView(size: 130) { dx, dy in
                            moveDX = dx; moveDY = dy
                        } onEnd: {
                            moveDX = 0; moveDY = 0
                            vm.stopWalking()
                        }
                        .opacity(vm.isLyingDown || vm.isSitting ? 0.35 : 1.0)
                        .allowsHitTesting(!vm.isLyingDown && !vm.isSitting)
                    }
                    .padding(.leading, 24)

                    Spacer()

                    VStack(spacing: 10) {
                        // Tombol Buka Lemari / Customizer
                        if vm.isNearWardrobe && !vm.isLyingDown && !vm.isSitting {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    showWardrobe = true
                                }
                            } label: {
                                ZStack {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                                        .frame(width: 130, height: 40)
                                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                    HStack(spacing: 6) {
                                        Image(systemName: "tshirt.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text("Ganti Baju")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        // Tombol Pintu
                        if vm.isNearDoor && !vm.isLyingDown && !vm.isSitting {
                            Button {
                                vm.toggleDoor()
                            } label: {
                                ZStack {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                                        .frame(width: 130, height: 40)
                                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                    HStack(spacing: 6) {
                                        Image(systemName: vm.isDoorOpen ? "door.left.hand.open" : "door.left.hand.closed")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(vm.isDoorOpen ? "Tutup Pintu" : "Buka Pintu")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        // Tombol Jendela
                        if vm.isNearWindow && !vm.isLyingDown && !vm.isSitting {
                            Button {
                                vm.toggleWindow()
                            } label: {
                                ZStack {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                                        .frame(width: 130, height: 40)
                                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                    HStack(spacing: 6) {
                                        Image(systemName: vm.isWindowOpen ? "window.casement.closed" : "window.casement")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(vm.isWindowOpen ? "Tutup Jendela" : "Buka Jendela")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        // Tombol Lampu Tiang (on/off saja)
                        if vm.isNearLamp && !vm.isLyingDown && !vm.isSitting {
                            Button {
                                vm.toggleLamp()
                            } label: {
                                ZStack {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(
                                            vm.isLampOn ? Color.yellow.opacity(0.6) : Color.white.opacity(0.3),
                                            lineWidth: 1.5))
                                        .frame(width: 130, height: 40)
                                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                    HStack(spacing: 6) {
                                        Image(systemName: vm.isLampOn ? "lamp.floor.fill" : "lamp.floor")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(vm.isLampOn ? Color.yellow : Color.white)
                                        Text(vm.isLampOn ? "Matikan Lampu" : "Nyalakan Lampu")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        // Tombol Duduk / Berdiri (kursi)
                        if vm.isNearChair || vm.isSitting {
                            Button {
                                if vm.isSitting { vm.standUpChair() } else { vm.sitDown() }
                            } label: {
                                ZStack {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                                        .frame(width: 110, height: 40)
                                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                    HStack(spacing: 6) {
                                        Image(systemName: vm.isSitting ? "figure.stand" : "chair.lounge.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(vm.isSitting ? "Berdiri" : "Duduk")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        // Tombol Rebahan / Berdiri
                        if vm.isNearBed || vm.isLyingDown {
                            Button {
                                if vm.isLyingDown {
                                    vm.standUp()
                                } else {
                                    vm.layDown()
                                }
                            } label: {
                                ZStack {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                                        .frame(width: 110, height: 40)
                                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                    HStack(spacing: 6) {
                                        Image(systemName: vm.isLyingDown ? "figure.stand" : "bed.double.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(vm.isLyingDown ? "Berdiri" : "Rebahan")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        // Tombol Siram Tanaman
                        if vm.isNearPlant || vm.isWatering {
                            Button {
                                vm.waterPlant()
                            } label: {
                                ZStack {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(
                                            vm.isWatering ? Color.cyan.opacity(0.6) : Color.white.opacity(0.3),
                                            lineWidth: 1.5))
                                        .frame(width: 130, height: 40)
                                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                    HStack(spacing: 6) {
                                        Image(systemName: vm.isWatering ? "drop.fill" : "drop")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(vm.isWatering ? Color.cyan : Color.white)
                                        Text(vm.isWatering ? "Menyiram..." : "Siram Tanaman")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.isWatering)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        if !vm.isLyingDown && !vm.isSitting {
                            // Tombol Edit Mode
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    vm.toggleEditMode()
                                    if !vm.isEditMode {
                                        showCatalog = false
                                        vm.pendingType = nil
                                        vm.selectFurniture(nil)
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(vm.isEditMode ? AnyShapeStyle(Color.orange.opacity(0.9)) : AnyShapeStyle(.ultraThinMaterial))
                                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                                        .frame(width: 58, height: 58)
                                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                    Image(systemName: vm.isEditMode ? "lock.open.fill" : "lock.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)

                            // Tombol buka/tutup catalog
                            if vm.isEditMode {
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        showCatalog.toggle()
                                        if !showCatalog {
                                            vm.pendingType = nil
                                            vm.selectFurniture(nil)
                                        }
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                                            .frame(width: 58, height: 58)
                                            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                        Image(systemName: showCatalog ? "xmark" : "plus")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .rotationEffect(.degrees(showCatalog ? 0 : 0))
                                    }
                                }
                                .buttonStyle(.plain)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                            }
                        }
                    }
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
                .allowsHitTesting(true)
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
                .allowsHitTesting(true)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.isNearMusicPlayer)
            }
            
            // ── Wardrobe Panel Overlay ──
            if showWardrobe {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showWardrobe = false }
                    }
                
                WardrobeCustomizerView(vm: vm) {
                    withAnimation { showWardrobe = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            if #available(iOS 17.0, *) {
                ObjectScannerView {
                    showScanner = false
                } onComplete: { outputUSDZPath in
                    showScanner = false
                    // Start placing item. Ensure filename is used.
                    vm.startPlacing(type: .custom3D, path3D: outputUSDZPath.lastPathComponent)
                }
            } else {
                Text("Fitur Scanner 3D Membutuhkan iOS 17 ke atas.")
            }
        }
    }
}

#Preview {
    ContentView()
}
