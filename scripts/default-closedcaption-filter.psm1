Import-Module -Name "$HELPERFOLDER/subtitle-parsing.psm1"
function Process {
    param ($subtitles)
    $temp = Remove-Names $subtitles
    $temp = Remove-Captions $temp
    $temp
}
