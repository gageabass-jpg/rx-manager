import SwiftUI

/// An expanding "gooey" search control. Collapsed it's a compact pill; tapping
/// springs it open into a full search field while the magnifier detaches into a
/// bubble on the left. The merge/stretch is a metaball effect: two blobs drawn
/// into a Canvas with a blur + alpha-threshold filter (the native equivalent of
/// the SVG feGaussianBlur + feColorMatrix "goo" filter).
struct GooeyInput: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var expandedPlaceholder: String = "Type to search…"
    var autoOpen: Bool = false
    var onOpenChange: ((Bool) -> Void)? = nil

    @State private var p: CGFloat = 0        // 0 = collapsed, 1 = expanded
    @State private var expanded = false
    @FocusState private var focused: Bool

    private let height: CGFloat = 46
    private let collapsedW: CGFloat = 150
    private let gap: CGFloat = 12
    private let blur: CGFloat = 7

    private let surface = RxTheme.ink
    private let onSurface = Color.white

    var body: some View {
        GeometryReader { geo in
            let g = layout(width: geo.size.width)

            ZStack(alignment: .topLeading) {
                // Gooey surface — the two blobs merged through blur + threshold.
                Canvas { ctx, _ in
                    ctx.addFilter(.alphaThreshold(min: 0.45, color: surface))
                    ctx.addFilter(.blur(radius: blur))
                    ctx.drawLayer { layer in
                        layer.fill(Capsule().path(in: g.bar), with: .color(.black))
                        layer.fill(Circle().path(in: g.circle), with: .color(.black))
                    }
                }
                .allowsHitTesting(false)

                // Magnifier — rides the circle from pill-left to the detached bubble.
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(onSurface)
                    .frame(width: g.circle.width, height: g.circle.height)
                    .position(x: g.circle.midX, y: g.circle.midY)
                    .allowsHitTesting(false)

                // Collapsed label.
                Text(placeholder)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(onSurface.opacity(0.9))
                    .lineLimit(1)
                    .frame(width: max(0, g.bar.width - height), alignment: .leading)
                    .position(x: g.bar.minX + height / 2 + (g.bar.width - height) / 2,
                              y: g.bar.midY)
                    .opacity(Double(max(0, 1 - p * 2)))
                    .allowsHitTesting(false)

                // Expanded field.
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(expandedPlaceholder)
                            .foregroundStyle(onSurface.opacity(0.5))
                    }
                    TextField("", text: $text)
                        .focused($focused)
                        .foregroundStyle(onSurface)
                        .tint(onSurface)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                }
                .font(.system(size: 15))
                .overlay(alignment: .trailing) {
                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(onSurface.opacity(0.55))
                        }
                    }
                }
                .padding(.leading, 18)
                .padding(.trailing, 14)
                .frame(width: g.bar.width, height: g.bar.height)
                .position(x: g.bar.midX, y: g.bar.midY)
                .opacity(Double(max(0, (p - 0.5) * 2)))
                .allowsHitTesting(expanded)

                // Collapsed tap target.
                if !expanded {
                    Button(action: open) { Color.clear.contentShape(Capsule()) }
                        .frame(width: collapsedW, height: height)
                        .position(x: geo.size.width / 2, y: height / 2)
                }
            }
            .frame(width: geo.size.width, height: height)
        }
        .frame(height: height)
        .onChange(of: focused) { _, isFocused in
            if !isFocused && text.isEmpty { close() }
        }
        .onAppear {
            if autoOpen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { open() }
            }
        }
    }

    // MARK: Interaction

    private func open() {
        guard !expanded else { return }
        expanded = true
        onOpenChange?(true)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { p = 1 }
        focused = true
    }

    private func close() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { p = 0 }
        expanded = false
        onOpenChange?(false)
    }

    // MARK: Geometry

    /// Interpolated circle + bar rects for the current progress `p`.
    private func layout(width W: CGFloat) -> (circle: CGRect, bar: CGRect) {
        let exCircle = CGRect(x: 0, y: 0, width: height, height: height)
        let exBar = CGRect(x: height + gap, y: 0,
                           width: max(0, W - height - gap), height: height)

        let colX = (W - collapsedW) / 2
        let colBar = CGRect(x: colX, y: 0, width: collapsedW, height: height)
        let colCircle = CGRect(x: colX, y: 0, width: height, height: height)

        return (lerp(colCircle, exCircle, p), lerp(colBar, exBar, p))
    }

    private func lerp(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(x: a.minX + (b.minX - a.minX) * t,
               y: a.minY + (b.minY - a.minY) * t,
               width: a.width + (b.width - a.width) * t,
               height: a.height + (b.height - a.height) * t)
    }
}
