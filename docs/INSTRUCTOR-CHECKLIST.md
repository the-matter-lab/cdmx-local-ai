# Instructor checklist

## Two weeks before

- Confirm all ten boards are ZERO 3W 1 GB and all cards are the same model and
  byte capacity.
- Use 5V/2A-or-better supplies and test the exact power cables. The ZERO 3 only
  accepts 5V input.
- Build, sanitize, capture, and read-back verify the golden image.
- Flash `equipo1` through `equipo10`; never boot two cards with the same number.
- Boot every card twice, including one deliberate unplug/replug test after all
  writes have settled.
- Verify `.local`, SSH, Samba write/delete, controller noVNC, view-only noVNC,
  Bayesian demo, zram, and setup AP recovery.
- If using USB rescue, enable the Radxa OTG peripheral overlay and NCM service
  on the master, then test macOS and Windows hosts.

## Credentials to prepare

- One local workshop password for Linux/Samba/setup AP/noVNC. Print it on the
  team card; do not reuse a personal password.
- Ten OpenAI project keys or, preferably, ten budgeted LiteLLM virtual keys.
- Ten Telegram bots, one per team. Record each token in an offline instructor
  secret sheet and configure one team group per bot.
- One to five numeric Telegram user IDs per team. Do not use a wildcard or an
  empty allowlist.
- Optional Discord app/bot per team with Message Content Intent enabled.

Inject API/channel credentials only after flashing each clone. Never add them
to the golden card or repository.

## Venue network rehearsal

- Prefer a dedicated workshop router/AP sized for roughly 60 clients (ten
  boards plus participant devices). Verify DHCP capacity and client-to-client
  traffic.
- If using venue Wi-Fi, explicitly ask whether multicast/mDNS and peer traffic
  are blocked. A successful Internet connection does not prove noVNC will work.
- Keep SSID/password ready for the onboarding page, but do not bake them into
  the cards.
- Record DHCP leases/IPs as a fallback when `.local` is unavailable.

## Day of

1. Power boards in batches and check `equipoN-setup` or the saved network.
2. Open each noVNC view-only link from the instructor laptop.
3. Run `systemctl --failed` and `free -h` over SSH.
4. Configure/test the team bot before handing out its QR/invite.
5. Designate one noVNC controller per team; everyone else uses view-only.
6. Keep two pre-flashed spare cards and at least one spare board/power supply.

## Recovery commands

```bash
sudo cdmx-network status
sudo cdmx-network reset
sudo systemctl restart cdmx-desktop cdmx-novnc cdmx-demo
sudo systemctl restart cdmx-picoclaw
sudo journalctl -u cdmx-network -u cdmx-picoclaw -n 100 --no-pager
sudo reboot
```
