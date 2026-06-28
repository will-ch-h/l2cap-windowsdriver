# Fetches Microsoft's bthecho L2CAP sample (pinned) and retargets it to the
# AirPods AAP control channel. The driver IS bthcli — we change two GUIDs, one
# buffer size, and the INF bind. Nothing else needs to be written.
#
# Run:  pwsh ./setup.ps1   (then see BUILD.md)
$ErrorActionPreference = 'Stop'

$sha  = 'd5569c08aa2818c6240744bb47a00f67f20fdb54'  # windows-driver-samples, pinned
$repo = 'https://github.com/microsoft/windows-driver-samples.git'
$src  = Join-Path $PSScriptRoot 'src'
$bth  = Join-Path $src 'bluetooth/bthecho'

if (-not (Test-Path $bth)) {
    git clone --filter=blob:none --sparse $repo $src
    git -C $src sparse-checkout set bluetooth/bthecho
    git -C $src checkout $sha
}

# --- the entire driver delta -------------------------------------------------
$pub = Join-Path $bth 'common/inc/public.h'
$cli = Join-Path $bth 'common/inc/clisrv.h'
$inx = Join-Path $bth 'bthcli/sys/BthEchoSampleCli.inx'

# 1. Service GUID  -> AAP service (both the INF bind and the client's SDP PSM
#    lookup key). 2. Device interface GUID -> what winl2capsocket.cpp opens.
(Get-Content $pub -Raw) `
  -replace 'DEFINE_GUID\(BTHECHOSAMPLE_SVC_GUID[^;]*\)',
           'DEFINE_GUID(BTHECHOSAMPLE_SVC_GUID, 0x74ec2172, 0x0bad, 0x4d01, 0x8f, 0x77, 0x99, 0x7b, 0x2b, 0xe0, 0x72, 0x2a)' `
  -replace 'DEFINE_GUID\(BTHECHOSAMPLE_DEVICE_INTERFACE[^;]*\)',
           'DEFINE_GUID(BTHECHOSAMPLE_DEVICE_INTERFACE, 0x9eec98bb, 0x3c54, 0x45d4, 0xa8, 0x43, 0x79, 0x00, 0xc4, 0x63, 0x5e, 0x08)' |
  Set-Content $pub

# 3. AAP metadata SDUs exceed the sample's 256 echo buffer; match the app's
#    1024 read so a large packet is never truncated (silent data loss).
(Get-Content $cli -Raw) -replace 'BthEchoSampleMaxDataLength = 256', 'BthEchoSampleMaxDataLength = 1024' |
  Set-Content $cli

# 4. INF: bind to the AAP service node, set names.
(Get-Content $inx -Raw) `
  -replace '\{c07508f2-b970-43ca-b5dd-cc4f2391bef4\}', '{74ec2172-0bad-4d01-8f77-997b2be0722a}' `
  -replace '"TODO-Set-Provider"',     '"LibrePods"' `
  -replace '"TODO-Set-Manufacturer"', '"LibrePods"' `
  -replace '"Bluetooth Echo Sample Client"', '"LibrePods AAP L2CAP"' `
  -replace 'BthEchoSampleCli\.SVCDESC = "BthEchoSampleCli"', 'BthEchoSampleCli.SVCDESC = "LibrePods AirPods AAP L2CAP channel"' |
  Set-Content $inx

# --- canary: fail loudly if upstream moved and a replacement missed ----------
$pubOut = Get-Content $pub -Raw
$inxOut = Get-Content $inx -Raw
if ($pubOut -notmatch '0x9eec98bb' -or $pubOut -notmatch '0x74ec2172') { throw "public.h patch missed - upstream layout changed?" }
if ($pubOut -match '0xfc71b33d' -or $pubOut -match '0xc07508f2')        { throw "old GUID still in public.h" }
if ($inxOut -notmatch '74ec2172-0bad-4d01-8f77-997b2be0722a')           { throw "INF bind patch missed" }

Write-Host "OK. bthcli retargeted: iface 9eec98bb, service 74ec2172, PSM 0x1001 via SDP. Now see BUILD.md."
