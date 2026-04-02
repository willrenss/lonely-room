import SwiftUI
import PhotosUI

// MARK: - Furniture Catalog Panel
struct FurnitureCatalogView: View {
    @ObservedObject var vm: KostViewModel
    var onDismiss: (() -> Void)? = nil
    var onOpenScanner: (() -> Void)? = nil
    var onOpenAIGenerator: (() -> Void)? = nil

    @State private var isShowingPhotoPicker = false

    var body: some View {
        HStack(spacing: 0) {

            // ── Tile Row ──
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(FurnitureType.allCases, id: \.self) { ft in
                        FurnitureTile(ft: ft, vm: vm) {
                            if ft == .customImage {
                                isShowingPhotoPicker = true
                            } else if ft == .custom3D {
                                onOpenScanner?()
                            } else if ft == .aiGenerated {
                                onOpenAIGenerator?()
                            } else {
                                vm.startPlacing(type: ft)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .contentShape(Rectangle())

            // ── Close Button ──
            Divider()
                .frame(height: 32)
                .padding(.vertical, 8)

            Button(action: { onDismiss?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
        .sheet(isPresented: $isShowingPhotoPicker) {
            CustomPhotoPickerView { img in
                isShowingPhotoPicker = false
                guard let image = img else { return }
                let filename = UUID().uuidString + ".jpg"
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
                if let data = image.jpegData(compressionQuality: 0.8) {
                    try? data.write(to: url)
                    vm.startPlacing(type: .customImage, imagePath: filename)
                }
            }
        }
    }
}

// MARK: - Furniture Tile
private struct FurnitureTile: View {
    let ft: FurnitureType
    @ObservedObject var vm: KostViewModel
    let action: () -> Void

    private var isSelected: Bool { vm.pendingType == ft }
    /// Owned = sudah ada DAN tidak boleh multiple → tile disabled dengan checkmark
    private var isOwned: Bool    { !ft.allowsMultiple && vm.hasItem(ofType: ft) }

    var body: some View {
        Button {
            if !isOwned { action() }
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOwned
                          ? Color.gray.opacity(0.25)
                          : ft.tileColor.opacity(isSelected ? 1.0 : 0.75))
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
                    )

                Image(systemName: ft.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isOwned ? Color.secondary : Color.white)
                    .frame(width: 42, height: 42)

                if isOwned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.green)
                        .background(Color.white.clipShape(Circle()))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
        .disabled(isOwned)
    }
}

// MARK: - Furniture Action Bubbles (kanan bawah)
struct FurnitureActionBubbles: View {
    @ObservedObject var vm: KostViewModel
    let selected: FurnitureItem
    var onRotateLeft:  () -> Void
    var onRotateRight: () -> Void
    var onDelete:      () -> Void
    var onStack:       () -> Void

    @State private var appeared = false

    private var canStack: Bool { selected.stackedOnID == nil }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {

            // ── Label item ──
            HStack(spacing: 6) {
                Image(systemName: selected.type.icon)
                    .foregroundStyle(selected.type.tileColor)
                Text(selected.type.rawValue)
                    .font(.subheadline).bold()
                    .foregroundStyle(.white)
                if selected.stackedOnID != nil {
                    Image(systemName: "square.stack.fill")
                        .font(.caption).foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8, anchor: .trailing)

            // ── Action row: rotate · stack · delete ──
            HStack(spacing: 10) {
                BubbleButton(icon: "rotate.left",
                             color: Color(red: 0.25, green: 0.50, blue: 0.95),
                             action: onRotateLeft)
                BubbleButton(icon: "rotate.right",
                             color: Color(red: 0.25, green: 0.50, blue: 0.95),
                             action: onRotateRight)
                if canStack {
                    BubbleButton(icon: "square.stack.3d.up.fill",
                                 color: Color(red: 0.15, green: 0.62, blue: 0.38),
                                 action: onStack)
                }
                BubbleButton(icon: "trash",
                             color: Color(red: 0.88, green: 0.22, blue: 0.22),
                             action: onDelete)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.7, anchor: .trailing)
            .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.05), value: appeared)

            // ── D-Pad (hanya untuk item di lantai) ──
            if selected.stackedOnID == nil {
                FurnitureDPad(vm: vm)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.7, anchor: .trailing)
                    .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.10), value: appeared)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }
}

// MARK: - Stack Mode Banner
struct StackModeBanner: View {
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.yellow)

            Text("Tumpuk")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)

            Text("Tap\nalas")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.red.opacity(0.85), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.yellow.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 3)
        .frame(width: 60)
    }
}

// MARK: - D-Pad (geser furniture)
struct FurnitureDPad: View {
    @ObservedObject var vm: KostViewModel
    let step: Float = 0.08

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                .frame(width: 116, height: 116)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

            VStack(spacing: 0) {
                DPadArrow(icon: "chevron.up")   { vm.moveSelected(dx: 0,    dz: -step) }
                HStack(spacing: 0) {
                    DPadArrow(icon: "chevron.left")  { vm.moveSelected(dx: -step, dz: 0) }
                    Spacer().frame(width: 28, height: 28)
                    DPadArrow(icon: "chevron.right") { vm.moveSelected(dx:  step, dz: 0) }
                }
                DPadArrow(icon: "chevron.down") { vm.moveSelected(dx: 0,    dz:  step) }
            }
            .frame(width: 116, height: 116)
        }
    }
}

struct DPadArrow: View {
    let icon: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .scaleEffect(pressed ? 0.78 : 1.0)
                .animation(.easeInOut(duration: 0.08), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}

// MARK: - Bubble Button
struct BubbleButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.opacity(pressed ? 1.0 : 0.82))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                    .shadow(color: color.opacity(0.5), radius: pressed ? 3 : 9, x: 0, y: pressed ? 1 : 4)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(pressed ? 0.87 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}
