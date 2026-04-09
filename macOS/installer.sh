c  #!/bin/bash

# ── Colors ──────────────────────────────────────────────────────────────
RST="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
WHITE="\033[1;37m"
DKCYAN="\033[2;36m"
DKGRAY="\033[90m"

# ── App definitions ─────────────────────────────────────────────────────
# Install types:
#   dmg - mount, copy .app to /Applications, detach
#   pkg - install via macOS installer command

APP_NAMES=(
    "Google Chrome"
    "Microsoft Teams"
    "Adobe Creative Cloud"
    "TeamViewer"
    "Dropbox"
    "Microsoft Outlook"
    "Microsoft Office 365"
)
APP_CATEGORIES=(
    "Browser"
    "Communication"
    "Creative Suite"
    "Remote Access"
    "Cloud Storage"
    "Email"
    "Productivity"
)
APP_URLS=(
    "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
    "https://go.microsoft.com/fwlink/?linkid=2249065"
    "https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v1/wam/download?sapCode=KCCC&startPoint=mam&platform=osx10-64"
    "https://download.teamviewer.com/download/TeamViewer.dmg"
    "https://www.dropbox.com/download?plat=mac&full=1"
    "https://go.microsoft.com/fwlink/?linkid=525137"
    "https://go.microsoft.com/fwlink/?linkid=2009112"
)
APP_FILES=(
    "googlechrome.dmg"
    "teams.pkg"
    "adobe_cc.dmg"
    "teamviewer.dmg"
    "dropbox.dmg"
    "outlook.pkg"
    "office365.pkg"
)
APP_TYPES=(
    "dmg"
    "pkg"
    "dmg"
    "dmg"
    "dmg"
    "pkg"
    "pkg"
)
APP_MIN_MACOS=(
    ""      # Chrome
    ""      # Teams
    ""      # Adobe CC
    ""      # TeamViewer
    ""      # Dropbox
    "14"    # Outlook
    "14"    # Office 365
)
APP_SELECTED=( 0 0 0 0 0 0 0 )
APP_COUNT=${#APP_NAMES[@]}

# ── Temp directory with cleanup ─────────────────────────────────────────
TEMP_DIR="${TMPDIR:-/tmp}/batch_installer"
mkdir -p "$TEMP_DIR"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

# ── Result tracking ─────────────────────────────────────────────────────
RESULT_NAMES=()
RESULT_STATUSES=()
RESULT_NOTES=()
PKG_ERROR=""

# ── Terminal helpers ────────────────────────────────────────────────────
get_width() { tput cols 2>/dev/null || echo 80; }

write_line() {
    local text="$1" color="${2:-$RST}"
    local w; w=$(get_width)
    printf "${color}%-${w}s${RST}\n" "$text"
}

# ── TUI Menu ────────────────────────────────────────────────────────────
draw_menu() {
    clear
    local w; w=$(get_width)
    local line
    line=$(printf '=%.0s' $(seq 1 "$w"))

    printf "${DKCYAN}%s${RST}\n" "$line"
    local title=" BATCH INSTALLER "
    local pad=$(( (w - ${#title}) / 2 ))
    printf "${WHITE}%*s%s${RST}\n" "$pad" "" "$title"
    printf "${DKCYAN}%s${RST}\n" "$line"
    echo ""
    echo "  Select apps to install:"
    echo ""

    for (( i=0; i<APP_COUNT; i++ )); do
        local num=$(( i + 1 ))
        local check="[ ]" check_color="$DKGRAY" name_color="$DKGRAY"
        if [[ ${APP_SELECTED[$i]} -eq 1 ]]; then
            check="[X]"; check_color="$GREEN"; name_color="$RST"
        fi

        local name="${APP_NAMES[$i]}"
        local cat="${APP_CATEGORIES[$i]}"
        local padded_name
        padded_name=$(printf "%-25s" "$name")

        printf "  ${CYAN}%d)${RST} ${check_color}%s${RST} ${name_color}%s${RST} ${DKGRAY}%s${RST}\n" "$num" "$check" "$padded_name" "$cat"
    done

    local sel=0
    for (( i=0; i<APP_COUNT; i++ )); do
        [[ ${APP_SELECTED[$i]} -eq 1 ]] && (( sel++ ))
    done

    echo ""
    if [[ $sel -gt 0 ]]; then
        printf "${CYAN}  %d of %d selected${RST}\n" "$sel" "$APP_COUNT"
    else
        printf "${DKGRAY}  0 of %d selected${RST}\n" "$APP_COUNT"
    fi
    echo ""
    printf "${DKGRAY}  [1-%d] Toggle    [A] All/None    [Enter] Install    [Q] Quit${RST}\n" "$APP_COUNT"
    echo ""
}

show_menu() {
    draw_menu

    while true; do
        printf "  > "
        local input=""
        read -r input

        case "$input" in
            [1-9])
                local idx=$(( input - 1 ))
                if [[ $idx -ge 0 && $idx -lt $APP_COUNT ]]; then
                    if [[ ${APP_SELECTED[$idx]} -eq 1 ]]; then
                        APP_SELECTED[$idx]=0
                    else
                        APP_SELECTED[$idx]=1
                    fi
                fi
                ;;
            a|A)
                local all=1
                for (( i=0; i<APP_COUNT; i++ )); do
                    [[ ${APP_SELECTED[$i]} -eq 0 ]] && all=0
                done
                if [[ $all -eq 1 ]]; then
                    for (( i=0; i<APP_COUNT; i++ )); do APP_SELECTED[$i]=0; done
                else
                    for (( i=0; i<APP_COUNT; i++ )); do APP_SELECTED[$i]=1; done
                fi
                ;;
            '') # Enter with no input
                local sel=0
                for (( i=0; i<APP_COUNT; i++ )); do
                    [[ ${APP_SELECTED[$i]} -eq 1 ]] && (( sel++ ))
                done
                if [[ $sel -eq 0 ]]; then
                    printf "${YELLOW}  Please select at least one app.${RST}\n"
                    sleep 0.8
                else
                    return 0
                fi
                ;;
            q|Q)
                clear
                echo "  Installer cancelled."
                exit 0
                ;;
        esac

        draw_menu
    done
}

# ── Download ────────────────────────────────────────────────────────────
download_file() {
    local url="$1" dest="$2"

    printf "${DKGRAY}         URL: %s${RST}\n" "$url"

    # Get file size via HEAD request
    local size_bytes
    size_bytes=$(curl -sIL -o /dev/null -w '%{size_download}' --head "$url" 2>/dev/null)
    local content_length
    content_length=$(curl -sIL "$url" 2>/dev/null | grep -i content-length | tail -1 | tr -d '\r' | awk '{print $2}')
    if [[ -n "$content_length" && "$content_length" -gt 0 ]] 2>/dev/null; then
        local size_mb
        size_mb=$(awk "BEGIN {printf \"%.2f\", $content_length / 1048576}")
        printf "${DKGRAY}         Size: %s MB${RST}\n" "$size_mb"
    else
        printf "${DKGRAY}         Size: unknown${RST}\n"
    fi

    # Download with progress bar (retry up to 3 times, resume partial downloads)
    local attempt
    for attempt in 1 2 3; do
        curl -L -# -o "$dest" -C - \
            --retry 3 --retry-delay 2 \
            -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
            "$url" 2>&1
        local curl_exit=$?
        if [[ $curl_exit -eq 0 ]]; then
            break
        fi
        if [[ $attempt -lt 3 ]]; then
            printf "${YELLOW}         Download interrupted, retrying (%d/3)...${RST}\n" "$((attempt + 1))"
        fi
    done

    # Validate download
    if [[ $curl_exit -ne 0 ]]; then
        printf "${RED}         Download failed (curl exit code %d)${RST}\n" "$curl_exit"
        rm -f "$dest"
        return 1
    fi
    if [[ ! -f "$dest" ]]; then
        printf "${RED}         Failed: file missing after download${RST}\n"
        return 1
    fi

    local fsize
    fsize=$(stat -f%z "$dest" 2>/dev/null || stat -c%s "$dest" 2>/dev/null || echo 0)
    if [[ "$fsize" -lt 1000 ]]; then
        printf "${RED}         Failed: file too small (%s bytes)${RST}\n" "$fsize"
        rm -f "$dest"
        return 1
    fi

    # Check it's not an HTML error page
    local ftype
    ftype=$(file --brief "$dest" 2>/dev/null)
    if echo "$ftype" | grep -qi "html\|ascii text\|xml document"; then
        local preview
        preview=$(head -c 200 "$dest" | tr '\n' ' ' | tr -s ' ')
        printf "${RED}         Error: server returned a web page instead of a file.${RST}\n"
        printf "${DKGRAY}         Preview: %s${RST}\n" "$preview"
        rm -f "$dest"
        return 1
    fi

    local dl_mb
    dl_mb=$(awk "BEGIN {printf \"%.2f\", $fsize / 1048576}")
    printf "${DKGRAY}         Done: %s MB${RST}\n" "$dl_mb"
    return 0
}

# ── Installers ──────────────────────────────────────────────────────────
install_dmg() {
    local filepath="$1" app_name="$2"

    # Mount the DMG
    local mount_output mount_point
    mount_output=$(hdiutil attach "$filepath" -nobrowse -noautoopen -noverify 2>&1)
    mount_point=$(echo "$mount_output" | awk -F'\t' '/\/Volumes\//{print $NF}' | head -1)
    # Fallback: try without tab delimiter
    if [[ -z "$mount_point" ]]; then
        mount_point=$(echo "$mount_output" | grep -o '/Volumes/.*' | head -1 | sed 's/[[:space:]]*$//')
    fi

    if [[ -z "$mount_point" ]]; then
        printf "${RED}         Failed to mount DMG${RST}\n"
        return 1
    fi

    # Find the .app bundle
    local app_path
    app_path=$(find "$mount_point" -maxdepth 2 -name "*.app" -print -quit 2>/dev/null)

    if [[ -z "$app_path" ]]; then
        # Some DMGs contain a .pkg instead
        local pkg_path
        pkg_path=$(find "$mount_point" -maxdepth 2 -name "*.pkg" -print -quit 2>/dev/null)
        if [[ -n "$pkg_path" ]]; then
            printf "${DKGRAY}         Found .pkg inside DMG, installing...${RST}\n"
            sudo installer -pkg "$pkg_path" -target /
            local exit_code=$?
            hdiutil detach "$mount_point" -quiet 2>/dev/null
            return $exit_code
        fi
        printf "${RED}         No .app or .pkg found in DMG${RST}\n"
        hdiutil detach "$mount_point" -quiet 2>/dev/null
        return 1
    fi

    # Copy to /Applications
    local app_basename
    app_basename=$(basename "$app_path")
    sudo rm -rf "/Applications/$app_basename"
    sudo cp -R "$app_path" /Applications/

    # Remove quarantine attribute
    sudo xattr -rd com.apple.quarantine "/Applications/$app_basename" 2>/dev/null

    # Detach
    hdiutil detach "$mount_point" -quiet 2>/dev/null
    return 0
}

install_pkg() {
    local filepath="$1"
    local logfile="$TEMP_DIR/installer_log.txt"

    # Run installer in background, write output to log
    sudo installer -pkg "$filepath" -target / > "$logfile" 2>&1 &
    local pid=$!

    # Spinner while waiting
    local spin='|/-\'
    local i=0
    local spin_start=$SECONDS
    while kill -0 "$pid" 2>/dev/null; do
        local elapsed=$(( SECONDS - spin_start ))
        printf "\r${DKGRAY}         Installing... %s (%ds)${RST}  " "${spin:i++%4:1}" "$elapsed"
        sleep 0.3
    done
    printf "\r"

    wait "$pid"
    local exit_code=$?

    # Show output and capture error
    cat "$logfile"
    if [[ $exit_code -ne 0 ]]; then
        PKG_ERROR=$(grep -i "error" "$logfile" | sed 's/installer: Error - //' | head -1)
    else
        PKG_ERROR=""
    fi
    rm -f "$logfile"
    return $exit_code
}

# ── Main install flow ───────────────────────────────────────────────────
install_apps() {
    clear

    # Build list of selected indices
    local chosen=()
    for (( i=0; i<APP_COUNT; i++ )); do
        [[ ${APP_SELECTED[$i]} -eq 1 ]] && chosen+=("$i")
    done
    local total=${#chosen[@]}

    local w; w=$(get_width)
    local line
    line=$(printf '=%.0s' $(seq 1 "$w"))

    printf "${DKCYAN}%s${RST}\n" "$line"
    printf "${WHITE}  BATCH INSTALLER${RST}\n"
    printf "${DKCYAN}%s${RST}\n" "$line"
    echo ""
    if [[ $total -gt 1 ]]; then
        printf "${WHITE}  Installing %d apps...${RST}\n" "$total"
    else
        printf "${WHITE}  Installing %d app...${RST}\n" "$total"
    fi
    echo ""

    # Log session
    local names_list=""
    for idx in "${chosen[@]}"; do
        [[ -n "$names_list" ]] && names_list+=", "
        names_list+="${APP_NAMES[$idx]}"
    done
    # Cache sudo credentials upfront and keep alive in background
    printf "${DKGRAY}  Enter your password to allow installations:${RST}\n"
    sudo -v
    # Refresh sudo every 60s so it doesn't expire during long downloads
    while true; do sudo -n true; sleep 60; done 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
    echo ""

    printf "${DKGRAY}         Session started. Installing: %s${RST}\n" "$names_list"

    local step=1
    for idx in "${chosen[@]}"; do
        local name="${APP_NAMES[$idx]}"
        local url="${APP_URLS[$idx]}"
        local file="${APP_FILES[$idx]}"
        local type="${APP_TYPES[$idx]}"
        local filepath="$TEMP_DIR/$file"
        local step_label="[$step/$total]"

        printf "${CYAN}  %s %s${RST}\n" "$step_label" "$name"

        # Check macOS version requirement
        local min_macos="${APP_MIN_MACOS[$idx]}"
        if [[ -n "$min_macos" ]]; then
            local current_macos
            current_macos=$(sw_vers -productVersion | cut -d. -f1)
            if [[ "$current_macos" -lt "$min_macos" ]]; then
                printf "${YELLOW}         Requires macOS %s or later (you have %s). Skipping.${RST}\n" "$min_macos" "$(sw_vers -productVersion)"
                RESULT_NAMES+=("$name")
                RESULT_STATUSES+=("WARN")
                RESULT_NOTES+=("Requires macOS $min_macos+")
                echo ""
                (( step++ ))
                continue
            fi
        fi

        # Download
        printf "${DKGRAY}         Downloading...${RST}\n"
        if ! download_file "$url" "$filepath"; then
            printf "${RED}         Download failed.${RST}\n"
            RESULT_NAMES+=("$name")
            RESULT_STATUSES+=("FAIL")
            RESULT_NOTES+=("Download failed")
            echo ""
            (( step++ ))
            continue
        fi

        # Detect actual file type and install
        printf "${YELLOW}         Installing...${RST}\n"
        local start_time=$SECONDS
        local exit_code=0
        local detected
        detected=$(file --brief "$filepath")

        if echo "$detected" | grep -qi "disk image\|bzip2\|zlib"; then
            install_dmg "$filepath" "$name"
            exit_code=$?
        elif echo "$detected" | grep -qi "xar archive\|package"; then
            install_pkg "$filepath"
            exit_code=$?
        else
            # Fall back to declared type
            case "$type" in
                dmg) install_dmg "$filepath" "$name"; exit_code=$? ;;
                pkg) install_pkg "$filepath"; exit_code=$? ;;
            esac
        fi

        local elapsed=$(( SECONDS - start_time ))

        if [[ $exit_code -eq 0 ]]; then
            printf "${GREEN}         Done. (%ds)${RST}\n" "$elapsed"
            RESULT_NAMES+=("$name")
            RESULT_STATUSES+=("OK")
            RESULT_NOTES+=("")
        else
            local note="Possible failure (exit code $exit_code)"
            if [[ -n "$PKG_ERROR" ]]; then
                note="$PKG_ERROR"
            fi
            printf "${YELLOW}         Installation may have failed (exit code %d). (%ds)${RST}\n" "$exit_code" "$elapsed"
            RESULT_NAMES+=("$name")
            RESULT_STATUSES+=("WARN")
            RESULT_NOTES+=("$note")
            PKG_ERROR=""
        fi

        # Clean up downloaded file
        rm -f "$filepath"

        echo ""
        (( step++ ))
    done

    # ── Summary ─────────────────────────────────────────────────────────
    printf "${DKCYAN}%s${RST}\n" "$line"
    printf "${WHITE}  SUMMARY${RST}\n"
    printf "${DKCYAN}%s${RST}\n" "$line"
    echo ""

    local ok_count=0 warn_count=0 fail_count=0

    for (( i=0; i<${#RESULT_NAMES[@]}; i++ )); do
        local status="${RESULT_STATUSES[$i]}"
        local rname="${RESULT_NAMES[$i]}"
        local note="${RESULT_NOTES[$i]}"

        case "$status" in
            OK)
                (( ok_count++ ))
                if [[ -n "$note" ]]; then
                    printf "${GREEN}  [OK]   ${RST}%s  (%s)\n" "$rname" "$note"
                else
                    printf "${GREEN}  [OK]   ${RST}%s\n" "$rname"
                fi
                ;;
            WARN)
                (( warn_count++ ))
                printf "${YELLOW}  [WARN] ${RST}%s  (%s)\n" "$rname" "$note"
                ;;
            FAIL)
                (( fail_count++ ))
                printf "${RED}  [FAIL] ${RST}%s  (%s)\n" "$rname" "$note"
                ;;
        esac
    done

    echo ""
    printf "${DKGRAY}  %d succeeded  |  %d warnings  |  %d failed${RST}\n" "$ok_count" "$warn_count" "$fail_count"
    echo ""
    printf "${DKGRAY}         Session complete. OK=%d WARN=%d FAIL=%d${RST}\n" "$ok_count" "$warn_count" "$fail_count"
    echo ""

    # Stop sudo keepalive
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
}

# ── Entry point ─────────────────────────────────────────────────────────
show_menu
install_apps
