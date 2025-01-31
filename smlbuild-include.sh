#!/bin/bash
#
# Chris Cannam, 2015-2022. MIT licence

# Disable shellcheck warnings for useless-use-of-cat. UUOC is good
# practice, not bad: clearer, safer, less error-prone.
# shellcheck disable=SC2002

internal_debug=no

if [ -z "${SML_LIB:-}" ]; then
    lib=/usr/lib/mlton/sml
    if [ ! -d "$lib" ]; then
	lib=/usr/local/lib/mlton/sml
    fi
else
    lib="$SML_LIB"
fi

canonicalise() {
    local pre="$1"
    local post=""
    while [ "$pre" != "$post" ]; do
        if [ -z "$post" ]; then post="$pre"; else pre="$post"; fi
        post=$(echo "$post" | sed -e 's|[^/.][^/.]*/\.\./||g')
    done
    echo "$post" | sed -e 's|^./||' -e 's|//|/|g'
}

simplify() {
    local path="$1"
    simple=$(canonicalise "$path")
    if [ "$internal_debug" = "yes" ]; then
	echo "simplified \"$path\" to \"$simple\"" 1>&2
    fi
    if [ ! -f "$simple" ]; then
	echo "*** Error: input file \"$simple\" not found" 1>&2
        exit 1
    fi
    echo "$simple"
}

cat_mlb() {
    local mlb=$(canonicalise "$1")
    if [ ! -f "$mlb" ]; then exit 1; fi
    local dir
    dir=$(dirname "$mlb")
    if [ "$internal_debug" = "yes" ]; then
	echo "reading MLB file \"$mlb\":" 1>&2
    fi
    cat "$mlb" | while read -r line; do
        if [ "$internal_debug" = "yes" ]; then
	    echo "read line \"$line\":" 1>&2
        fi
	local trimmed
        # remove leading and trailing whitespace
        trimmed="${line#"${line%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        case "$trimmed" in
            # check for ML-style comments or variable sigils; only
            # launch a further substitution if we see any
            *[\($]*) 
                # Tell shellcheck that the $-variables in
                # single-quotes are not intended for bash to expand
                # shellcheck disable=SC2016
	        trimmed=$(
                    echo "$trimmed" |
                        # remove ML-style comments; expand library path
		        sed -e 's|(\*.*\*)||' -e 's#$(SML_LIB)#'"${lib}"'#g' |
                        # expand other vars:
		        perl -p -e 's|\$\(([A-Za-z_-]+)\)|$ENV{$1}|'
                       )
                ;;
            *) ;;
        esac
	local path="$trimmed"
	case "$path" in
	    "") ;;		                  # keep empty lines for ignoring later
	    /*) ;;
	    *) path="$dir/$trimmed" ;;
	esac
	case "$path" in
	    "") ;;		                  # ignore empty lines
	    *basis.mlb) ;;			  # remove incompatible Basis lib
	    *mlton.mlb) ;;			  # remove incompatible MLton lib
	    *main.sml) ;;			  # remove redundant call to main
	    *.mlb) cat_mlb "$path" ;;
	    *.sml) simplify "$path" ;;
	    *.sig) simplify "$path" ;;
            *) echo "*** Warning: unsupported syntax or file in $mlb: $trimmed" 1>&2
	esac
    done
    if [ "$internal_debug" = "yes" ]; then
	echo "finished reading MLB file \"$mlb\"" 1>&2
    fi
}

expand_arg() {
    local arg="$1"
    local unique="no"
    case "$arg" in
        "-u") unique=yes
              shift
              arg="$1" ;;
        *) ;;
    esac
    case "$arg" in
	*.sml) echo "$arg" ;;
	*.mlb) cat_mlb "$arg" ;;
	*) echo "*** Error: .sml or .mlb file must be provided" 1>&2
	   exit 1 ;;
    esac | (
        if [ "$unique" = "yes" ]; then
            cat -n | sort -k 2 -u | sort -n | awk '{ print $2; }'
        else
            cat
        fi
    )
}

get_base() {
    local arg="$1"
    case "$arg" in
	*.sml) basename "$arg" .sml ;;
	*.mlb) basename "$arg" .mlb ;;
	*) echo "*** Error: .sml or .mlb file must be provided" 1>&2
	   exit 1 ;;
    esac
}    

get_outfile() {
    local arg="$1"
    canonicalise $(dirname "$arg")/$(get_base "$arg")
}

get_tmpfile() {
    local arg="$1"
    mktemp /tmp/smlbuild-$(get_base "$arg")-XXXXXXXX
}

get_tmpsmlfile() {
    local arg="$1"
    mktemp /tmp/smlbuild-$(get_base "$arg")-XXXXXXXX.sml
}

get_tmpobjfile() {
    local arg="$1"
    mktemp /tmp/smlbuild-$(get_base "$arg")-XXXXXXXX.o
}


