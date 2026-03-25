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
                Text("Lonely Room")
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

// MARK: - Content View
struct ContentView: View {
    @StateObject private var vm             = KostViewModel()
    @StateObject private var weatherService = WeatherService()

    @State private var moveDX: CGFloat   = 0
    @State private var moveDY: CGFloat   = 0
    @State private var rotateDX: CGFloat = 0

    @State private var showCatalog    = false
    @State private var catalogWasOpen = false

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
            if abs(rotateDX) > 0.001 {
                vm.rotateCamera(by: Float(rotateDX))
                rotateDX = 0
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
            KostSceneView(vm: vm)
                .ignoresSafeArea()
                .onTapGesture { }

            // Hands — fullscreen so GeometryReader gets full dimensions
            HandView(isWalking: vm.isWalking)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    JoystickView(size: 130) { dx, dy in
                        moveDX = dx; moveDY = dy
                    } onEnd: {
                        moveDX = 0; moveDY = 0
                        vm.stopWalking()
                    }
                    .padding(.leading, 24)
                    .padding(.bottom, 32)

                    Spacer()

                    VStack(spacing: 16) {
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
                                Image(systemName: showCatalog ? "xmark" : "plus")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 32)
                }
            }

            // Furniture catalog overlay
            VStack {
                Spacer()
                if showCatalog && vm.pendingType == nil && vm.selectedFurniture == nil {
                    FurnitureCatalogView(vm: vm, onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showCatalog = false
                            vm.pendingType = nil
                            vm.selectFurniture(nil)
                        }
                    })
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if let sel = vm.selectedFurniture, vm.pendingType == nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FurnitureActionBubbles(
                            selected: sel,
                            onRotateLeft:  { vm.rotateSelected(by: -.pi/4) },
                            onRotateRight: { vm.rotateSelected(by:  .pi/4) },
                            onDelete: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    vm.deleteSelected()
                                }
                            }
                        )
                        .padding(.trailing, 24)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(true)
            }

            VStack {
                HStack(alignment: .top) {
                    WeatherBadgeView(condition: vm.weather, error: weatherService.errorMessage)
                        .padding(.top, 16).padding(.leading, 20)
                    Spacer()
                    ClockView(date: currentTime)
                        .padding(.top, 16).padding(.trailing, 20)
                }
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    ContentView()
}
