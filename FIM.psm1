# Funções do monitor de integridade. O script fim.ps1 só chama essas funções.

function Get-FileSnapshot {
    <#
    .SYNOPSIS
    Calcula o SHA-256 de todos os arquivos de uma pasta (recursivo).
    Devolve uma hashtable com o caminho relativo como chave.
    #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [string[]] $Exclude = @()
    )
    $root = (Resolve-Path $Path).Path.TrimEnd('\', '/')
    $snapshot = @{}
    Get-ChildItem -Path $root -File -Recurse -Force | Where-Object {
        $name = $_.Name
        -not ($Exclude | Where-Object { $name -like $_ })
    } | ForEach-Object {
        $relative = $_.FullName.Substring($root.Length + 1)
        $snapshot[$relative] = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
    }
    return $snapshot
}

function Save-Baseline {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $BaselineFile,
        [string[]] $Exclude = @()
    )
    $snapshot = Get-FileSnapshot -Path $Path -Exclude $Exclude
    $data = [ordered]@{
        criado_em = (Get-Date).ToString('s')
        pasta     = (Resolve-Path $Path).Path
        arquivos  = $snapshot
    }
    $data | ConvertTo-Json -Depth 4 | Set-Content -Path $BaselineFile -Encoding UTF8
    return $snapshot.Count
}

function Read-Baseline {
    param([Parameter(Mandatory)] [string] $BaselineFile)
    $json = Get-Content -Path $BaselineFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $table = @{}
    foreach ($prop in $json.arquivos.PSObject.Properties) {
        $table[$prop.Name] = $prop.Value
    }
    return $table
}

function Compare-Snapshot {
    <#
    .SYNOPSIS
    Compara o estado atual com a baseline e devolve a lista de mudanças.
    #>
    param(
        [Parameter(Mandatory)] [hashtable] $Baseline,
        [Parameter(Mandatory)] [hashtable] $Current
    )
    $changes = New-Object System.Collections.Generic.List[object]
    foreach ($file in $Current.Keys) {
        if (-not $Baseline.ContainsKey($file)) {
            $changes.Add([pscustomobject]@{ Tipo = 'CRIADO'; Arquivo = $file })
        }
        elseif ($Baseline[$file] -ne $Current[$file]) {
            $changes.Add([pscustomobject]@{ Tipo = 'ALTERADO'; Arquivo = $file })
        }
    }
    foreach ($file in $Baseline.Keys) {
        if (-not $Current.ContainsKey($file)) {
            $changes.Add([pscustomobject]@{ Tipo = 'REMOVIDO'; Arquivo = $file })
        }
    }
    return , ($changes | Sort-Object Tipo, Arquivo)
}

function Write-FimLog {
    param([string] $LogFile, [string] $Message)
    $line = "{0} {1}" -f (Get-Date).ToString('s'), $Message
    if ($LogFile) { Add-Content -Path $LogFile -Value $line -Encoding UTF8 }
    return $line
}

Export-ModuleMember -Function Get-FileSnapshot, Save-Baseline, Read-Baseline, Compare-Snapshot, Write-FimLog
