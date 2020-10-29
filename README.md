# GitHub to GitLab Migration

A set of script to help automate bulk transfer of GitHub repositories to GitLab.

## Overview

Use these scripts when migrating a large number of repos. The scripts work across GitHub organizations, as long as the GitHub has access to them.

The Make targets are structured in the sequence they should be run. Follow the steps below to understand how to execute.

## Prerequisites

1. Export env var `GITHUB_TOKEN` with admin access to all GitHub repos.
1. Export env var `GITLAB_TOKEN` with ability to create new groups.

## Terminology

- GitHub organization == GitLab group.
- GitHub repository == GitLab project.

## Steps

1. Prepare a list of all repositories that are to be migrated.
1. Prepare GitLab for the migration.
1. Migrate the repositories.
1. Update migrated repos to desired state.
1. Validate the migration.
1. Lock down GitHub access.

## 1. Prepare a list of all repositories that are to be migrated

Get a GitHub token which has access to all GitHub orgs (and hence the repos in the orgs to migrate). In the exampe these step follow, we'll have 2 orgs:

1. my-public-org
1. my-private-org

Export env var for the number of repos in each GitHub divided by max number of repos that GitHub/GitLab APIs can retrieve (100). The example in the steps below migrates 2 orgs, so that vars would look like this:

1. If public org has 2074 repos, `export PUBLIC_ORG_PAGINATION=21`
1. If private org has 374 repos, `export PRIVATE_ORG_PAGINATION=4`

> Modify `get-all-github-repo-names` bash function to add more for loops for GitHub orgs.

Get the list of all repos:

```bash
make get-all-github-repo-names
```

Output is stored in the `github_repo_names` folder.

## 2. Prepare GitLab for the migration

1. (Optional) Create the top-level `migrated` group in GitLab.
1. Create sub-groups under the `migrated` group.
   1. Follow the structure of GitHub orgs or another structure.
1. Export env vars for the names and IDs of the groups. The migration scripts make use of those.
   1. Export names:
      1. `export PUBLIC_GITLAB_ORG_NAME=my-public-org`
      1. `export PRIVATE_GITLAB_ORG_NAME=my-private-org`
   1. Export IDs:
      1. `export PUBLIC_GITLAB_ORG_ID=10`
      1. `export PRIVATE_GITLAB_ORG_ID=11`

## 3. Migrate the repositories

GitLab does not have the functionality of migrating repos per org, so there's a bit of work involved when doing a mass migration, while keeping the repos separated appropriately.

Navigate to GitLab's [Import repositories from GitHub][].

Select the destination of all repos. This is done from the dropdown next to each repo.

If you have hundreds of repos, use the `gitlab-ui-import-by-org.js` script to select the destinations.

The script:

1. Loops through all GitHub repos on the page.
2. Updates the GitLab group dropdown based on what the GitHub repo's org.

For example, all repos in `my-public-org` GitHub org will be moved to the `migrated/my-public-org` GitLab group.

> If you didn't create a top-level `migrated` GitLab group, update the `gitlabOwner` var in the script.

1. Run the script (paste into the browser console).
2. Validate the GitLab destination groups were updated correctly.
3. Click `Import all repositories`.

> Note that if you have over 1000 repositories, the migration may take up to an hour or more to complete.

## 4. Update migrated repos to desired state

The migration preserves the state of repositories, including their visibility status. In our use case, we wanted all migrated repos to be Public. Use GitLab API to update all repo's `visibility` property to be `public`. The following set of scripts accomplishes this.

> Modify `check-all-gitlab-projects-visibility` function to add more for loops for each GitLab org.

```bash
make check-all-gitlab-projects-visibility
```

Use `get-all-gitlab-project-ids` function to do a manual visual scan of project visibilities in GitLab groups. If any are set to something other than `public`, run the `update-all-gitlab-projects-visibility` script.

> Modify `get-all-gitlab-project-ids` function to add more for loops for each GitLab org.

```bash
make get-all-gitlab-project-ids
```

This script is a prerequisite to running `update-all-gitlab-projects-visibility`. Loops through the specified subgroups and outputs all project IDs in `gitlab_project_ids` folder, grouped by group (no pun intended).

> Modify `update-all-gitlab-projects-visibility` function to add more for loops for each GitLab org.

```bash
make update-all-gitlab-projects-visibility
```

`update-all-gitlab-projects-visibility` grabs the projects IDs produced by the `get-all-gitlab-project-ids` script and sets the visibility of those projects to the specified value (default is `public`).

(Optional) Archive migrated projects, so that they are explicitly read-only.

> Archived projects will still appear when searching ([until further notice](https://gitlab.com/gitlab-org/gitlab-ce/issues/32806)). Archived project don't appear when browsing the `archive` group. You need to click `Archived projects` tab to view them.

```bash
make update-all-gitlab-projects-archive-status archive
```

## 5. Validate the migration

The migration has been known to error out at times. The error encountered so far are:

1. Project shows this error on the screen: `The repository for this project does not exist.` [GitLab issue 40953][].
2. Migration hangs, but in actuality completes successfully.
3. GitHub orgs with leading dots `.` fail (GitLab limitation).

In order to validate that the repos migrated successfully, you can clone each new GitLab project and validate that the files are on the local filesystem. The scripts take such "user validation" approach, because there does not seem to be a good way to validate projects' integrity (beyond a generic `git fsck` in [application settings][]).

`get-all-gitlab-clone-urls` outputs all GitLab project URLs to the `gitlab_project_urls` folder.

> `http_url_to_repo` is used instead of `ssh_url_to_repo`. You might want to use SSH.

```bash
make get-all-gitlab-clone-urls
```

`clone-all-gitlab-repos` clones all GitLab projects in the specified groups. Watch out for any warning in the terminal while this is running. If there are any `fatal` error messages during cloning, that means that repo wasn't migrated correctly.

```bash
make clone-all-gitlab-repos
```

`check-all-gitlab-repos` `cd`s into each cloned project and prints out a warning if the project folder structure is empty. Note that there could be false negatives (since some GitHub repos can be empty).

```bash
make check-all-gitlab-repos
```

## 6. Lock down GitHub access

The last step is to make sure that no new repos are added to GitHub. This is done by:

1. Navigating to `/settings/member_privileges` page of each GitHub org.
2. Disabling `Repository creation` and `Repository forking` options.

[application settings]: https://gitlab.com/admin/application_settings
[gitlab issue 40953]: https://gitlab.com/gitlab-org/gitlab-ce/issues/40953
[import repositories from github]: https://gitlab.com/import/github/status
