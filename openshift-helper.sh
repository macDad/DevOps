#!/bin/bash

# Check if fzf is installed
if ! command -v fzf &> /dev/null; then
    echo "fzf is not installed. Please install it first."
    echo "On Ubuntu/Debian: sudo apt-get install fzf"
    echo "On Fedora: sudo dnf install fzf"
    echo "On macOS: brew install fzf"
    exit 1
fi

# Function to login to OpenShift using a token
login_to_openshift() {
    echo "Paste your full 'oc login --token' command (e.g., 'oc login --token=... --server=https://...'):"
    read -r login_command

    # Execute the login command
    eval $login_command
    if [ $? -ne 0 ]; then
        echo "Login failed. Please check your command."
        exit 1
    fi
}

# Function to select the namespace
select_namespace() {
    # List all available namespaces and allow user to select one using fzf
    echo "Fetching available namespaces..."
    namespaces=$(oc get namespaces -o custom-columns=NAME:.metadata.name --no-headers)

    echo "Select a namespace (project) to work in:"
    namespace=$(echo "$namespaces" | fzf --height 10 --border --prompt="Select a namespace: ")

    if [ -z "$namespace" ]; then
        echo "No namespace selected. Exiting."
        exit 1
    fi

    # Switch to the selected namespace
    oc project $namespace
    if [ $? -ne 0 ]; then
        echo "Failed to switch to the namespace $namespace."
        exit 1
    fi

    echo "Selected namespace: $namespace"
}

# Function to select and update a Spring Boot application property in a ConfigMap
select_and_update_property() {
    echo "Enter the ConfigMap name containing the Spring Boot properties:"
    read configmap_name

    # Get the ConfigMap data
    configmap_data=$(oc get configmap $configmap_name -n $namespace -o jsonpath='{.data}' | jq 'to_entries | map("\(.key): \(.value)") | .[]')

    if [ -z "$configmap_data" ]; then
        echo "Failed to retrieve ConfigMap or it is empty. Please check the ConfigMap name."
        return
    fi

    echo "Available Spring Boot properties in ConfigMap '$configmap_name':"
    selected_property=$(echo "$configmap_data" | fzf --height 10 --border --prompt="Select a property to update: ")

    if [ -z "$selected_property" ]; then
        echo "No property selected."
        return
    fi

    # Extract the key and value
    property_key=$(echo "$selected_property" | cut -d ':' -f 1)
    property_value=$(echo "$selected_property" | cut -d ':' -f 2)

    echo "Selected property: $property_key"
    echo "Current value: $property_value"

    # Ask for the new value
    echo "Enter the new value for $property_key:"
    read new_value

    # Patch the ConfigMap with the new value
    oc patch configmap $configmap_name -n $namespace --type merge -p "{\"data\": {\"$property_key\": \"$new_value\"}}"

    if [ $? -ne 0 ]; then
        echo "Failed to update the property."
    else
        echo "Property $property_key updated successfully."
    fi
}

# Function to display menu and perform actions
show_menu() {
    while true; do
        echo ""
        echo "Please select an option:"
        echo "1) List Pods"
        echo "2) List Services"
        echo "3) List Deployments"
        echo "4) List ConfigMaps"
        echo "5) List Routes"
        echo "6) Select and Update Spring Boot Property in ConfigMap"
        echo "7) Change Namespace"
        echo "8) Exit"
        echo ""
        read -p "Enter your choice [1-8]: " choice

        case $choice in
            1)
                echo "Listing all pods in namespace $namespace:"
                oc get pods -n $namespace
                ;;
            2)
                echo "Listing all services in namespace $namespace:"
                oc get services -n $namespace
                ;;
            3)
                echo "Listing all deployments in namespace $namespace:"
                oc get deployments -n $namespace
                ;;
            4)
                echo "Listing all ConfigMaps in namespace $namespace:"
                oc get configmaps -n $namespace
                ;;
            5)
                echo "Listing all routes in namespace $namespace:"
                oc get routes -n $namespace
                ;;
            6)
                select_and_update_property
                ;;
            7)
                echo "Switching namespace..."
                select_namespace
                ;;
            8)
                echo "Exiting script."
                exit 0
                ;;
            *)
                echo "Invalid option. Please select a valid option."
                ;;
        esac
    done
}

# Main script execution
login_to_openshift
select_namespace
show_menu
