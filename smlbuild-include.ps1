
$libdir = "C:\mlton-20201002-1.amd64-mingw-gmp-dynamic\lib\mlton\sml"

#$mlton = (Get-Command mlton -ErrorAction SilentlyContinue).Path
#if ($mlton -ne "") {
#   $libdir = "$mlton\..\lib\mlton\sml"
#}

$libdir = $libdir -Replace "\\","/"

"Using ""$libdir"" as SML_LIB path"

function script:listMLB($m) {

  if (! (Test-Path $m)) {
    "Error: file not found: " + $m
    return
  }

  $lines = @(Get-Content $m)

  # remove incompatible Basis lib, MLton lib, and unneeded call to main
  $lines = $lines -notmatch "basis[.]mlb" -notmatch "mlton[.]mlb" -notmatch "main[.]sml"

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
      $expanded += @(listMLB $path)
      
    } elseif ($path -match "[.](sml|sig)$") {

      # use forward slashes for path separators
      $path = $path -replace "\\","/"

      $expanded += $path

    } else {
      Write-Warning "*** Warning: unsupported syntax or file in ${m}: ${line}"
    }
  }

  $expanded
}

function script:processMLB($m) {

  $lines = @(listMLB $mlb)

  if ($lines -match "^Error: ") {
    $lines -match "^Error: "
  } else {

    $expanded = @()

    foreach ($line in $lines) {

      $path = $line

      # add use declaration
      $path = $path -replace "^(.*)$",'use "$1";'

      $expanded += $path
    }

    $expanded
  }
}


