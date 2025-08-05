# === KONFIGURATION ===
$headers = @{
    'X-API-KEY' = 'ABC1234567890987654321'
}
$agentsUrl = "https://api.yourdomain.com/agents/"
$cpuListUrl = "https://raw.githubusercontent.com/Bastika07/Win11/refs/heads/main/windows11-cpus.md"
$csvPath = "C:\\temp\\tacticalrmm-cpu-check.csv"  # Pfad anpassen!

# === FUNKTION ZUR NORMALISIERUNG ===
function Normalize-CPUString($str) {
    $str = $str -replace '[®™©]', ''
    $str = $str -replace '\(R\)|\(TM\)|\(C\)', ''
    $str = $str -replace 'Gen[0-9]+th', ''
    $str = $str -replace '[^a-zA-Z0-9]', ''
    $str = $str.ToLower()
    return $str
}

# === CPU-LISTE LADEN UND AUFBEREITEN ===
try {
    $cpuList = Invoke-WebRequest -Uri $cpuListUrl -UseBasicParsing
    $cpuLines = $cpuList.Content -split "`n"
} catch {
    Write-Output "Fehler beim Herunterladen der CPU-Liste."
    exit 1
}

$cpuEntries = @()
foreach ($line in $cpuLines) {
    if ($line -match '^\|\s*\w+') {
        $columns = $line -split '\|'
        if ($columns.Count -ge 4) {
            $hersteller = Normalize-CPUString $columns[1]
            $marke      = Normalize-CPUString $columns[2]
            $modell     = Normalize-CPUString $columns[3]
            if ($hersteller -and $marke -and $modell -and $hersteller -ne "hersteller") {
                $cpuEntries += "$hersteller$marke$modell"
            }
        }
    }
}

# === AGENTS ABFRAGEN ===
try {
    $agentsResult = Invoke-RestMethod -Method 'Get' -Uri $agentsUrl -Headers $headers -ContentType "application/json"
} catch {
    Write-Output "Fehler beim Abrufen der Agents."
    exit 1
}

# === VERGLEICH & SAMMELN ===
$results = @()
foreach ($agent in $agentsResult) {
    $hostname = $agent.hostname
    # Feldnamen ggf. anpassen!
    $cpuRaw = $agent.cpu_model
    $cpuNorm = Normalize-CPUString $cpuRaw

    $found = $false
    foreach ($entry in $cpuEntries) {
        if ($cpuNorm -like "*$entry*") {
            $found = $true
            break
        }
    }

    $status = if ($found) { "Unterstützt" } else { "Nicht unterstützt" }
    $results += [PSCustomObject]@{
        Hostname      = $hostname
        CPU           = $cpuRaw
        'Windows 11 Status' = $status
    }
}

# === EXPORT ALS CSV ===
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "Ergebnis als CSV gespeichert: $csvPath"
