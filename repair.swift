import SwiftUI

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
