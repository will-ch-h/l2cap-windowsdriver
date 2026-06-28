# Build & install

Prereq: run `pwsh ./setup.ps1` first (fetches + retargets bthcli into `src/`).

## 1. Build

Use the **EWDK** (Enterprise WDK) — a single mountable ISO, no install needed:
download it, mount, and run `LaunchBuildEnv.cmd` to get a build shell.

```cmd
cd src\bluetooth\bthecho
msbuild bthecho.sln /p:Configuration=Release /p:Platform=x64
```

Output: `bthcli\sys\x64\Release\BthEchoSampleCli\` — contains the `.sys`, the
generated `.inf`, and a `.cat`.

## 2. Sign (self-signed) + test mode

Test mode still requires *a* signature; a free self-signed cert is enough — no
Microsoft signing needed.

```powershell
# one-time test cert
$c = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=LibrePods Dev" `
     -CertStoreLocation Cert:\CurrentUser\My -KeyUsage DigitalSignature `
     -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")
$t = (Get-Command signtool).Source   # from the EWDK/SDK

& $t sign /v /fd SHA256 /a /sc Cert:\CurrentUser\My `
     /n "LibrePods Dev" BthEchoSampleCli.sys
# trust the test cert (Local Machine root + trusted publisher), then:
bcdedit /set testsigning on    # reboot; Secure Boot must be off
```

Install: right-click the `.inf` → Install, or `pnputil /add-driver BthEchoSampleCli.inf /install`.
The driver attaches when AirPods connect; verify the interface exists with the
app's `WinL2capSocket::connectedAirPods()` (or check Device Manager → Bluetooth).
