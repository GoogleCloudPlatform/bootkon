```bash
MY_NAME=""     # your (first) name, shown in the greeting (optional)
BK_STREAM=example BK_REPO=GoogleCloudPlatform/bootkon; . <(wget -qO- https://raw.githubusercontent.com/${BK_REPO}/main/.scripts/bk \
   || echo 'echo "ERROR: could not download bootkon — check your network and paste the command again, or ask the event staff." >&2')
```