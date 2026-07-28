# Participant card

Replace `N` with your team number.

1. Join the venue workshop Wi-Fi. If the board is not configured, join
   `equipoN-setup`, open `http://10.42.N.1:8080/`, and choose venue Wi-Fi.
2. One teammate opens `http://equipoN.local:6080/control.html`.
3. Everyone else opens `http://equipoN.local:6080/view.html`.
4. Send a message mentioning your team's Telegram bot. The bot works only for
   the five users approved by the instructor.

Other access:

```text
SSH:    ssh cdmx@equipoN.local
Samba:  smb://equipoN.local/workspace
```

The shared code directory is `/var/lib/cdmx-picoclaw/workspace`. Keep all agent
work there. Do not paste API keys or bot tokens into chat, source files, or the
terminal.

Before unplugging, use `sudo poweroff` and wait for activity to stop. If power
is removed unexpectedly, the board should recover on the next boot, but an SD
card can still be damaged by interruption during a write.
