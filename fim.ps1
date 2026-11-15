<#
.SYNOPSIS
Monitor de integridade de arquivos (FIM) com SHA-256.

.EXAMPLE
./fim.ps1 -Mode Baseline -Path C:\Lab
./fim.ps1 -Mode Check -Path C:\Lab
./fim.ps1 -Mode Monitor -Path C:\Lab -Interval 5 -LogFile fim.log
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('Baseline', 'Check', 'Monitor')] [string] $Mode,
    [Parameter(Mandatory)] [string] $Path,
    [string] $BaselineFile = (Join-Path $PSScriptRoot 'baseline.json'),
    [int] $Interval = 5,
    [string] $LogFile,
    [string[]] $Exclude = @('*.tmp', '*.log', '~$*')
)

Import-Module (Join-Path $PSScriptRoot 'FIM.psm1') -Force

$colors = @{ CRIADO = 'Green'; ALTERADO = 'Yellow'; REMOVIDO = 'Red' }

function Show-Changes($changes) {
    foreach ($c in $changes) {
        $line = Write-FimLog -LogFile $LogFile -Message ("{0,-9} {1}" -f $c.Tipo, $c.Arquivo)
        Write-Host "  $line" -ForegroundColor $colors[$c.Tipo]
    }
}

switch ($Mode) {
    'Baseline' {
        $count = Save-Baseline -Path $Path -BaselineFile $BaselineFile -Exclude $Exclude
        Write-Host "`n  baseline criada com $count arquivo(s) em $BaselineFile`n" -ForegroundColor Cyan
    }
    'Check' {
        if (-not (Test-Path $BaselineFile)) { throw "Baseline não encontrada. Rode primeiro com -Mode Baseline." }
        $changes = Compare-Snapshot -Baseline (Read-Baseline $BaselineFile) -Current (Get-FileSnapshot -Path $Path -Exclude $Exclude)
        if ($changes.Count -eq 0) {
            Write-Host "`n  nenhuma mudança, tudo íntegro`n" -ForegroundColor Green
            exit 0
        }
        Write-Host "`n  $($changes.Count) mudança(s) desde a baseline`n"
        Show-Changes $changes
        Write-Host ''
        exit 1
    }
    'Monitor' {
        if (-not (Test-Path $BaselineFile)) { throw "Baseline não encontrada. Rode primeiro com -Mode Baseline." }
        $baseline = Read-Baseline $BaselineFile
        $alreadySeen = @{}
        Write-Host "`n  monitorando $Path a cada $Interval s, Ctrl+C para parar`n" -ForegroundColor Cyan
        while ($true) {
            $changes = Compare-Snapshot -Baseline $baseline -Current (Get-FileSnapshot -Path $Path -Exclude $Exclude)
            # só avisa de novo se o arquivo mudar outra vez
            $fresh = $changes | Where-Object { $alreadySeen["$($_.Tipo)|$($_.Arquivo)"] -ne $true }
            if ($fresh) { Show-Changes $fresh }
            $alreadySeen = @{}
            foreach ($c in $changes) { $alreadySeen["$($c.Tipo)|$($c.Arquivo)"] = $true }
            Start-Sleep -Seconds $Interval
        }
    }
}
