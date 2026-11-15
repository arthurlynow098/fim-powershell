$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'FIM.psm1'
Import-Module $modulePath -Force

Describe 'Monitor de integridade' {

    BeforeEach {
        $script:lab = Join-Path ([System.IO.Path]::GetTempPath()) ("fim-teste-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:lab | Out-Null
        Set-Content -Path (Join-Path $script:lab 'config.ini') -Value 'porta=8080'
        Set-Content -Path (Join-Path $script:lab 'leia-me.txt') -Value 'arquivo de teste'
        $script:baseline = Get-FileSnapshot -Path $script:lab
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:lab
    }

    It 'não acusa nada quando nada mudou' {
        $changes = Compare-Snapshot -Baseline $script:baseline -Current (Get-FileSnapshot -Path $script:lab)
        @($changes).Count | Should -Be 0
    }

    It 'detecta arquivo alterado' {
        Set-Content -Path (Join-Path $script:lab 'config.ini') -Value 'porta=4444'
        $changes = Compare-Snapshot -Baseline $script:baseline -Current (Get-FileSnapshot -Path $script:lab)
        $changes[0].Tipo | Should -Be 'ALTERADO'
        $changes[0].Arquivo | Should -Be 'config.ini'
    }

    It 'detecta arquivo criado e removido' {
        Remove-Item (Join-Path $script:lab 'leia-me.txt')
        Set-Content -Path (Join-Path $script:lab 'backdoor.ps1') -Value 'teste'
        $changes = Compare-Snapshot -Baseline $script:baseline -Current (Get-FileSnapshot -Path $script:lab)
        ($changes | Where-Object Tipo -eq 'CRIADO').Arquivo | Should -Be 'backdoor.ps1'
        ($changes | Where-Object Tipo -eq 'REMOVIDO').Arquivo | Should -Be 'leia-me.txt'
    }

    It 'ignora arquivos excluídos pelo filtro' {
        Set-Content -Path (Join-Path $script:lab 'cache.tmp') -Value 'temporario'
        $current = Get-FileSnapshot -Path $script:lab -Exclude @('*.tmp')
        $current.ContainsKey('cache.tmp') | Should -Be $false
    }

    It 'salva e lê a baseline em JSON sem perder nada' {
        $file = Join-Path $script:lab 'baseline.json'
        Save-Baseline -Path $script:lab -BaselineFile $file -Exclude @('baseline.json') | Should -Be 2
        $loaded = Read-Baseline $file
        $loaded['config.ini'] | Should -Be $script:baseline['config.ini']
    }
}
