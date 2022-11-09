
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

if ($args.Count -lt 1) {
  "Usage: with-mlb-dependencies <buildcommand> <buildargs>"
  exit 1
}

$mydir = Split-Path -Parent $PSCommandPath

. $mydir/smlbuild-include.ps1

$mlb = ""
$sml = ""
$output = ""
$expecting_output = $false

$args = $args -Replace "_DASH_","-"

foreach ($arg in $args) {

  if ($expecting_output) {
    $output = $arg
    $expecting_output = $false
  } else {
    if ($arg -match "[.]mlb$") {
      $mlb = $arg
    } elseif ($arg -match "[.]sml") {
      $sml = $arg
    } elseif ($arg -match "-o") {
      $expecting_output = $true
    } elseif ($arg -match "-output") {
      $expecting_output = $true
    }
    if ($mlb) {
      break
    }
  }
}

"mlb = $mlb" | Out-Host
"sml = $sml" | Out-Host
"output = $output" | Out-Host

$compiler=$args[0]
$compiler_args=$args[1..$args.length]

"$compiler $compiler_args" | Out-File ".mlb-dependencies-command"

&$compiler $compiler_args | Tee-Object -FilePath ".mlb-dependencies-output" | Out-Host

"Completed" | Out-Host

if ($mlb) {

  if (!$output) {
    $output = $mlb -replace "[.]mlb$",".exe"
  }
  $base = $output -replace "[.]exe$",""
  $deps = "$base.deps"

  "Writing dependencies to $deps"
    
  $lines = @(listMLB $mlb)

  if ($lines -match "^Error: ") {
    $lines -match "^Error: "
    exit 1
  }

  $lines = $lines -replace "^","${output}: "

  $lines | Out-File -Encoding "ASCII" $deps

} elseif ($sml) {

  if (!$output) {
    $output = $sml -replace "[.]mlb$",".exe"
  }
  $base = $output -replace "[.]exe$",""
  $deps = "$base.deps"

  "Writing dependencies to $deps"
    
  "${target}: $sml" | Out-File -Encoding "ASCII" $deps
}

Get-Content ".mlb-dependencies-output" | Out-Host


