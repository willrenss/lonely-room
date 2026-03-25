import SwiftUI

// MARK: - Furniture Catalog Panel
struct FurnitureCatalogView: View {
    @ObservedObject var vm: KostViewModel
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sofa.fill").foregroundStyle(.orange)
                Text("Furnitur").bold().foregroundStyle(.primary)
                Spacer()
                if vm.pendingType != nil {
                    Button(action: { vm.pendingType = nil }) {
                        Label("Batal", systemImage: "xmark.circle")
                            .font(.caption).foregroundStyle(.red)
                    }
                    .padding(.trailing, 6)
                }
                Button(action: { onDismiss?() }) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Divider()

            // Catalog scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FurnitureType.allCases, id: \.self) { ft in
                        let isSelected = vm.pendingType == ft
                        Button(action: {
                            vm.startPlacing(type: ft)
                        }) {
                            VStack(spacing: 5) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ft.tileColor.opacity(isSelected ? 1.0 : 0.72))
                                        .frame(width: 54, height: 54)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isSelected ? Color.yellow : Color.clear,
                                                    lineWidth: 2.5
                                                )
                                        )
                                        .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
                                    Image(systemName: ft.icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white)
                                }
                                Text(ft.rawValue)
                                    .font(.caption2).bold()
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }

            // Selected furniture actions
            if let sel = vm.selectedFurniture {
                Divider()
                HStack(spacing: 14) {
                    Image(systemName: sel.type.icon).foregroundStyle(sel.type.tileColor)
                    Text(sel.type.rawValue).bold().foregroundStyle(.primary)
                    Spacer()
                    Button(action: { vm.rotateSelected(by: -.pi/4) }) {
                        Image(systemName: "rotate.left").font(.title3).foregroundStyle(.blue)
                    }
                    Button(action: { vm.rotateSelected(by: .pi/4) }) {
                        Image(systemName: "rotate.right").font(.title3).foregroundStyle(.blue)
                    }
                    Button(action: { vm.deleteSelected() }) {
                        Image(systemName: "trash").font(.title3).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Furniture Action Bubbles
struct FurnitureActionBubbles: View {
    @ObservedObject var vm: KostViewModel
    let selected: FurnitureItem
    var onRotateLeft:  () -> Void
    var onRotateRight: () -> Void
    var onDelete:      () -> Void
    var onStack:       () -> Void

    @State private var appeared = false

    private var canStack: Bool {
        // Can stack only if this item is not already stacked on another
        selected.stackedOnID == nil
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Item label
            HStack(spacing: 6) {
                Image(systemName: selected.type.icon).foregroundStyle(selected.type.tileColor)
                Text(selected.type.rawValue).font(.subheadline).bold().foregroundStyle(.white)
                if selected.stackedOnID != nil {
                    Image(systemName: "square.stack.fill")
                        .font(.caption).foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            .scaleEffect(appeared ? 1 : 0.6, anchor: .bottomTrailing)
            .opacity(appeared ? 1 : 0)

            // Action row: rotate + stack + delete
            HStack(spacing: 12) {
                BubbleButton(icon: "rotate.left",
                             color: Color(red: 0.25, green: 0.50, blue: 0.95),
                             action: onRotateLeft)
                    .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.04), value: appeared)

                BubbleButton(icon: "rotate.right",
                             color: Color(red: 0.25, green: 0.50, blue: 0.95),
                             action: onRotateRight)
                    .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.08), value: appeared)

                if canStack {
                    BubbleButton(icon: "square.stack.3d.up.fill",
                                 color: Color(red: 0.15, green: 0.62, blue: 0.38),
                                 action: onStack)
                        .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.12), value: appeared)
                }

                BubbleButton(icon: "trash",
                             color: Color(red: 0.88, green: 0.22, blue: 0.22),
                             action: onDelete)
                    .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.16), value: appeared)
            }

            // D-pad for moving selected furniture
            if selected.stackedOnID == nil {
                FurnitureDPad(vm: vm)
                    .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.20), value: appeared)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

// MARK: - Stack Mode Banner
struct StackModeBanner: View {
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundStyle(.yellow)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mode Tumpuk Aktif").bold().foregroundStyle(.white)
                Text("Tap furnitur yang lebih besar sebagai alas")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
    }
}

// MARK: - D-Pad for furniture movement
struct FurnitureDPad: View {
    @ObservedObject var vm: KostViewModel
    let step: Float = 0.08

    var body: some View {
        ZStack {
            // Background disc
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                .frame(width: 120, height: 120)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

            // Arrows
            VStack(spacing: 0) {
                DPadArrow(icon: "chevron.up") { vm.moveSelected(dx: 0, dz: -step) }
                HStack(spacing: 0) {
                    DPadArrow(icon: "chevron.left")  { vm.moveSelected(dx: -step, dz: 0) }
                    Spacer().frame(width: 28, height: 28)
                    DPadArrow(icon: "chevron.right") { vm.moveSelected(dx: step, dz: 0) }
                }
                DPadArrow(icon: "chevron.down") { vm.moveSelected(dx: 0, dz: step) }
            }
            .frame(width: 120, height: 120)
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
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .scaleEffect(pressed ? 0.8 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.06)) { pressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.25)) { pressed = false } }
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
                    .fill(color.opacity(pressed ? 0.95 : 0.82))
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                    .shadow(color: color.opacity(0.55), radius: pressed ? 4 : 10, x: 0, y: pressed ? 2 : 5)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(pressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.08)) { pressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3)) { pressed = false } }
        )
    }
}
