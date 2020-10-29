.DEFAULT_GOAL := help

help: ## Shows this help text
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-41s\033[0m %s\n", $$1, $$2}'

get-all-github-repo-names: ## Outputs GitHub repos to `github_repo_names` dir
	./migration-scripts.bash get-all-github-repo-names

check-all-gitlab-projects-visibility: ## Outputs GitLab projects' visibility status to `gitlab_project_visibility` dir
	./migration-scripts.bash check-all-gitlab-projects-visibility

get-all-gitlab-project-ids: ## Outputs GitLab project IDs in `gitlab_project_ids` dir
	./migration-scripts.bash get-all-gitlab-project-ids

update-all-gitlab-projects-visibility: ## Sets GitLab projects' visibility (default is `public`)
	./migration-scripts.bash update-all-gitlab-projects-visibility

update-all-gitlab-projects-archive-status: ## Sets GitLab projects' archive status (default is `unarchive`)
	./migration-scripts.bash update-all-gitlab-projects-archive-status

get-all-gitlab-clone-urls: ## Outputs GitLab to `gitlab_project_urls` dir
	./migration-scripts.bash get-all-gitlab-clone-urls

clone-all-gitlab-repos: ## Clones all migrated projects
	./migration-scripts.bash clone-all-gitlab-repos

check-all-gitlab-repos: ## Checks that all migrated projects can be cloned locally
	./migration-scripts.bash check-all-gitlab-repos

.PHONY: help
