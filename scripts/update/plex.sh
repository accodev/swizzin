#!/bin/bash

# The legacy Plex entry is a one-line plexmediaserver.list, but it becomes a
# deb822 plexmediaserver.sources once `apt modernize-sources` has run, which
# 10-dependencies.sh now does on trixie. Match both, or the migration silently
# never fires on a converted box.
plex_legacy_sources=(
    /etc/apt/sources.list.d/plexmediaserver.list
    /etc/apt/sources.list.d/plexmediaserver.sources
)

plex_needs_migration=
for plex_source in "${plex_legacy_sources[@]}"; do
    [[ -f $plex_source ]] && plex_needs_migration=true
done

if [[ -n $plex_needs_migration ]]; then
    echo_info "Updating plex apt repo endpoint"
    #shellcheck source=sources/functions/utils
    . /etc/swizzin/sources/functions/utils

    for plex_source in "${plex_legacy_sources[@]}"; do
        rm_if_exists "$plex_source"
    done

    # downloads.plex.tv/repo/deb is served under a key whose binding signature is
    # SHA1. Debian 13 refuses SHA1 from 2026-02-01, so apt cannot verify that
    # repository and falls back to a stale index, which silently pins plex to the
    # installed version. PlexSign.v2.key is EdDSA/SHA256 and signs repo.plex.tv.
    rm_if_exists /usr/share/keyrings/plex-archive-keyring.gpg
    rm_if_exists /usr/share/keyrings/plexmediaserver.gpg
    curl -sL https://downloads.plex.tv/plex-keys/PlexSign.v2.key | gpg --yes --dearmor -o /usr/share/keyrings/plexmediaserver.v2.gpg 2>> "${log}"
    echo "deb [signed-by=/usr/share/keyrings/plexmediaserver.v2.gpg] https://repo.plex.tv/deb public main" > /etc/apt/sources.list.d/plex.list
    apt_update
fi

# removing lockfile for the upgrade script so that it can be re-run as many times as people want
if [ -f "/install/.updateplex.lock" ]; then
    # echo file exists
    rm /install/.updateplex.lock
fi
