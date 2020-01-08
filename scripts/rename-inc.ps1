[CmdletBinding()]
param (
    [parameter(Mandatory=$true)]
    [int] $startOffset,
    [int] $amount = 1
)

if ($amount -eq 0) {
    throw "Amount needs to be either negative or positive, not 0."
}

$runs = Get-ChildItem -Path (Get-Location) -Filter "r*.srt" | ForEach-Object {
    if ($_.Name.Contains("_")) {
        $tempCnt = [int] ($_.Name.Substring(1, $_.Name.LastIndexOf("_") - 1));
    } else {
        $tempCnt = [int] ($_.Name.Substring(1, $_.Name.LastIndexOf(".") - 1));
    }
    Add-Member -InputObject $_ -Type NoteProperty -Name "Counter" -Value $tempCnt -PassThru
}

# Note about sorting: incrementing counters might cause conflicts when renaming file 1 to file 2 and file 2 exists, so we start renaming from the end
# Negative amounts use sorting in the regular alphabetical direction
if ($amount -gt 0) {
    $runs = $runs | Sort-Object -Descending -Property Name
} else {
    $runs = $runs | Sort-Object -Property Name
}

$runs | ? { $_.Counter -ge $startOffset } `
      | % { Move-Item -Path $_.FullName -Destination (Join-Path $_.DirectoryName ("r{0:d3}{1}" -f ($_.Counter + $amount),($_.Name.Substring(4))) ) }
