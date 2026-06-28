# l2cap-windowsdriver

Simple L2CAP bluetooth kernel level driver for windows to connect to Apple Airpods.

It exposes the AirPods **AAP control channel** over L2CAP so
[librepods-windows](https://github.com/will-ch-h/librepods-windowsbridge) can reach AirPods (the Microsoft
Bluetooth stack doesn't expose L2CAP to user mode).

## Forked from Microsoft's bthecho sample

This is **not** original kernel code. it's Microsoft's `bthecho` L2CAP client
profile driver (`bthcli`), retargeted to AirPods. The upstream is wired in as a
git remote:

```
$ git remote -v
origin     https://github.com/will-ch-h/l2cap-windowsdriver
upstream   https://github.com/microsoft/windows-driver-samples.git
```

- **Upstream:** [`microsoft/windows-driver-samples`](https://github.com/microsoft/windows-driver-samples), path `bluetooth/bthecho`
- **Pinned at:** commit `d5569c0`
- **Downstream delta:** the whole fork is [`setup.ps1`](setup.ps1) — it fetches
  the pinned sample into `src/' and applies four
  changes. 

| What | bthcli | here | why |
|------|--------|------|-----|
| Service GUID | `c07508f2-…` | `74ec2172-0bad-4d01-8f77-997b2be0722a` | bind to the AirPods AAP node + SDP PSM lookup |
| Interface GUID | `fc71b33d-…` | `9eec98bb-3c54-45d4-a843-7900c4635e08` | what `winl2capsocket.cpp` opens with `CreateFile` |
| Read buffer | 256 | 1024 | AAP metadata SDUs would otherwise truncate |
| INF bind | echo service | AAP service | PnP loads us on the AirPods service node |

The PSM (`0x1001`) is discovered from the AirPods SDP record by the unchanged
client code — no hardcoding needed.

## Use

```powershell
pwsh ./setup.ps1     # fetch + retarget into src/
# then BUILD.md to build and sign
```

The consuming app finds the driver purely by the interface GUID `9eec98bb…` and
a device path embedding the MAC (`&<mac>_c`), both of which bthcli already
produces. No app-side change.
