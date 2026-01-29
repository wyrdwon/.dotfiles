#!/bin/zsh

# Configuration for accounts
# Modify these variables to match your actual accounts
declare -A ACCOUNT_CONFIG=(
    ["handle_username"]="wyrdwon"
    ["handle_name"]="wyrdwon"
    ["handle_email"]="tarmac2817@proton.me"
    
    ["prof_username"]="asiimwemmanuel"
    ["prof_name"]="Emmanuel Asiiwme"
    ["prof_email"]="catalog9731@proton.me"
)

# Function to get the currently active GitHub account
get_active_account() {
    local auth_status
    auth_status=$(gh auth status 2>&1)
    
    # Extract the active account username
    # Look for lines with "Active account: true" and get the username from the line above
    local active_user
    active_user=$(echo "$auth_status" | grep -B 2 "Active account: true" | grep "Logged in to github.com account" | sed -n 's/.*account \([^ ]*\).*/\1/p')
    
    echo "$active_user"
}

# Function to switch GitHub account and git config
switch_gh_account() {
    local target_username="$1"
    local target_name="$2"
    local target_email="$3"
    
    local current_account
    current_account=$(get_active_account)
    
    # Check if already on the target account (idempotent check)
    if [[ "$current_account" == "$target_username" ]]; then
        echo "Already using account: $target_username"
        return 0
    fi
    
    echo "Switching from $current_account to $target_username..."
    
    # Switch the GitHub CLI account
    if gh auth switch --user "$target_username" 2>/dev/null; then
        echo "✓ Switched GitHub CLI to: $target_username"
    else
        echo "✗ Failed to switch GitHub CLI account"
        return 1
    fi
    
    # Update git config
    git config --global user.name "$target_name"
    git config --global user.email "$target_email"
    
    echo "✓ Updated git config:"
    echo "  - user.name: $target_name"
    echo "  - user.email: $target_email"
    
    return 0
}

# Main function to set handle account
sethandle() {
    switch_gh_account \
        "${ACCOUNT_CONFIG[handle_username]}" \
        "${ACCOUNT_CONFIG[handle_name]}" \
        "${ACCOUNT_CONFIG[handle_email]}"
}

# Main function to set professional account
setprof() {
    switch_gh_account \
        "${ACCOUNT_CONFIG[prof_username]}" \
        "${ACCOUNT_CONFIG[prof_name]}" \
        "${ACCOUNT_CONFIG[prof_email]}"
}

# Functions are automatically available when script is sourced
# No need to export in modern shells

# If script is executed directly with an argument, run the corresponding function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        handle)
            sethandle
            ;;
        prof)
            setprof
            ;;
        status)
            echo "Current active account: $(get_active_account)"
            ;;
        *)
            echo "Usage: $0 {handle|prof|status}"
            exit 1
            ;;
    esac
fi
