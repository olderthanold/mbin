#!/usr/bin/env bash
# ociamp2.sh v02
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SSH_AUTHORIZED_KEYS_FILE="${SSH_AUTHORIZED_KEYS_FILE:-/m/mbin/old.pub}"

echo -e "${YELLOW}Running ociamp2.sh v02${NC}"

if ! command -v oci >/dev/null 2>&1; then
    echo -e "${RED}Error: OCI CLI command not found: oci${NC}"
    exit 1
fi

if [[ ! -r "$SSH_AUTHORIZED_KEYS_FILE" ]]; then
    echo -e "${RED}Error: SSH public key file not readable: $SSH_AUTHORIZED_KEYS_FILE${NC}"
    exit 1
fi

# Define the availability domains ----------------------------------------- <UPDATE> -------------------------------------------
AD1="sYfx:EU-FRANKFURT-1-AD-1"
AD2="sYfx:EU-FRANKFURT-1-AD-2"
AD3="sYfx:EU-FRANKFURT-1-AD-3"

# Array to hold availability domains
AVAILABILITY_DOMAINS=("$AD1" "$AD2" "$AD3")

# Loop indefinitely until a command succeeds
while true; do
    for AVAILABILITY_DOMAIN in "${AVAILABILITY_DOMAINS[@]}"; do
        echo "Attempting to launch instance in Availability Domain: $AVAILABILITY_DOMAIN"
        # ------------------------------------------------------------ <UPDATE AS NECESSARY> ------------------------------------
        oci compute instance launch \
            --availability-domain "$AVAILABILITY_DOMAIN" \
            --compartment-id "ocid1.compartment.oc1..aaaaaaaab5nd5rc7djycod3f2xmoyclydn3j4mwtd3bsaakhs66yeyvxe4aq" \
            --shape "VM.Standard.A1.Flex" \
            --subnet-id "ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaaa4gjmklnvy4cwguyj5txtgj4epkd27xtwaja5iuwwtzkdsylomma" \
            --assign-private-dns-record true \
            --assign-public-ip true \
            --agent-config '{"is_management_disabled": false, "is_monitoring_disabled": false, "plugins_config": [
                {"desired_state": "DISABLED", "name": "Vulnerability Scanning"},
                {"desired_state": "DISABLED", "name": "Management Agent"},
                {"desired_state": "ENABLED", "name": "Custom Logs Monitoring"},
                {"desired_state": "DISABLED", "name": "Compute RDMA GPU Monitoring"},
                {"desired_state": "ENABLED", "name": "Compute Instance Monitoring"},
                {"desired_state": "DISABLED", "name": "Compute HPC RDMA Auto-Configuration"},
                {"desired_state": "DISABLED", "name": "Compute HPC RDMA Authentication"},
                {"desired_state": "ENABLED", "name": "Cloud Guard Workload Protection"},
                {"desired_state": "DISABLED", "name": "Block Volume Management"},
                {"desired_state": "DISABLED", "name": "Bastion"}]}' \
            --availability-config '{"recovery_action": "RESTORE_INSTANCE"}' \
            --display-name "amp" \
            --image-id "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaasoblespfnzqa67jnq4psbpnbal4mlh2tpwnlhnhvmkhzuqbrxu4a" \
            --instance-options '{"are_legacy_imds_endpoints_disabled": false}' \
            --shape-config '{"memory_in_gbs": 24, "ocpus": 4}' \
            --ssh-authorized-keys-file "$SSH_AUTHORIZED_KEYS_FILE"
            #--ssh-authorized-keys "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGuCF0uiflr/lzzD8Ha5VPKhMt9O7BGl4uwrV2TFnjDq"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Instance created successfully in $AVAILABILITY_DOMAIN.${NC}"
            exit 0  # Exit the script after successful execution
        else
            echo -e "${YELLOW}Failed to launch instance in $AVAILABILITY_DOMAIN. Trying the next one...${NC}"
            sleep 3  # Wait 3 seconds before trying the next domain
        fi
    done
done
