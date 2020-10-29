#!/usr/bin/env bash

set -eo pipefail

if [ ! -d "github_repo_names" ]; then mkdir github_repo_names; fi
if [ ! -d "gitlab_project_ids" ]; then mkdir gitlab_project_ids; fi
if [ ! -d "gitlab_project_urls" ]; then mkdir gitlab_project_urls; fi
if [ ! -d "gitlab_project_visibility" ]; then mkdir gitlab_project_visibility; fi

get-github-repo-names-for-org() {
    declare github_org=${1} page=${2:-1}

    curl -X GET "https://api.github.com/orgs/${github_org}/repos?per_page=100&page=${i}" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        | grep "full_name" | awk -F ': "' '{ print $2 }' \
        | awk -F '"' '{ print $1 }' | awk -F '/' '{ print $2 }' \
        > "github_repo_names/${github_org}${page}.txt"
}

get-all-github-repo-names() {
    for i in {1..$PUBLIC_ORG_PAGINATION}; do
        get-github-repo-names-for-org $PUBLIC_GITLAB_ORG_NAME ${i}
    done
    for i in {1..$PRIVATE_ORG_PAGINATION}; do
        get-github-repo-names-for-org $PRIVATE_GITLAB_ORG_NAME ${i}
    done
}

check-projects-visibility-in-gitlab-group() {
    declare group_name=${1} group_id=${2} page=${3:-1}

    curl --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
        "https://gitlab.com/api/v4/groups/${group_id}/projects?per_page=100&page=${page}&archived=true" \
        | jq -r ".[] | { id, visibility }"
        > "gitlab_project_visibility/${group_name}-project-id-and-visibility${page}.txt"
}

check-all-gitlab-projects-visibility() {
    for i in {1..$PUBLIC_ORG_PAGINATION}; do
        check-projects-visibility-in-gitlab-group $PUBLIC_GITLAB_ORG_NAME $PUBLIC_GITLAB_ORG_ID ${i}
    done
    for i in {1..$PRIVATE_ORG_PAGINATION}; do
        check-projects-visibility-in-gitlab-group $PRIVATE_GITLAB_ORG_NAME $PRIVATE_GITLAB_ORG_ID ${i}
    done
}

get-project-ids-in-gitlab-group() {
    declare group_name=${1} group_id=${2} page=${3:-1}

    curl --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
        "https://gitlab.com/api/v4/groups/${group_id}/projects?per_page=100&page=${page}&archived=true" \
        | jq -r ".[] | { id }" | grep "id" | awk -F ': ' '{ print $2 }' \
        > "gitlab_project_ids/${group_name}-project-ids${page}.txt"
}

get-all-gitlab-project-ids() {
    for i in {1..$PUBLIC_ORG_PAGINATION}; do
        get-project-ids-in-gitlab-group $PUBLIC_GITLAB_ORG_NAME $PUBLIC_GITLAB_ORG_ID ${i}
    done
    for i in {1..$PRIVATE_ORG_PAGINATION}; do
        get-project-ids-in-gitlab-group $PRIVATE_GITLAB_ORG_NAME $PRIVATE_GITLAB_ORG_ID ${i}
    done
}

update-projects-visibility-in-gitlab-group() {
    declare group_name=${1} visibility=${2:-public} page=${3:-1}

    for repo_id in $(cat "gitlab_project_ids/${group_name}-project-ids${page}.txt"); do
        curl -X PUT --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
            "https://gitlab.com/api/v4/projects/${repo_id}?visibility=${visibility}&archived=true"
    done
}

update-all-gitlab-projects-visibility() {
    declare visibility=${1:-public}

    for i in {1..$PUBLIC_ORG_PAGINATION}; do
        update-projects-visibility-in-gitlab-group $PUBLIC_GITLAB_ORG_NAME ${visibility} ${i}
    done
    for i in {1..$PRIVATE_ORG_PAGINATION}; do
        update-projects-visibility-in-gitlab-group $PRIVATE_GITLAB_ORG_NAME ${visibility} ${i}
    done
}

update-projects-archive-status-in-gitlab-group() {
    declare group_name=${1} archive=${2:-unarchive} page=${3:-1}

    for repo_id in $(cat "gitlab_project_ids/${group_name}-project-ids${page}.txt"); do
        curl -X POST --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
            "https://gitlab.com/api/v4/projects/${repo_id}/${archive}"
    done
}
update-all-gitlab-projects-archive-status() {
    declare archive=${1:-unarchive}

    for i in {1..$PUBLIC_ORG_PAGINATION}; do
        update-projects-archive-status-in-gitlab-group $PUBLIC_GITLAB_ORG_NAME ${archive} ${i}
    done
    for i in {1..$PRIVATE_ORG_PAGINATION}; do
        update-projects-archive-status-in-gitlab-group $PRIVATE_GITLAB_ORG_NAME ${archive} ${i}
    done
}

get-clone-urls-for-gitlab-group() {
    declare group_name=${1} group_id=${2} page=${3:-1}

    curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "https://gitlab.com/api/v4/groups/${group_id}/projects?per_page=100&page=${page}&archived=yes" \
        | jq -r ".[] | { http_url_to_repo }" | grep "http_url_to_repo" \
        | awk -F ': "' '{ print $2 }' | awk -F '"' '{ print $1 }' \
        > "gitlab_project_urls/${group_name}-project-http-urls${page}.txt"
}

get-all-gitlab-clone-urls() {
    for i in {1..$PUBLIC_ORG_PAGINATION}; do
        get-clone-urls-for-gitlab-group $PUBLIC_GITLAB_ORG_NAME $PUBLIC_GITLAB_ORG_ID ${i}
    done
    for i in {1..$PRIVATE_ORG_PAGINATION}; do
        get-clone-urls-for-gitlab-group $PRIVATE_GITLAB_ORG_NAME $PRIVATE_GITLAB_ORG_ID ${i}
    done
}

clone-gitlab-repos-in-org() {
    declare group_name=${1} page=${2:-1}

    if [ ! -d "${group_name}" ]; then mkdir "${group_name}"; fi

    pushd "${group_name}"
    for url in $(cat "../gitlab_project_urls/${group_name}-project-http-urls${page}.txt"); do
        git clone "${url}"
    done
    popd
}

clone-all-gitlab-repos() {
    for i in {1..$PUBLIC_ORG_PAGINATION}; do
        clone-gitlab-repos-in-org $PUBLIC_GITLAB_ORG_NAME ${i}
    done
    for i in {1..$PRIVATE_ORG_PAGINATION}; do
        clone-gitlab-repos-in-org $PRIVATE_GITLAB_ORG_NAME ${i}
    done
}

check-cloned-repos-in-gitlab-group() {
    declare group_dir=$1

    for repo_dir in $(ls ${group_dir}); do
        if [[ -z "$(ls ${group_dir}/${repo_dir})" ]]; then
            printf "\t${repo_dir} is empty, changes are it failed to import.\n"
        fi
    done
}

check-all-gitlab-repos() {
    declare gitlab_groups=(
        my-public-org
        my-private-org
    )
    for gitlab_group in ${gitlab_groups[@]}; do
        echo "Checking in ${gitlab_group}"
        check-cloned-repos-in-gitlab-group ${gitlab_group}
    done
}

"$@"
