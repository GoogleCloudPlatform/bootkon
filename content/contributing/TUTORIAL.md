# Development Workflow

You want to contribute to bootkon or create your own version? This tutorial is for you.

## Continue in Cloud Shell

Hi, press `START`.

## Authenticate to GitHub

Cloud Shell editor supports authentication to GitHub via an interactive authentication flow.
In this case, you just push your changes and a notification appears to guide you through this process. If you go this route, please continue with **Set up git**.

If, for some reason, this doesn't work for you, you can use the following method:

Create SSH keys if they don't exist yet (just hit return when it asks for passphrases):
```bash
test -f ~/.ssh/id_rsa.pub || ssh-keygen -t rsa
```

Display your newly created SSH key and [add it to your GitHub account](https://github.com/settings/keys):
```bash
cat ~/.ssh/id_rsa.pub
```

Overwrite the remote URL to use the SSH protocol insead of HTTPS. Adjust the command in case you are working on your personal fork:
```bash
git remote set-url origin git@github.com:GoogleCloudPlatform/bootkon.git
```

## Set up git

```bash
git config --global user.name "John Doe"
```
```bash
git config --global user.email johndoe@example.com  
```

Check your git config:
```bash
cat ~/.gitconfig
```

## Pushing to GitHub

You can now commit changes and push them to GitHub. You can either use the version control of the Cloud Shell IDE (tree icon on the left hand side) or the command line:

```bash
git status
```

## Set up your development environment

`. bk` creates `vars.local.sh` from the template `.scripts/vars.template.sh` on
first run and auto-detects your `PROJECT_ID`/`GCP_USERNAME` from Cloud Shell.
`vars.local.sh` is git-ignored, so you never risk committing your project —
never edit the template itself.

To override a detected value (or set `MY_NAME`), <walkthrough-editor-open-file filePath="vars.local.sh">edit `vars.local.sh`</walkthrough-editor-open-file>, then reload:
```bash
. bk
```

It also runs on Argolis (for Google employees). `vars.local.sh` takes precedence
over the template defaults, and every new terminal picks it up automatically via
the block `bk` adds to `~/.bashrc`.

## Test a branch end-to-end

To try your branch the way a participant would — a clean clone and the full
`bk` bootstrap — run the one-liner with your branch in **both** `BK_BRANCH` and
the URL. The stream READMEs hard-code `main`, so you must swap it out:

```bash
BK_BRANCH=<your-branch> BK_STREAM=<stream> BK_REPO=<user>/bootkon; . <(wget -qO- https://raw.githubusercontent.com/${BK_REPO}/${BK_BRANCH}/.scripts/bk)
```

`bk` clones the branch into `~/bootkon`. If `~/bootkon` already exists (your dev
checkout), `bk` reuses it instead of cloning — so for a truly clean test, remove
it first (`rm -rf ~/bootkon`). In your own dev checkout you don't need the
one-liner at all: `git checkout <your-branch>` and run `. bk`. `BK_BRANCH` — and
therefore the rendered image links (`.../blob/<branch>/...`) — follow whatever
the checkout is on, so push image changes before expecting them to render.

## Reloading the tutorial

You can reload a lab on-the-fly by typing `bk-tutorial` followed by the lab markdown file into the terminal and pressing return. Let's reload
this tutorial:
```bash
bk-tutorial docs/book/contributing.md
```