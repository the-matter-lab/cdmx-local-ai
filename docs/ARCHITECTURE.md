# Architecture and tradeoffs

```text
participant phones/laptops
  ├─ HTTP 6080 ──> noVNC/websockify ──> 127.0.0.1:5901 TigerVNC/Openbox
  ├─ SSH/Samba ───────────────────────> shared workspace
  └─ Telegram/Discord cloud
             │ outbound long poll/WebSocket
             v
        PicoClaw (cdmx-agent, no sudo)
             │ OpenAI API or per-team LiteLLM virtual key
             v
       /var/lib/cdmx-picoclaw/workspace

network onboarding
  equipoN-setup / 10.42.N.1 ──> local portal ──> NetworkManager venue profile
  optional USB NCM / 10.55.N.1 ────────────────> recovery access
```

The graphical session is single and shared. `view.html` asks noVNC to suppress
input, while `control.html` permits it. This is coordination, not an access
control boundary: anyone who knows the controller URL and password can control
the desktop.

The channel agent is isolated from the login account so its API/channel secret
file is unreadable by ordinary participants. Both identities share only the
setgid workspace group. PicoClaw's command tool is enabled because autonomous
coding is the workshop topic; systemd limits its filesystem and OS privileges,
but it is not a mathematically complete sandbox.

The Wi-Fi onboarding portal is reachable only from that team's setup or USB
subnet, uses a per-process form token, validates all values, calls `nmcli` with
argument arrays rather than a shell, and never logs credentials. NetworkManager
stores the venue profile in its root-only system connection directory.
