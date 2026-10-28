# Jochen Pfeiffer

[Stack Overflow](https://stackoverflow.com/users/676613/jochen)
[LinkedIn](https://www.linkedin.com/in/jochenpfeiffer)

[Get the Shoe](https://www.youtube.com/watch?v=8dU-L88mAcA&list=PLD444B18FA8DA6622)
[Take That Out](https://vimeo.com/161766794?share=copy#t=0)
[Under Prechac](https://vimeo.com/jochenpfeiffer/underprechac?share=copy#t=0)
[Combat Juggling](https://www.youtube.com/watch?v=-joC-UzV0eM&list=PLP71RgSwx-pnzphX852v_R3RfYywxYqsN)

## Pages and the AntiVirus Web app

This public repository hosts the existing homepage and
**https://jjochen.github.io/antivirus-flutter/** on GitHub Pages with GitHub Free.
The Flutter source repository stays private. Flutter/Dart sources, passwords,
build output, and access tokens are not committed here. Public release assets
contain the compiled Web bundle; the password hash and all bundled assets are
publicly downloadable. The app's password prompt is bypassable client-side
visibility protection, not authentication.

### One-time setup

1. In this repository's **Settings → Pages**, select **GitHub Actions** as the
   deployment source. Keep the repository public; no paid plan is required.
2. Configure this repository's **github-pages** environment without required
   reviewers, wait timers, or other approval rules. If limiting deployment
   branches, permit **master**. The workflow's repository-dispatch event runs
   against the default branch, so release tags do not need deployment access.
3. Create a fine-grained personal access token limited to this repository with
   **Contents: Read and write** (Metadata read is implicit). Store it only as
   **PAGES_PUBLISH_TOKEN** in the private source repository's Actions secrets.
   It needs no access to private source code and no workflow/administration
   permission. Replace that secret when rotating or renewing the token.
4. In the private source repository, configure the Actions variable
   **WEB_PASSWORD_SHA256** with the locally generated 64-character SHA-256 hex
   digest. The plaintext password stays outside GitHub.

### Automatic deployment

The private source workflow runs its full quality gates on each `main` push,
including squash merges. It then builds a separate protected production release
with base href `/antivirus-flutter/`, validates its configuration and output,
and publishes `antivirus-web.tar.gz` as a release asset here. Release tags are
`antivirus-<source-run-id>-<source-run-attempt>` so reruns can publish again.
No build products enter either repository's Git history.

Using the restricted publishing token, the source workflow sends the
`antivirus-web-published` repository-dispatch event. The Pages workflow here
downloads the newest matching, published, non-prerelease asset. It copies the
tracked homepage files and inserts the Web build only at `antivirus-flutter/`.
Existing HTML/CSS stay byte-for-byte unchanged. Archives with missing runtime
files, an incorrect base href, source maps, links, or escaping paths fail before
publication. No private-source credentials are used by this public workflow.

After staging tests succeed, official SHA-pinned configure/upload/deploy Pages
actions publish the complete website. Homepage pushes to `master` also rebuild
the combined site using the latest app release. Pull requests run staging tests
and never deploy. No manual deployment approval is required. Before the first
app release exists, only the existing homepage is deployed.

### Password changes, disabling, and recovery

To change the app password, update the hash variable in the private source repo
and push to `main`; an empty commit can trigger the build without a code change.
Changing the variable alone does not rebuild an already published static site.

To disable only the app and preserve the homepage, set this public repository's
Actions variable **ANTIVIRUS_WEB_ENABLED=false** and run the **Pages** workflow
once from the Actions UI on `master`. Future runs keep the app absent until the
variable is restored to `true` or removed and the workflow runs again. Removing
the private hash/publishing token stops new releases but does not unpublish an
existing site. Unpublishing the entire Pages site also removes the homepage.

The latest published matching release is selected at deployment time, including
for retries and homepage pushes. To roll back, unpublish/delete newer matching
releases, then rerun Pages. An old workflow retry will otherwise use the newest
release, avoiding a stale queued deployment overwriting a newer build.

### Local validation

On Linux with Bash, Git, and GNU tar:

```sh
bash -n tool/prepare_pages.sh tool/test_prepare_pages.sh
bash tool/test_prepare_pages.sh

# Stage a tested production archive from the private build (outside Git).
bash tool/prepare_pages.sh /path/to/antivirus-web.tar.gz /tmp/new-pages-output
```

The output directory must not exist. Passing `-` instead of an archive stages
the homepage without the app. The script never modifies tracked website files.
