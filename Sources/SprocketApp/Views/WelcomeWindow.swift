import SwiftUI
import SprocketKit

struct WelcomeWindow: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)
            ScrollView {
                Group {
                    if state.pendingUserCode != nil {
                        DeviceFlowProgress()
                    } else {
                        switch state.welcomeStep {
                        case 1: WelcomeStep1()
                        case 2: WelcomeStep2()
                        default: WelcomeStep3()
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 22)
            }
            Divider().opacity(0.6)
            footer
        }
        .background(.regularMaterial)
        .onChange(of: state.isAuthed) { _, authed in
            if authed { closeWelcomeWindow() }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(.primary.opacity(0.06))
                SprocketMark(size: 14, color: .primary)
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("Welcome to Sprocket").font(.system(size: 12.5, weight: .semibold))
                Text("Step \(state.welcomeStep) of 3").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { n in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(n <= state.welcomeStep ? Color.sprocketAccent : Color.primary.opacity(0.10))
                        .frame(width: 18, height: 3)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack {
            Button(state.welcomeStep == 1 ? "Quit" : "Back") {
                if state.pendingUserCode != nil { return }
                if state.welcomeStep == 1 { NSApp.terminate(nil) }
                else { state.welcomeStep -= 1 }
            }
            .buttonStyle(.bordered)
            .disabled(state.pendingUserCode != nil)

            Spacer()

            HStack(spacing: 8) {
                if state.welcomeStep != 3 && state.pendingUserCode == nil {
                    Button("Skip") { dismiss() }
                        .buttonStyle(.bordered)
                }
                Button(continueLabel) {
                    if state.pendingUserCode != nil { return }
                    if state.welcomeStep < 3 {
                        state.welcomeStep += 1
                    } else {
                        Task {
                            await state.signIn(clientID: state.clientIDDraft)
                            if state.isAuthed {
                                closeWelcomeWindow()
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.sprocketAccent)
                .disabled(disableContinue)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.02))
    }

    private var continueLabel: String {
        if state.pendingUserCode != nil { return "Waiting for GitHub…" }
        if state.isSigningIn { return "Signing in…" }
        return state.welcomeStep == 3 ? "Continue & sign in" : "Continue"
    }

    private var disableContinue: Bool {
        if state.pendingUserCode != nil || state.isSigningIn { return true }
        if state.welcomeStep == 3 {
            let s = state.clientIDDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            return !isPlausibleClientID(s)
        }
        return false
    }

    private func closeWelcomeWindow() {
        dismiss()
        NSApp.windows
            .first { $0.title == "Welcome" }
            .map { $0.close() }
    }
}

/// GitHub Client IDs:
/// - Legacy OAuth Apps: `Iv1.<16-hex>` (contains a dot)
/// - GitHub Apps:        `Iv23li…`     (no dot)
/// - New OAuth Apps:     `Ov23li…`     (no dot)
func isPlausibleClientID(_ s: String) -> Bool {
    (s.hasPrefix("Iv") || s.hasPrefix("Ov")) && s.count >= 12
}

private struct WelcomeStep1: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You'll create your own GitHub OAuth app.")
                .font(.system(size: 22, weight: .semibold))
                .kerning(-0.4)
                .lineLimit(nil)
            Text("Sprocket talks to GitHub on your behalf to monitor workflow runs and show this month's Actions minutes. You'll register your own OAuth app so the token is issued directly to this Mac and never leaves it.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                BulletCard(icon: "lock", title: "Token in Keychain",
                           detail:"Stored in macOS Keychain, never on disk in plaintext.")
                BulletCard(icon: "globe", title: "Direct to GitHub",
                           detail:"No third-party server. Polling only — no analytics.")
                BulletCard(icon: "clock.badge.checkmark", title: "CI minutes",
                           detail:"Shows monthly Actions usage against your included budget.")
                BulletCard(icon: "gearshape", title: "One-time setup",
                           detail:"Reused across sign-outs. Reconfigure anytime.")
            }
            .padding(.top, 6)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.sprocketAccent)
                Text("Sprocket will request `repo`, `workflow`, `read:org`, and `user`.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
            .padding(.top, 8)
        }
    }
}

private struct BulletCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.secondary)
                Text(title).font(.system(size: 11.5, weight: .semibold))
            }
            Text(detail).font(.system(size: 11)).foregroundStyle(.tertiary).lineSpacing(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
    }
}

