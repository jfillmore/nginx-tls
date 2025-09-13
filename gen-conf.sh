#!/bin/bash -u

BASE_DIR=$(cd $(dirname "$0") && pwd -P)
SCRIPT_NAME=$(basename "$0")

CA_NAME="acme-fake-ca"
CERT_NAME="paladin-co"

SITE_DIRS=(
    "$BASE_DIR/sites"
)


# functions
# ==========================================

fail() {
    echo "${1-command failed}" >&2
    exit ${2:-1}
}

rem() {
    [ "$VERBOSE" -eq 1 ] && echo -e "+ [\033[1;37;40m$@\033[0;0m]" >&2
}

usage() {
    cat <<EOI
Usage: $SCRIPT_NAME [ARGUMENTS] OUTPUT_DIR
(e.g.)

ARGUMENTS:

    -l|--link             Automatically link sites-enabled/ to sites-available/
    -d|--dry-run          Run without making any changes
    -f|--force            Force regeneration of the CA/host certificates
    -h|--help             This information
    -v|--verbose          Print debugging information to stdout

    --pki-only            Only generate the PKI (CA and certs)

EXAMPLE:

    \$ $SCRIPT_NAME -v /usr/local/etc/nginx/
EOI
}

cmd() {
    if [ $DRYRUN -eq 1 ]; then
        echo -e "\033[0;33;40m# $@\033[0;0m" >&2
    else
        [ $VERBOSE -eq 1 ] && echo -e "\033[0;33;40m> $@\033[0;0m" >&2
        "$@"
    fi
}

prompt_yn() {
    local msg="${1:-confinue?}"
    local resp=''
    while [ "$resp" != 'y' -a "$resp" != 'n' ]; do
        read -p "$msg (y|n) > " resp
    done
    [ "$resp" = 'y' ] && return 0 || return 1
}


gen_ssl_ca() {
    local dest="$1"
    # generate CA RSA key and certificate
    [ -f "$dest/$CA_NAME.key" -a $FORCE -eq 0 ] \
        || cmd openssl genrsa \
            -out "$dest/$CA_NAME.key" \
            4096 \
            || fail "failed to generate CA RSA key"
    [ -f "$dest/$CA_NAME.crt" ] && {
        cmd openssl x509 \
            -checkend 0 \
            -noout \
            -in "$dest/$CERT_NAME.crt" \
            || is_expired=1
    }
    [ -f "$dest/$CA_NAME.crt" -a $FORCE -eq 0 ] \
        || cmd openssl req \
            -x509 \
            -new \
            -sha256 \
            -nodes \
            -days $((365 * 1)) \
            -key "$dest/$CA_NAME.key" \
            -out "$dest/$CA_NAME.crt" \
            -config "$BASE_DIR/openssl-ca-crt.config" \
            || fail "failed to generate CA certificate"
}


gen_ssl() {
    local dest="$1"
    local is_expired=0
    [ -f "$dest/$CERT_NAME.key" -a -f "$dest/$CERT_NAME.csr" -a $FORCE -eq 0 ] || {
        rem "creating $dest/$CERT_NAME.key (and CSR)"
        cmd openssl req \
            -nodes \
            -newkey rsa:4096 \
            -keyout "$dest/$CERT_NAME.key" \
            -out "$dest/$CERT_NAME.csr" \
            -config "$BASE_DIR/openssl-crt.config" \
            || fail "Failed to generate $dest/$CERT_NAME.key"
    }

    [ -f "$dest/$CERT_NAME.crt" ] && {
        cmd openssl x509 \
            -checkend 0 \
            -noout \
            -in "$dest/$CERT_NAME.crt" \
            || is_expired=1
    }
    [ -f "$dest/$CERT_NAME.crt" -a $FORCE -eq 0 -a $is_expired -eq 0 ] || {
        rem "creating $dest/$CERT_NAME.crt"
        cmd openssl x509 -req \
            -in "$dest/$CERT_NAME.csr" \
            -extfile "$BASE_DIR/openssl-crt.config" \
            -extensions req_ext \
            -CA "$dest/$CA_NAME.crt" \
            -CAkey "$dest/$CA_NAME.key" \
            -CAcreateserial \
            -days $((365 * 1)) \
            -sha256 \
            -out "$dest/$CERT_NAME.crt" \
            || fail "Failed to generate $dest/$CERT_NAME.crt"

    }
}


# collect args
# ==========================================

VERBOSE=0
DRYRUN=0
FORCE=0

output_dir=
tls_only=0
auto_link=0

while [ $# -gt 0 ]; do
    arg="$1"
    shift
    case "$arg" in
        --dry-run|-d)
            DRYRUN=1
            ;;
        --verbose|-v)
            [ $VERBOSE -eq 1 ] && set -x
            VERBOSE=1
            ;;
        --help|-h)
            usage
            exit
            ;;
        --force|-f)
            FORCE=1
            ;;
        --link|-l)
            auto_link=1
            ;;
        --pki-only)
            tls_only=1
            ;;
        *)
            [ -n "$output_dir" ] && fail "'$output_dir' already given"
            output_dir="$arg"
            ;;
    esac
done


# script body
# ==========================================

which openssl &>/dev/null || fail "openssl not found; cannot generate certs"

[ -n "$output_dir" ] || {
    usage
    fail "No output dir given"
}
[ -d "$output_dir" ] || fail "'$output_dir' not found or can't be read"


# DREAM: template the nginx config files
rem "generating SSL CA"
gen_ssl_ca "$output_dir" || fail

rem "generating SSL certs"
gen_ssl "$output_dir" || fail

[ $tls_only -eq 0 ] && {
    rem "generating configs"
    cmd mkdir -p "$output_dir/sites-enabled"
    cmd mkdir -p "$output_dir/sites-available"

    rem " - nginx.conf"
    cp "$BASE_DIR/nginx.conf.tpl" "$output_dir/nginx.conf" \
        || fail "Failed to copy '$output_dir/nginx.conf'"

    rem " - ssl-includes.conf"
    cmd cp "$BASE_DIR/ssl-includes.conf" "$output_dir/"

    for site_dir in "${SITE_DIRS[@]}"; do
        for src_file in "$site_dir"/*.tpl; do
            dest_file=sites-available/$(basename "${src_file%%.tpl}")
            rem " - $dest_file"
            cmd cp "$src_file" "$output_dir/$dest_file" \
                || fail "Failed to copy '$output_dir/$dest_file'"
            (
                cmd cd "$output_dir/sites-enabled/" \
                    && cmd ln -sf "../$dest_file"
            ) || fail "Failed to create symlink for $output_dir/$dest_file"
        done
    done
}

echo "- Consider adding trust for '$output_dir/$CA_NAME.crt' (see README.md)"
echo "e.g. sudo security add-trusted-cert '$output_dir/$CA_NAME.crt'"

[ $tls_only -eq 0 ] && echo "- Be sure to run 'sudo nginx -s reload'"

exit 0

