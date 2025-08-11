#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Script:    spring-init.sh
# Author:    Leandro F. Moraes
# GitHub:    https://github.com/leandrofmoraes
# Version:   1.0.0
# Desc:      Spring Boot project initializer using Spring Initializr API
# Usage:     ./spring-init.sh
# Deps:      curl, jq, unzip, fzf (optional)
# ------------------------------------------------------------------------------
set -euo pipefail

# Function to check for required dependencies
check_deps() {
  local deps=(curl jq unzip)
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Dependency '$cmd' is not installed. Please install it and try again." >&2
      exit 1
    fi
  done
}

FZF_PRESENT=$(command -v fzf &> /dev/null && echo "true" || echo "false")

# Function to display an error message and exit
throw_exception() {
    echo "Error: $1" >&2
    exit 1
}

# Accept JSON response from Spring Initializr
METADATA=$(curl -s -H "Accept: application/json" https://start.spring.io) || throw_exception "Failed to fetch Spring Initializr metadata"

# Global variables
PROJECT_NAME=""
GROUP_ID=""
ARTIFACT_ID=""
JAVA_VERSION=""
BOOT_VERSION=""
DESCRIPTION=""
PROJECT_TYPE=""
DEPS_CSV=""

# Function: Prompt user to select the project type
set_project_type() {
  # Load available type keys (excluding "dependencies")
  readarray -t TYPE_KEYS < <(jq -r '._links | keys_unsorted[] | select(. != "dependencies")' <<<"$METADATA")

  echo "Choose project type:"
  # Display available options with numbered indexes
  for i in "${!TYPE_KEYS[@]}"; do
    printf "  %2d) %s\n" $((i+1)) "${TYPE_KEYS[i]}"
  done

# Get valid user selection
  while true; do
    read -rp "> " TYPE_IDX
    if [[ "$TYPE_IDX" =~ ^[0-9]+$ ]] && (( TYPE_IDX >= 1 && TYPE_IDX <= ${#TYPE_KEYS[@]} )); then
      break
    else
      echo "Invalid index! Select between 1 and ${#TYPE_KEYS[@]}"
    fi
  done

  PROJECT_TYPE="${TYPE_KEYS[$((TYPE_IDX-1))]}"
}

# Function: Prompt user to set a project name
set_project_name(){
  local mode="${1:-initial}"

  if [[ "$mode" == "review" ]]; then
    read -e -i "$PROJECT_NAME" -p "New project name: " tmp
    PROJECT_NAME="${tmp:-$PROJECT_NAME}"
    return
  fi

  read -p "Project name: " PROJECT_NAME
  PROJECT_NAME=${PROJECT_NAME:-$(jq -r '.name.default' <<<"$METADATA")}
}

# Function: Prompt user to set a Group ID
set_group_id(){
  local mode="${1:-initial}"

  if [[ "$mode" == "review" ]]; then
    read -e -i "$GROUP_ID" -p "New Group ID: " tmp
    GROUP_ID=${tmp:-$GROUP_ID}
    return
  fi

  read -p "Group ID (e.g., com.example): " GROUP_ID
  GROUP_ID=${GROUP_ID:-$(jq -r '.groupId.default' <<<"$METADATA")}
}

# Function: Prompt user to set a Artifact ID
set_artifact_id(){
  local mode="${1:-initial}"

  if [[ "$mode" == "review" ]]; then
    read -e -i "$ARTIFACT_ID" -p "New Artifact ID: " tmp
    ARTIFACT_ID="${tmp:-$ARTIFACT_ID}"
    return
  fi

  read -p "Artifact ID (e.g., my-project): " ARTIFACT_ID
  ARTIFACT_ID=${ARTIFACT_ID:-$(jq -r '.artifactId.default' <<<"$METADATA")}
}

# Function: Prompt user to set a Java version
set_java_version(){
  local mode="${1:-initial}"

  # Load available Java version names
  readarray -t AVAILABLE_VERSIONS < <(jq -r '.javaVersion.values[].name' <<<"$METADATA")

  echo "Available Java versions:"
  for i in "${!AVAILABLE_VERSIONS[@]}"; do
    printf "  %2d) %s\n" $((i+1)) "${AVAILABLE_VERSIONS[i]}"
  done
  echo

  while true; do
    if [[ "$mode" == "review" ]]; then
      read -e -i "$jid" -p "New Java version: " tmp
      jid="${tmp:-$jid}"
    else
      read -rp "> " jid
    fi

    # Validate input
    if [[ "$jid" =~ ^[0-9]+$ ]] && (( jid >= 1 && jid <= ${#AVAILABLE_VERSIONS[@]} )); then
      break
    else
      echo "Invalid index! Select between 1 and ${#AVAILABLE_VERSIONS[@]}"
    fi
  done

  # Set Java version with fallback to default
  JAVA_VERSION="${AVAILABLE_VERSIONS[$((jid-1))]:-$(jq -r '.javaVersion.default' <<<"$METADATA")}"
}

# Function: Prompt user to set or review Spring Boot version
set_boot_version() {
  local mode="${1:-initial}"
  local boot_names boot_ids

  # Load available Spring Boot IDs and names (version names and IDs are swapped)
  readarray -t boot_ids < <(jq -r '.bootVersion.values[].name' <<<"$METADATA")
  readarray -t boot_names < <(jq -r '.bootVersion.values[].id' <<<"$METADATA")

  local default=$(jq -r '.bootVersion.default' <<<"$METADATA")

  echo "Choose Spring Boot version:"
  for i in "${!boot_names[@]}"; do
    printf "  %2d) %s\n" $((i+1)) "${boot_names[i]}"
  done

  while true; do
    if [[ "$mode" == "review" ]]; then
      read -e -i "$bid" -p "New Spring Boot version: " tmp
      bid="${tmp:-$bid}"
    else
      read -rp "> " bid
    fi

    # Validate input
    if [[ "$bid" =~ ^[0-9]+$ ]] && (( bid >= 1 && bid <= ${#boot_names[@]} )); then
      break
    else
      echo "Invalid index! Select between 1 and ${#boot_names[@]}"
    fi
  done
  # Set Boot version with fallback to default
  selected_id=$((bid-1))
  BOOT_VERSION="${boot_ids[selected_id]:-$default}"
}

# Function: Prompt user to set or review project description
set_description(){
  local mode="${1:-initial}"

  if [[ "$mode" == "review" ]]; then
    read -e -i "$DESCRIPTION" -p "New description: " tmp
    DESCRIPTION="${tmp:-$DESCRIPTION}"
    return
  fi

  read -p "Project description: " DESCRIPTION
  DESCRIPTION=${DESCRIPTION:-$(jq -r '.description.default' <<<"$METADATA")}
}

# Function: Prompt user to select dependencies
set_dependencies_without_fzf() {
  local mode="${1:-initial}"

  # Load dependency names and IDs
  readarray -t DEP_NAMES < <(jq -r '.dependencies.values[].values[].name' <<<"$METADATA")
  readarray -t DEP_IDS   < <(jq -r '.dependencies.values[].values[].id' <<<"$METADATA")

  # Format dependencies to display in 4 columns
  LINES=()
  for i in "${!DEP_NAMES[@]}"; do
    LINES+=( "$(printf "%3d) %s" $((i+1)) "${DEP_NAMES[i]}")" )
  done
  # Display in multi-column format
  printf "%s\n" "${LINES[@]}" | pr -t -4 -w "$(tput cols)"

  echo "Select dependencies (comma-separated indices):"

  # Get and validate user selections
  while true; do
    if [[ "$mode" == "review" ]]; then
      read -e -i "$CHOICES" -p "> " tmp
      CHOICES="${tmp:-$CHOICES}"
    else
      read -rp "> " CHOICES
    fi

    INVALID=0
    IFS=, read -ra SEL_IDX <<<"$CHOICES"
    SEL_IDS=()

    # Validate each selection
    for idx in "${SEL_IDX[@]}"; do
      if [[ ! "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#DEP_NAMES[@]} )); then
        echo "Invalid index: $idx"
        INVALID=1
      else
        SEL_IDS+=("${DEP_IDS[$((idx-1))]}")
      fi
    done

    (( INVALID == 0 )) && break
  done

  # Convert to comma-separated string
  DEPS_CSV=$(IFS=,; echo "${SEL_IDS[*]}")
}

set_dependencies() {
  local mode="${1:-initial}"

  # Delegate to set_dependencies if fzf is not available
  if ! command -v fzf &>/dev/null; then
    set_dependencies_without_fzf "$mode"
    return
  fi

  # Load dependency names and IDs
  readarray -t DEP_NAMES < <(jq -r '.dependencies.values[].values[].name' <<<"$METADATA")
  readarray -t DEP_IDS   < <(jq -r '.dependencies.values[].values[].id' <<<"$METADATA")

  # Prepare items for fzf
  local fzf_items=()
  for i in "${!DEP_NAMES[@]}"; do
    fzf_items+=("$((i+1))" "${DEP_NAMES[i]}")
  done

  local prompt_msg
  case "$mode" in
    "review")
      prompt_msg="Revisar dependências (TAB para selecionar múltiplas)"
      ;;
    *)
      prompt_msg="Selecione as dependências (TAB para múltiplas)"
      ;;
  esac

  # Uses fzf to select dependencies
  local selections
  selections=$(printf "%s\t%s\n" "${fzf_items[@]}" |
    fzf --multi \
        --height 60% \
        --border \
        --header "↑↓ para navegar | TAB para selecionar | ENTER para confirmar" \
        --prompt "$prompt_msg > " \
        --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
        --with-nth 2..
    )

  if [[ -z "$selections" ]]; then
    echo "Seleção cancelada pelo usuário"
    return 1
  fi

  # Process the selected items
  SEL_IDS=()
  while IFS=$'\t' read -r idx name; do
    local array_idx=$((idx - 1))
    SEL_IDS+=("${DEP_IDS[$array_idx]}")
  done <<< "$selections"

  DEPS_CSV=$(IFS=,; echo "${SEL_IDS[*]}")
}

# Function: Call all field-setters in sequence
set_fields(){
  set_project_type
  set_project_name
  set_group_id
  set_artifact_id
  set_java_version
  set_boot_version
  set_description
  set_dependencies
}

# Function: Download and unpack the project ZIP from Spring Initializr
project_download() {
  curl https://start.spring.io/starter.zip \
    -d type="$PROJECT_TYPE" \
    -d javaVersion="$JAVA_VERSION" \
    -d bootVersion="$BOOT_VERSION" \
    -d name="$PROJECT_NAME" \
    -d groupId="$GROUP_ID" \
    -d artifactId="$ARTIFACT_ID" \
    -d description="$DESCRIPTION" \
    -d dependencies="$DEPS_CSV" \
    -o "$PROJECT_NAME.zip" \
    && unzip -q "$PROJECT_NAME.zip" -d "$PROJECT_NAME" \
    && rm "$PROJECT_NAME.zip" \
    || throw_exception "Failed to download project"

  echo "Project '$PROJECT_NAME' downloaded and extracted successfully!"
  exit 0
}

# Function: Review and re-execute a specific setter based on user choice
revise_exec() {
  case "$1" in
    1) set_project_name review ;;
    2) set_group_id     review ;;
    3) set_artifact_id  review ;;
    4) set_java_version review ;;
    5) set_boot_version review ;;
    6) set_description  review ;;
    7) set_project_type review ;;
    8) set_dependencies review ;;
  esac
}

# Function: Prompt which field to change during review
field_to_change() {
  clear
  echo "Which field would you like to change?"
  echo "  1) Project name"
  echo "  2) Group ID"
  echo "  3) Artifact ID"
  echo "  4) Java Version"
  echo "  5) Spring Boot Version"
  echo "  6) Description"
  echo "  7) Project type"
  echo "  8) Dependencies"
  echo -e "  0) Back\n"

  while true; do
    read -rp "> " FIELD
    if [[ "$FIELD" == "0" ]]; then
      return
    elif [[ "$FIELD" =~ ^[1-8]$ ]]; then
      revise_exec "$FIELD"
      break
    else
      echo "Invalid option! Choose between 0 and 8."
    fi
  done
}

# Function: Display a summary of current project settings
project_summary() {
  clear
  cat <<EOF
Project summary:
  Name         : $PROJECT_NAME
  Group ID     : $GROUP_ID
  Artifact ID  : $ARTIFACT_ID
  Java Version : $JAVA_VERSION
  Spring Boot  : $BOOT_VERSION
  Description  : $DESCRIPTION
  Type         : $PROJECT_TYPE
  Dependencies : $DEPS_CSV
EOF
  echo "=================================="
}

# Function: Menu to review summary and choose next action
summary_menu(){
  while true; do
    project_summary
    echo -e "\n1) Change a field\n2) Continue\n3) Exit\n"
    read -rp "> " OPT

    case "$OPT" in
      1) field_to_change ;;  # go back to review
      2) actions_menu ;;     # proceed
      3) exit 0 ;;           # quit
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}

# Function: Main action menu for download, review or exit
actions_menu() {
  clear
  echo -e "\n=================================="
  echo "Select an action:"
  echo "1) Download project"
  echo "2) Review settings"
  echo -e "3) Exit\n"

  while true; do
    read -rp "> " ACTION
    if [[ "$ACTION" =~ ^[1-3]$ ]]; then
      break
    else
      echo "Invalid option! Choose between 1 and 3."
    fi
  done

  case "$ACTION" in
    1) project_download ;;  # download
    2) summary_menu  ;;     # review
    3) exit 0       ;;     # quit
  esac
}

# Entry point: collect all fields and then present action menu
check_deps   # Ensure required dependencies are installed
set_fields # Initialize project settings
actions_menu # Show main menu
