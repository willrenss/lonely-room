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
                        let alreadyPlaced = vm.furnitureItems.contains(where: { $0.type == ft })
                        let isSelected = vm.selectedFurniture?.type == ft
                        Button(action: {
                            if alreadyPlaced {
                                if let existing = vm.furnitureItems.first(where: { $0.type == ft }) {
                                    vm.selectFurniture(existing)
                                }
                            } else {
                                vm.startPlacing(type: ft)
                            }
                        }) {
                            VStack(spacing: 5) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ft.tileColor.opacity(
                                            alreadyPlaced ? (isSelected ? 1.0 : 0.55) :
                                            (vm.pendingType == ft ? 1.0 : 0.72)
                                        ))
                                        .frame(width: 54, height: 54)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isSelected ? Color.yellow :
                                                    (vm.pendingType == ft ? Color.yellow : Color.clear),
                                                    lineWidth: 2.5
                                                )
                                        )
                                        .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
                                    Image(systemName: ft.icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white.opacity(alreadyPlaced ? 0.65 : 1.0))
                                }
                                .overlay(alignment: .topTrailing) {
                                    if alreadyPlaced {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                            .background(Circle().fill(ft.tileColor).padding(-1))
                                            .offset(x: 6, y: -6)
                                    }
                                }
                                Text(ft.rawValue)
                                    .font(.caption2).bold()
                                    .foregroundStyle(alreadyPlaced ? .secondary : .primary)
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
    let selected: FurnitureItem
    var onRotateLeft:  () -> Void
    var onRotateRight: () -> Void
    var onDelete:      () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: selected.type.icon).foregroundStyle(selected.type.tileColor)
                Text(selected.type.rawValue).font(.subheadline).bold().foregroundStyle(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            .scaleEffect(appeared ? 1 : 0.6, anchor: .bottomTrailing)
            .opacity(appeared ? 1 : 0)

            HStack(spacing: 14) {
                BubbleButton(icon: "rotate.left",
                             color: Color(red: 0.25, green: 0.50, blue: 0.95),
                             action: onRotateLeft)
                    .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.05), value: appeared)

                BubbleButton(icon: "rotate.right",
                             color: Color(red: 0.25, green: 0.50, blue: 0.95),
                             action: onRotateRight)
                    .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.10), value: appeared)

                BubbleButton(icon: "trash",
                             color: Color(red: 0.88, green: 0.22, blue: 0.22),
                             action: onDelete)
                    .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.15), value: appeared)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true }
        }
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
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                    .shadow(color: color.opacity(0.55), radius: pressed ? 4 : 10, x: 0, y: pressed ? 2 : 5)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(pressed ? 0.90 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.08)) { pressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3)) { pressed = false } }
        )
    }
}
