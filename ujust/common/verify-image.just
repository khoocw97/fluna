# Re-record the booted image as signature-verified. No-op when it already is.
verify-image:
    #!/usr/bin/bash
    # Modelled on Bazzite's ujust verify-image: detect an unverified deployment,
    # show the target, confirm, then rebase it to the signed ref. bootc has no
    # ostree-unverified-registry/ostree-image-signed string to rewrite (those
    # prefixes live in the origin file), so the equivalent switch is used here.
    set -euo pipefail

    echo "Checking image verification status..."

    # Nothing is hardcoded: the image and its state come from the booted
    # deployment, and the policy file says whether the repository has a key.
    status=$(sudo bootc status --format json)
    ref=$(jq -r '.status.booted.image.image.image // empty' <<<"${status}")
    signature=$(jq -r '.status.booted.image.image.signature // empty' <<<"${status}")
    if [[ -z ${ref} ]]; then
        echo "No container image is booted."
        exit 1
    fi

    # Repository part of the ref: strip digest, then tag (only after the last
    # slash, so registry ports stay intact).
    repo="${ref%@*}"
    [[ ${repo##*/} == *:* ]] && repo="${repo%:*}"

    key=$(jq -r --arg r "${repo}" \
        '(.transports.docker[$r] // [])[] | select(.type == "sigstoreSigned") | .keyPath' \
        /etc/containers/policy.json | head -n1)

    if [[ ${signature} == "containerPolicy" ]]; then
        echo "System is already verified: ${ref}"
        exit 0
    fi
    if [[ -z ${key} ]]; then
        echo "No signature policy covers ${repo}, so there is nothing to verify against."
        exit 1
    fi

    echo "UNVERIFIED IMAGE DETECTED"
    echo "Current: ${ref}"
    echo "Key:     ${key}"
    echo ""
    echo "This will re-record the image as signed, so you receive verified updates."
    echo ""

    read -p "Proceed with switch? [y/N] " -n 1 -r
    echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    sudo bootc switch --enforce-container-sigpolicy "${ref}"
    echo "Queued. Reboot to boot the verified deployment."
