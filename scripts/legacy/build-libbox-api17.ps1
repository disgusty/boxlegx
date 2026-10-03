# lx-legacy: сборка ядра sing-box-lx (libbox.aar) для Android 4.2+ (API 17).
#
# Что делает:
#   1. клонирует Leadaxe/sing-box-lx нужного тега с форк-сабмодулями;
#   2. кладёт копию модуля github.com/sagernet/sing в submodules/sing и
#      накладывает sing-old-kernels.patch (i386 sendmsg через socketcall —
#      прямой SYS_SENDMSG есть только с Linux 4.3; нефатальный SO_REUSEPORT —
#      Linux 3.9+), подключает её через replace в go.mod;
#   3. собирает AAR gomobile bind с -androidapi 17 под armeabi-v7a и x86
#      (NDK r23c — последний NDK с API 16–18).
#
# Требования: Go (версия из go.mod ядра, проверено на 1.25.5), git, JDK 17+,
# Android SDK (platforms;android-17), NDK r23c.
#
# Пример:
#   .\build-libbox-api17.ps1 -GoRoot C:\dev\go -NdkDir C:\dev\android-ndk-r23c `
#       -WorkDir C:\dev\singbox -Out ..\..\app\android\app\libs\libbox-api17.aar

param(
    [string]$Tag = 'v1.14.2-lx.11',
    [Parameter(Mandatory)] [string]$GoRoot,
    [Parameter(Mandatory)] [string]$NdkDir,
    [Parameter(Mandatory)] [string]$WorkDir,
    [Parameter(Mandatory)] [string]$Out,
    [string]$AndroidHome = "$env:LOCALAPPDATA\Android\Sdk"
)
# Ошибки нативных команд — по коду возврата: PowerShell 5.1 считает ошибкой
# любую строку в stderr (у git это обычные предупреждения).
function Check([string]$what) { if ($LASTEXITCODE -ne 0) { throw "$what failed: $LASTEXITCODE" } }
$patch = Join-Path $PSScriptRoot 'sing-old-kernels.patch'
$env:PATH = "$GoRoot\bin;$env:PATH"
$env:GOTOOLCHAIN = 'local'
$gopath = (& go env GOPATH)
$env:PATH = "$gopath\bin;$env:PATH"

# 1. Исходники ядра.
$src = Join-Path $WorkDir "sing-box-lx-$Tag"
if (-not (Test-Path $src)) {
    git clone -q --depth 1 --branch $Tag https://github.com/Leadaxe/sing-box-lx.git $src 2>$null; Check 'git clone'
    git -C $src submodule update --init --depth 1 `
        submodules/wireguard-go submodules/sing-tun submodules/gvisor submodules/utls 2>$null; Check 'submodules'
}
Push-Location $src
try {
    go mod download; Check 'go mod download'

    # 2. Модуль sing с патчами старых ядер.
    if (-not (Test-Path 'submodules/sing')) {
        $ver = ((Select-String go.mod -Pattern '^\s+github.com/sagernet/sing v(\S+)').Matches[0].Groups[1].Value)
        $cache = Join-Path (& go env GOMODCACHE) "github.com\sagernet\sing@v$ver"
        Copy-Item $cache 'submodules/sing' -Recurse
        Get-ChildItem 'submodules/sing' -Recurse -File | ForEach-Object { $_.IsReadOnly = $false }
        git apply --directory=submodules/sing $patch; Check 'git apply'
        Add-Content go.mod "`n// lx-legacy: sing с исправлениями для ядер Android 4.x.`nreplace github.com/sagernet/sing => ./submodules/sing`n"
    }

    # 3. gomobile bind.
    go install github.com/sagernet/gomobile/cmd/gomobile github.com/sagernet/gomobile/cmd/gobind; Check 'go install gomobile'
    $env:ANDROID_HOME = $AndroidHome
    $env:ANDROID_NDK_HOME = $NdkDir
    $env:GOARM = '7'
    $tags = 'with_gvisor,with_quic,with_wireguard,with_utls,badlinkname,tfogo_checklinkname0,' +
        'with_xhttp,with_awg,with_lx_command,with_lx_chain,with_lx_idle_suspend,with_openvpn,' +
        'with_openconnect,with_tailscale,ts_omit_logtail,ts_omit_ssh,ts_omit_drive,ts_omit_taildrop,' +
        'ts_omit_webclient,ts_omit_doctor,ts_omit_capture,ts_omit_kube,ts_omit_aws,ts_omit_synology,ts_omit_bird'
    $ld = "-X github.com/sagernet/sing-box/constant.Version=$($Tag.TrimStart('v'))-legacy -s -w -buildid= -checklinkname=0"
    if (Test-Path build) { Remove-Item build -Recurse -Force }
    $outFull = if ([IO.Path]::IsPathRooted($Out)) { $Out } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $Out)) }
    # gomobile через ProcessStartInfo: PowerShell 5.1 режет аргументы вида
    # -javapkg=io.nekohasekai по точке, а cmd.exe оставляет переменные
    # «=C:», на которых gomobile падает.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$gopath\bin\gomobile.exe"
    $psi.Arguments = "bind -v -o `"$outFull`" -target android/arm,android/386 -androidapi 17 " +
        "-javapkg=io.nekohasekai -libname=box -trimpath -buildvcs=false `"-ldflags=$ld`" -tags=$tags ./experimental/libbox"
    $psi.WorkingDirectory = $src
    $psi.UseShellExecute = $false
    foreach ($k in @($psi.EnvironmentVariables.Keys)) { if ($k.StartsWith('=')) { $psi.EnvironmentVariables.Remove($k) } }
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw "gomobile bind failed: $($p.ExitCode)" }
    Write-Host "OK: $outFull"
} finally {
    Pop-Location
}
