func dirLabel(_ t) -> String {
  if t.directory == nil || t.directory == "" { return "" }
  if t.directory.contains("/.claude/worktrees/") {
    let parts = t.directory.split(separator: "/")
    return String(parts.last)
  }
  let parts = t.directory.split(separator: "/")
  if parts.count == 0 { return t.directory }
  return String(parts.last)
}

func isWorktreeTab(_ t) -> Bool {
  if t.directory == nil || t.directory == "" { return false }
  let d = t.directory
  return d.contains("/.claude/worktrees/")
}

func branchLabel(_ t) -> String {
  if t.branch == nil { return "" }
  if t.branch == "" { return "" }
  return t.branch
}

func sessionTitle(_ t) -> String {
  if t.title.hasPrefix("✳ ") { return String(t.title.dropFirst(2)) }
  if t.title.hasPrefix("⠂ ") { return String(t.title.dropFirst(2)) }
  return t.title
}

func worktreeCount(_ w) -> Int {
  return w.tabs.filter { isWorktreeTab($0) }.count
}

func needsInput(_ w) -> Bool {
  if w.color == nil { return false }
  return w.color == "#FF3B30"
}

func dirName(_ t) -> String {
  if t.directory == nil || t.directory == "" { return "" }
  let parts = t.directory.split(separator: "/")
  if parts.count == 0 { return "" }
  return String(parts.last)
}

func hasUnpushed(_ w, _ t) -> Bool {
  if w.description == nil { return false }
  if !w.description.hasPrefix("⇡") { return false }
  let n = dirName(t)
  if n == "" { return false }
  return w.description.contains("[\(n)]")
}

func hasDirty(_ w, _ t) -> Bool {
  if w.description == nil { return false }
  if !w.description.hasPrefix("⇡") { return false }
  let n = dirName(t)
  if n == "" { return false }
  return w.description.contains("(\(n))")
}

func repoName(_ t) -> String {
  if t.directory == nil || t.directory == "" { return "" }
  let d = t.directory
  if !d.contains("/.claude/worktrees/") { return "" }
  let parts = d.split(separator: "/")
  if parts.count < 4 { return "" }
  return String(parts[parts.count - 4])
}

func placeLabel(_ t) -> String {
  if isWorktreeTab(t) {
    let r = repoName(t)
    let n = dirName(t)
    if r != "" { return "\(r) › \(n)" }
    return n
  }
  return dirLabel(t)
}

VStack(alignment: .leading, spacing: 6) {
  HStack(spacing: 6) {
    Image(systemName: "arrow.triangle.branch").foregroundColor(.accent)
    Text("Worktree Map").font(.title3).bold()
    Spacer()
    Text("\(workspaceCount)").font(.caption).monospacedDigit().foregroundColor(.secondary)
  }
  Divider()

  ForEach(workspaces) { w in
    VStack(alignment: .leading, spacing: 3) {
      Button(action: { cmux("workspace.select", workspace_id: w.id) }) {
        HStack(spacing: 6) {
          Circle()
            .fill(needsInput(w) ? "#FF3B30" : (w.selected ? "#0A84FF" : (worktreeCount(w) > 0 ? "#34C759" : "#8E8E93")))
            .frame(width: 8, height: 8)
          Text("Tab \(w.index + 1)")
            .font(.system(size: 13))
            .fontWeight(w.selected ? .semibold : .regular)
            .foregroundColor(w.selected ? .primary : .secondary)
          Spacer()
          if needsInput(w) {
            HStack(spacing: 3) {
              Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 9))
                .foregroundColor(.white)
              Text("needs input")
                .font(.system(size: 10))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            }
            .padding(4)
            .background { Capsule().foregroundColor("#FF3B30") }
          }
          if w.unread > 0 {
            HStack(spacing: 3) {
              Image(systemName: "bell.fill")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
              Text("\(w.unread)")
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            }
            .padding(4)
            .background { Capsule().foregroundColor("#8E8E93").opacity(0.25) }
          }
        }
        .padding(5)
        .background {
          RoundedRectangle(cornerRadius: 6)
            .foregroundColor(w.selected ? "#0A84FF" : "#000000")
            .opacity(w.selected ? 0.18 : 0.0)
        }
      }

      ForEach(w.tabs) { t in
        Button(action: {
          cmux("workspace.select", workspace_id: w.id)
          cmux("surface.focus", surface_id: t.id)
        }) {
          HStack(alignment: .top, spacing: 6) {
            if isWorktreeTab(t) {
              Text("🌱")
                .font(.system(size: 12))
                .frame(width: 16)
            } else {
              Image(systemName: "terminal")
                .font(.system(size: 10))
                .foregroundColor(.tertiary)
                .frame(width: 16)
            }
            VStack(alignment: .leading, spacing: 2) {
              HStack(alignment: .top, spacing: 4) {
                Text(placeLabel(t))
                  .font(.system(size: 14))
                  .fontWeight(isWorktreeTab(t) ? .semibold : .regular)
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)
                if hasDirty(w, t) {
                  Circle().fill("#FF9F0A").frame(width: 6, height: 6)
                }
                if hasUnpushed(w, t) {
                  Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor("#0A84FF")
                }
              }
              Text(sessionTitle(t))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
              if branchLabel(t) != "" {
                Text(branchLabel(t))
                  .font(.system(size: 11, design: .monospaced))
                  .foregroundColor(.tertiary)
                  .lineLimit(2)
              }
            }
            Spacer()
          }
          .padding(5)
          .padding(.leading, 10)
          .background {
            RoundedRectangle(cornerRadius: 6)
              .foregroundColor(t.focused && w.selected ? "#0A84FF" : "#000000")
              .opacity(t.focused && w.selected ? 0.10 : 0.0)
          }
        }
      }
    }
  }
  Spacer()
}