private struct WelcomeStep2: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Register the app on GitHub")
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.2)
            Text("We'll open a pre-filled registration page. Follow these five steps:")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    StepLine("1.", "The form is pre-filled — leave defaults or rename it.")
                    StepLine("2.", "Scroll down and tick **\"Enable Device Flow\"**.")
                        .foregroundStyle(.primary)
                    StepLine("3.", "Click **\"Register application\"**.")
                    StepLine("4.", "Copy the **Client ID** (no secret needed).")
                    StepLine("5.", "Come back to Sprocket.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                DeviceFlowCheckboxIllustration()
                    .frame(width: 160)
            }
            .padding(.top, 4)

            HStack(spacing: 8) {
                Button {
                    openURL(Self.registrationURL)
                } label: {
                    Label("Open GitHub to create app", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.sprocketAccent)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Self.registrationURL.absoluteString, forType: .string)
                } label: {
                    Label("Copy registration URL", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 6)
        }
    }

    private static let registrationURL: URL = {
        var c = URLComponents(string: "https://github.com/settings/applications/new")!
        c.queryItems = [
            URLQueryItem(name: "oauth_application[name]", value: "Sprocket"),
            URLQueryItem(name: "oauth_application[url]", value: "https://github.com/MRL-00/Sprocket"),
            URLQueryItem(name: "oauth_application[callback_url]", value: "https://localhost/callback"),
            URLQueryItem(name: "oauth_application[description]",
                         value: "Menu-bar GitHub Actions monitor. Uses Device Flow — callback URL is unused."),
        ]
        return c.url!
    }()
}

private struct StepLine: View {
    let n: String
    let text: String
    init(_ n: String, _ text: String) { self.n = n; self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(n).font(.system(size: 12, weight: .medium)).foregroundStyle(.tertiary).frame(width: 16, alignment: .leading)
            Text(.init(text)).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DeviceFlowCheckboxIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("github.com")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.tertiary)
            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.10)).frame(height: 8)
            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.10)).frame(width: 110, height: 8)

            HStack(alignment: .top, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.sprocketAccent)
                        .frame(width: 12, height: 12)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Enable Device Flow").font(.system(size: 10, weight: .semibold))
                    Text("Allow this OAuth App to authorize users via Device Flow.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineSpacing(1)
                }
            }
            .padding(6)
            .background(Color.sprocketAccent.opacity(0.13), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.sprocketAccent, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            )
            .padding(.top, 4)

            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.10)).frame(width: 80, height: 8).padding(.top, 8)
            Text("Register application")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.sprocketAccent, in: RoundedRectangle(cornerRadius: 4))
                .padding(.top, 2)
        }
        .padding(10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
    }
}

private struct WelcomeStep3: View {
    @Environment(AppState.self) private var state
    @State private var saveForNextTime = true

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste your Client ID")
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.2)
            Text("From the GitHub page after registering, copy the Client ID and paste it here.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            Text("Client ID")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            ZStack(alignment: .trailing) {
                TextField("Iv1.…", text: $state.clientIDDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(isValid ? Color.sprocketAccent : Color.primary.opacity(0.15),
                                          lineWidth: 1)
                    )
                if isValid {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.sprocketSuccess)
                        .padding(.trailing, 10)
                }
            }

            if isValid {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                    Text("Looks like a valid Client ID")
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.sprocketSuccess)
            }

            if let err = state.signInError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .medium))
                    Text(err)
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.sprocketFailure)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.sprocketFailure.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Next: device sign-in")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text("We'll show a one-time code, open `github.com/login/device` in your browser, and finish signing in automatically.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
            .padding(.top, 6)

            Toggle("Save this Client ID for next time", isOn: $saveForNextTime)
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5))
                .padding(.top, 4)
        }
    }

    private var isValid: Bool {
        isPlausibleClientID(state.clientIDDraft.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct DeviceFlowProgress: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Authorize Sprocket on GitHub")
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.2)

            Text("We've opened **github.com/login/device** in your browser and copied your one-time code. Paste the code there to finish signing in.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Your one-time code")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                HStack(spacing: 8) {
                    Text(state.pendingUserCode ?? "")
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.sprocketAccent, lineWidth: 1))
                    Button("Copy") {
                        if let code = state.pendingUserCode {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(code, forType: .string)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button {
                if let url = state.pendingVerificationURL { openURL(url) }
            } label: {
                Label("Open github.com/login/device", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.sprocketAccent)
            .padding(.top, 4)

            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Waiting for you to authorize on GitHub…")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            if let err = state.signInError {
                Text(err).font(.system(size: 11)).foregroundStyle(Color.sprocketFailure)
            }
        }
        .onAppear {
            if let url = state.pendingVerificationURL { openURL(url) }
        }
    }
}
