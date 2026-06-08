import SwiftUI
import UniformTypeIdentifiers

struct DashboardSectionDropDelegate: DropDelegate {
    let section: DashboardSection
    @Binding var sectionOrder: [DashboardSection]
    @Binding var draggedSection: DashboardSection?
    let onReorder: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggedSection,
              draggedSection != section,
              let fromIndex = sectionOrder.firstIndex(of: draggedSection),
              let toIndex = sectionOrder.firstIndex(of: section) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            sectionOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedSection = nil
        onReorder()
        return true
    }
}

struct ReorderableDashboardBubbleModifier: ViewModifier {
    let section: DashboardSection
    @Binding var draggedSection: DashboardSection?
    @Binding var sectionOrder: [DashboardSection]
    let onReorder: () -> Void

    func body(content: Content) -> some View {
        content
            .scaleEffect(draggedSection == section ? 1.02 : 1)
            .opacity(draggedSection == section ? 0.82 : 1)
            .shadow(
                color: draggedSection == section ? .white.opacity(0.18) : .clear,
                radius: draggedSection == section ? 10 : 0,
                y: draggedSection == section ? 4 : 0
            )
            .animation(.easeInOut(duration: 0.2), value: draggedSection)
            .onDrag {
                draggedSection = section
                return NSItemProvider(object: section.rawValue as NSString)
            }
            .onDrop(
                of: [.text],
                delegate: DashboardSectionDropDelegate(
                    section: section,
                    sectionOrder: $sectionOrder,
                    draggedSection: $draggedSection,
                    onReorder: onReorder
                )
            )
    }
}

extension View {
    func reorderableDashboardBubble(
        _ section: DashboardSection,
        draggedSection: Binding<DashboardSection?>,
        sectionOrder: Binding<[DashboardSection]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        modifier(
            ReorderableDashboardBubbleModifier(
                section: section,
                draggedSection: draggedSection,
                sectionOrder: sectionOrder,
                onReorder: onReorder
            )
        )
    }
}
