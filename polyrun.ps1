
<#

.SYNOPSIS
Use Poly/ML to run a Standard ML program defined in a .mlb file

.EXAMPLE
polyrun example.mlb datafile.txt
Run the Standard ML program defined in example.mlb using Poly/ML, passing datafile.txt as an argument to the program

#>

if ($args.Count -lt 1) {
  "Usage: polyrun file.mlb [args...]"
  exit 1
}

$mlb = $args[0]

if ($mlb -notmatch "[.]mlb$") {
  "Error: argument must be a .mlb file"
  exit 1
}

$libdir = "c:/Users/Chris/Documents/mlton-20150109-all-mingw-492/lib/sml"

function script:processMLB($m) {

  if (! (Test-Path $m)) {
    "Error: file not found: " + $m
    return
  }

  $lines = @(Get-Content $m)

  # remove incompatible Basis lib and unneeded call to main
  $lines = $lines -notmatch "basis[.]mlb" -notmatch "main[.]sml"

  # remove ML-style comments
  $lines = $lines -replace "\(\*[^\*]*\*\)",""

  # expand library path
  $lines = $lines -replace "\$\(SML_LIB\)",$libdir

  # remove leading whitespace
  $lines = $lines -replace "^ *",""

  # remove trailing whitespace
  $lines = $lines -replace " *$",""

  # remove empty lines
  $lines = $lines -notmatch "^$"

  # remove lines with double-quotes in them, e.g. annotation
  $lines = $lines -notmatch """"

  $expanded = @()

  foreach ($line in $lines) {

    $path = $line

    if (!([System.IO.Path]::IsPathRooted($path))) {
      if (Split-Path -parent $m) {
        # resolve path relative to containing mlb file
        $path = (Join-Path (Split-Path -parent $m) $path)
      }
    }

    if ($path -match "[.]mlb$") {

      # recurse to expand included mlb
      $expanded += @(processMLB $path)
      
    } elseif ($path -match "[.](sml|sig)$") {

      # use forward slashes for path separators
      $path = $path -replace "\\","/";

      # add use declaration
      $path = $path -replace "^(.*)$",'use "$1";'

      $expanded += $path

    } else {
      Write-Warning "*** Warning: unsupported syntax or file in ${m}: ${line}"
    }
  }

  $expanded
}

$lines = @(processMLB $mlb)

if ($lines -match "^Error: ") {
  $lines -match "^Error: "
  exit 1
}

$outro = @"
val _ = main ();
val _ = OS.Process.exit (OS.Process.success);
"@ -split "[\r\n]+"

$script = @()
$script += $lines
$script += $outro

$tmpfile = ([System.IO.Path]::GetTempFileName()) -replace "[.]tmp",".sml"

$script | Out-File -Encoding "ASCII" $tmpfile

cat $tmpfile | polyml $args[1..$args.Length] | Out-Host

if (-not $?) {
    del $tmpfile
    exit $LastExitCode
}

del $tmpfile
