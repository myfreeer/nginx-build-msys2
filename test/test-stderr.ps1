param(
    [Parameter(Mandatory = $true)]
    [string]$Exe,
    [int]$Port = 18082
)

$ErrorActionPreference = 'Stop'

$Exe = (Resolve-Path $Exe).Path
$root = Join-Path $env:LOCALAPPDATA ("Temp\nginx-stderr-test-" + [guid]::NewGuid().ToString('N'))
$confDir = Join-Path $root 'conf'
$logsDir = Join-Path $root 'logs'
$tempDir = Join-Path $root 'temp'
New-Item -ItemType Directory -Force -Path $confDir, $logsDir, $tempDir | Out-Null

$conf = Join-Path $confDir 'nginx.conf'
@"
worker_processes  1;
daemon            off;
master_process    on;
error_log         stderr info;
pid               logs/nginx.pid;

events {
    worker_connections  128;
}

http {
    access_log  stderr;

    server {
        listen      127.0.0.1:$Port;
        server_name localhost;

        location / {
            return 200 "ok\n";
        }
    }
}
"@ | Set-Content -Path $conf -Encoding utf8NoBOM

$prefix = ($root -replace '\\', '/') + '/'
$outLog = Join-Path $root 'stdout.log'
$errLog = Join-Path $root 'stderr.log'

function Wait-Http([string]$Url, [int]$Seconds = 10) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        try {
            return Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
        } catch {
            Start-Sleep -Milliseconds 200
        }
    }
    throw "timeout waiting for $Url"
}

try {
    & $Exe -p $prefix -c conf/nginx.conf -t 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'nginx -t failed' }

    $p = Start-Process -FilePath $Exe `
        -ArgumentList @('-p', $prefix, '-c', 'conf/nginx.conf') `
        -NoNewWindow -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
        -PassThru

    Start-Sleep -Milliseconds 1500

    $r = Wait-Http "http://127.0.0.1:$Port/"
    Start-Sleep -Milliseconds 500

    $err = Get-Content $errLog -Raw
    $workerAccess = $err -match '"GET / HTTP/1\.1" 200'
    $workerNotice = $err -match 'start worker process'

    Write-Output "http=$($r.StatusCode)"
    Write-Output "stderr_has_worker_notice=$workerNotice"
    Write-Output "stderr_has_worker_access=$workerAccess"

    & $Exe -p $prefix -c conf/nginx.conf -s reload 2>&1
    Start-Sleep -Milliseconds 1500
    $r2 = Wait-Http "http://127.0.0.1:$Port/reload-check"
    Start-Sleep -Milliseconds 500
    $err2 = Get-Content $errLog -Raw
    $reloaded = $err2 -match 'reconfiguring'
    $secondAccess = $err2 -match '"GET /reload-check HTTP/1\.1" 200'
    Write-Output "reload_notice=$reloaded"
    Write-Output "second_access=$secondAccess"

    & $Exe -p $prefix -c conf/nginx.conf -s quit 2>&1
    $deadline = (Get-Date).AddSeconds(8)
    while ((Get-Date) -lt $deadline -and -not $p.HasExited) {
        Start-Sleep -Milliseconds 200
    }
    Write-Output "master_exited=$($p.HasExited)"

    if ($workerAccess -and $workerNotice -and $reloaded -and $secondAccess -and $p.HasExited) {
        Write-Output 'RESULT=PASS'
        exit 0
    }

    Write-Output 'RESULT=FAIL'
    exit 1
} finally {
    Get-Process | Where-Object { $_.Path -eq $Exe } | Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}
