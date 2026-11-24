import SwiftUI

// MARK: - Собственные замены системных меню/алертов/тостов Apple

struct MenuAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    var destructive: Bool = false
    let action: () -> Void
}

struct DialogButton: Identifiable {
    let id = UUID()
    let title: String
    var destructive: Bool = false
    var cancel: Bool = false
    let action: () -> Void
}

/// Общий держатель собственного меню «долгое нажатие» — монтируется один раз у корня приложения,
/// чтобы перекрывать весь экран (меню сообщений лежит глубоко внутри списков/ScrollView).
final class MenuPresenter: ObservableObject {
    static let shared = MenuPresenter()
    @Published var isPresented = false
    @Published var reactions: [String] = []
    @Published var onReact: ((String) -> Void)? = nil
    @Published var actions: [MenuAction] = []

    func show(reactions: [String] = [], onReact: ((String) -> Void)? = nil, actions: [MenuAction]) {
        guard !reactions.isEmpty || !actions.isEmpty else { return }
        self.reactions = reactions
        self.onReact = onReact
        self.actions = actions
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { isPresented = true }
    }
}

/// Долгое нажатие вместо системного .contextMenu — своя карточка снизу экрана.
/// Монтируется один раз в корне приложения и показывает то, что положил MenuPresenter.shared.
struct ActionMenuOverlay: View {
    @ObservedObject var presenter = MenuPresenter.shared

    private var isPresented: Bool { presenter.isPresented }
    private var reactions: [String] { presenter.reactions }
    private var onReact: ((String) -> Void)? { presenter.onReact }
    private var actions: [MenuAction] { presenter.actions }

    private func close() { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { presenter.isPresented = false } }

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                VStack {
                    Spacer()
                    VStack(spacing: 0) {
                        if !reactions.isEmpty {
                            HStack(spacing: 14) {
                                ForEach(reactions, id: \.self) { e in
                                    Button {
                                        onReact?(e)
                                        close()
                                    } label: {
                                        Text(e).font(.system(size: 26))
                                    }
                                    if e != reactions.last { Spacer() }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            Rectangle().fill(Theme.stroke).frame(height: 1)
                        }
                        ForEach(actions) { a in
                            Button {
                                close()
                                a.action()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: a.icon)
                                        .foregroundColor(a.destructive ? Color(hex: 0xFF6B6B) : Theme.accent)
                                        .frame(width: 22)
                                    Text(a.title)
                                        .font(.system(size: 15))
                                        .foregroundColor(a.destructive ? Color(hex: 0xFF6B6B) : Theme.text)
                                    Spacer()
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            if a.id != actions.last?.id {
                                Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 54)
                            }
                        }
                    }
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.stroke, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .zIndex(2000)
    }
}

/// Диалог подтверждения вместо системного .confirmationDialog / .alert
struct ConfirmDialogOverlay: View {
    @Binding var isPresented: Bool
    let title: String
    var message: String? = nil
    let buttons: [DialogButton]

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .transition(.opacity)
                VStack(spacing: 14) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.text).multilineTextAlignment(.center)
                    if let m = message {
                        Text(m).font(.system(size: 12)).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
                    }
                    VStack(spacing: 10) {
                        ForEach(buttons) { b in
                            Button {
                                isPresented = false
                                b.action()
                            } label: {
                                Text(b.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(b.destructive ? Color(hex: 0xFF6B6B) : (b.cancel ? Theme.textSecondary : .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(b.cancel ? AnyShapeStyle(Theme.card) : (b.destructive ? AnyShapeStyle(Color(hex: 0xFF6B6B, opacity: 0.15)) : AnyShapeStyle(Theme.accentGradient)))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: (b.cancel || b.destructive) ? 1 : 0))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
                .padding(18)
                .background(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.stroke, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, 36)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .zIndex(2000)
    }
}

/// Ввод текста вместо системного .alert с TextField
struct PromptDialogOverlay: View {
    @Binding var isPresented: Bool
    let title: String
    var message: String? = nil
    let placeholder: String
    @Binding var text: String
    let confirmTitle: String
    let onConfirm: () -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false; onCancel?() }
                    .transition(.opacity)
                VStack(spacing: 14) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.text).multilineTextAlignment(.center)
                    if let m = message {
                        Text(m).font(.system(size: 12)).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
                    }
                    GlassField(placeholder: placeholder, text: $text)
                    HStack(spacing: 10) {
                        Button {
                            isPresented = false
                            onCancel?()
                        } label: {
                            Text(tr("Отмена", "Cancel", "Abbrechen"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.card)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        Button {
                            isPresented = false
                            onConfirm()
                        } label: {
                            Text(confirmTitle)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.accentGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(18)
                .background(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.stroke, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, 30)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .zIndex(2000)
    }
}

/// Тост сверху экрана вместо системного .alert с одной кнопкой «ОК»
struct ToastOverlay: View {
    @Binding var text: String?
    var body: some View {
        VStack {
            if let t = text {
                Text(t)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 8)
                    .onTapGesture { text = nil }
                    .task(id: t) {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        if !Task.isCancelled { text = nil }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: text)
        .allowsHitTesting(text != nil)
        .zIndex(3000)
    }
}

extension View {
    /// Долгое нажатие открывает собственное меню снизу (вместо системного .contextMenu).
    /// Само меню рисуется один раз в корне приложения через ActionMenuOverlay + MenuPresenter.shared.
    func customActionMenu(reactions: [String] = [], onReact: ((String) -> Void)? = nil, actions: [MenuAction]) -> some View {
        // simultaneousGesture, а не .onLongPressGesture — чтобы не перехватывать тап у Button/NavigationLink,
        // на которых это меню тоже навешено (список чатов и т.п.)
        self.simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                MenuPresenter.shared.show(reactions: reactions, onReact: onReact, actions: actions)
            }
        )
    }
}
