import PhotosUI
import SwiftUI

/// Выбор аватарки.
///
/// Сначала своё фото, потом набор. Порядок не случаен: человек, который
/// хочет поставить своё лицо, не должен сперва пролистывать чужие значки.
@MainActor
struct AvatarPicker: View {

    @Environment(\.dsMotion) private var motion

    let current: Avatar
    let accent: Color
    let onSelect: (Avatar) -> Void
    let onDismiss: () -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var isPickingPhoto = false
    @State private var dragOffset: CGFloat = 0

    private let columns = [GridItem(.adaptive(minimum: 62), spacing: DS.Space.sm)]

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(DS.Color.scrim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
                .transition(.opacity)
                .accessibilityLabel("Закрыть выбор аватарки")
                .accessibilityAddTraits(.isButton)

            panel
        }
        .ignoresSafeArea()
        .photosPicker(isPresented: $isPickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let id = PhotoStore.avatars.save(image) else { return }
                onSelect(.photo(id))
                photoItem = nil
            }
        }
    }

    private var panel: some View {
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            Text("Аватарка")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)

            PillButton("Выбрать своё фото", icon: "photo.on.rectangle",
                       kind: .tinted(accent), fullWidth: true) {
                isPickingPhoto = true
            }

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    SectionHeader("Место на карте",
                                  subtitle: "Страна в цвете своего флага")
                    LazyVGrid(columns: columns, spacing: DS.Space.sm) {
                        ForEach(0..<AvatarPlace.count, id: \.self) { index in
                            button(.place(index))
                        }
                    }

                    SectionHeader("Или картинка")
                    LazyVGrid(columns: columns, spacing: DS.Space.sm) {
                        ForEach(0..<AvatarScene.count, id: \.self) { index in
                            button(.scene(index))
                        }
                    }
                }
                .padding(.bottom, DS.Space.xs)
            }
            .frame(maxHeight: 360)
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.xl)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedTopShape(radius: DS.Radius.xl)
                .fill(motion.reduceTransparency
                      ? AnyShapeStyle(DS.Color.materialFallback)
                      : AnyShapeStyle(.ultraThinMaterial))
                .overlay {
                    UnevenRoundedTopShape(radius: DS.Radius.xl)
                        .fill(DS.Color.panel.opacity(motion.reduceTransparency ? 1 : 0.9))
                }
                .overlay {
                    UnevenRoundedTopShape(radius: DS.Radius.xl)
                        .stroke(DS.Gradient.glassBorder(0.8), lineWidth: 1)
                }
                .dsShadow(.high)
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: dragOffset)
        .gesture(dismissDrag)
        .transition(.move(edge: .bottom))
    }

    private func button(_ option: Avatar) -> some View {
        let isSelected = option == current

        return Button {
            Haptics.shared.selection()
            onSelect(option)
        } label: {
            AvatarView(avatar: option, size: 58)
                .overlay {
                    Circle().strokeBorder(isSelected ? accent : Color.clear, lineWidth: 2.5)
                }
                .padding(2)
        }
        .buttonStyle(.plain)
        .animation(motion.animation(.snap), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { dragOffset = max(0, $0.translation.height) }
            .onEnded { value in
                if value.translation.height > 90 || value.predictedEndTranslation.height > 220 {
                    onDismiss()
                }
                withAnimation(motion.animation(.snap)) { dragOffset = 0 }
            }
    }
}
