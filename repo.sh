#!/usr/bin/env bash

set -e
set -o pipefail

# Script for Git repos housing edX services. These repos are mounted as
# data volumes into their corresponding Docker containers to facilitate development.
# Repos are cloned to/removed from the directory above the one housing this file.

if [ -z "$DEVSTACK_WORKSPACE" ]; then
    echo "need to set workspace dir"
    exit 1
elif [ -d "$DEVSTACK_WORKSPACE" ]; then
    cd "$DEVSTACK_WORKSPACE"
else
    echo "Workspace directory $DEVSTACK_WORKSPACE doesn't exist"
    exit 1
fi

OPENEDX_GIT_BRANCH=open-release/juniper.3

APPSEMBLER_EDX_PLATFORM_BRANCH="main"
AMC_BRANCH="develop"
PLATFORM_THEMES_DIR="${DEVSTACK_WORKSPACE}/edx-themes/edx-platform"
THEME_CODEBASE_BRANCH="juniper/main"
THEME_CUSTOMERS_BRANCH="juniper/tahoe"

# When you add new services should add them to both repos and ssh_repos
# (or non_release_repos and non_release_ssh_repos if they are not part
# of Open edX releases).

repos=(
    "https://github.com/edx/course-discovery.git"
    "https://github.com/edx/credentials.git"
    "https://github.com/edx/cs_comments_service.git"
    "https://github.com/edx/ecommerce.git"
    "https://github.com/edx/edx-e2e-tests.git"
    "https://github.com/edx/edx-notes-api.git"
    "git@github.com:appsembler/amc.git"
    "git@github.com:appsembler/edx-theme-codebase.git"
    "git@github.com:appsembler/edx-theme-customers.git"
    "git@github.com:appsembler/edx-platform.git"
    "git@github.com:appsembler/edxapp-envs.git"
    "https://github.com/edx/xqueue.git"
    "https://github.com/edx/edx-analytics-pipeline.git"
    "https://github.com/edx/frontend-app-gradebook.git"
    "https://github.com/edx/frontend-app-publisher.git"
)

non_release_repos=(
    "https://github.com/edx/frontend-app-learning.git"
    "https://github.com/edx/registrar.git"
    "https://github.com/edx/frontend-app-program-console.git"
)

ssh_repos=(
    "git@github.com:edx/course-discovery.git"
    "git@github.com:edx/credentials.git"
    "git@github.com:edx/cs_comments_service.git"
    "git@github.com:edx/ecommerce.git"
    "git@github.com:edx/edx-e2e-tests.git"
    "git@github.com:edx/edx-notes-api.git"
    "git@github.com:appsembler/edx-platform.git"
    "git@github.com:appsembler/edxapp-envs.git"
    "git@github.com:edx/xqueue.git"
    "git@github.com:edx/edx-analytics-pipeline.git"
    "git@github.com:edx/frontend-app-gradebook.git"
    "git@github.com:edx/frontend-app-publisher.git"
)

non_release_ssh_repos=(
    "git@github.com:edx/frontend-app-learning.git"
    "git@github.com:edx/registrar.git"
    "git@github.com:edx/frontend-app-program-console.git"
)

private_repos=(
    # Needed to run whitelabel tests.
    "https://github.com/edx/edx-themes.git"
)

if [ -n "${OPENEDX_RELEASE}" ]; then
    OPENEDX_GIT_BRANCH=open-release/${OPENEDX_RELEASE}
else
    OPENEDX_GIT_BRANCH=master
    repos+=("${non_release_repos[@]}")
    ssh_repos+=("${non_release_ssh_repos[@]}")
fi

name_pattern=".*(edx|appsembler)/(.*).git"

_checkout ()
{
    repos_to_checkout=("$@")

    for repo in "${repos_to_checkout[@]}"
    do
        # Use Bash's regex match operator to capture the name of the repo.
        # Results of the match are saved to an array called $BASH_REMATCH.
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[2]}"
        # If a directory exists and it is nonempty, assume the repo has been cloned.
        if [ -d "$name" ] && [ -n "$(ls -A "$name" 2>/dev/null)" ]; then
            echo "Checking out branch of $name"
            cd "$name"
            _appsembler_checkout_and_update_branch "$name"
            cd ${DEVSTACK_WORKSPACE}
        elif [ "$name" == "edxapp-envs" ] && [ -d "src/edxapp-envs/.git" ]; then
            echo "Checking out branch ${OPENEDX_GIT_BRANCH} of $name"
            cd src/edxapp-envs
            _appsembler_checkout_and_update_branch "$name"
            cd ${DEVSTACK_WORKSPACE}
        elif [ "$name" == "edx-theme-codebase" ] && [ -d "edx-themes/edx-platform/edx-theme-codebase/.git" ]; then
            echo "Checking out branch of $name"
            mkdir -p "${DEVSTACK_WORKSPACE}/edx-themes/edx-platform"
            cd edx-themes/edx-platform/edx-theme-codebase
            _appsembler_checkout_and_update_branch "$name"
            cd ${DEVSTACK_WORKSPACE}
        elif [ "$name" == "edx-theme-customers" ] && [ -d "edx-themes/edx-platform/edx-theme-codebase/customer_specific/.git" ]; then
            echo "Checking out branch of $name"
            mkdir -p "${DEVSTACK_WORKSPACE}/edx-themes/edx-platform"
            cd edx-themes/edx-platform/edx-theme-codebase/customer_specific
            _appsembler_checkout_and_update_branch "$name"
            cd ${DEVSTACK_WORKSPACE}
        fi
    done
}

checkout ()
{
    _checkout "${repos[@]}"
}

_clone ()
{

    repos_to_clone=("$@")
    for repo in "${repos_to_clone[@]}"
    do
        # Use Bash's regex match operator to capture the name of the repo.
        # Results of the match are saved to an array called $BASH_REMATCH.
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[2]}"

        # If a directory exists and it is nonempty, assume the repo has been checked out
        # and only make sure it's on the required branch
        if [ -d "$name" ] && [ -n "$(ls -A "$name" 2>/dev/null)" ]; then
            if [ ! -d "$name/.git" ]; then
                printf "ERROR: [%s] exists but is not a git repo.\n" "$name"
                exit 1
            fi
            printf "The [%s] repo is already checked out. Checking for updates.\n" "$name"
            cd "${DEVSTACK_WORKSPACE}/${name}"
            _appsembler_checkout_and_update_branch $name
            cd ..
        elif [ "$name" == "edx-theme-customers" ] && [ -d "edx-theme-codebase/customer_specific/.git" ]; then
            printf "The [%s] repo is already checked out. Checking for updates.\n" "$name"
            cd "${DEVSTACK_WORKSPACE}/edx-theme-codebase/customer_specific"
            _appsembler_checkout_and_update_branch $name
            cd "${DEVSTACK_WORKSPACE}"
        elif [ "$name" == "edxapp-envs" ] && [ -d "src/edxapp-envs/.git" ]; then
            printf "The [%s] repo is already checked out. Checking for updates.\n" "$name"
            cd "${DEVSTACK_WORKSPACE}/src/edxapp-envs"
            _appsembler_checkout_and_update_branch "$name"
            cd "${DEVSTACK_WORKSPACE}"
        else
            if [ "$name" == "edx-platform" ]; then
                git clone -b ${APPSEMBLER_EDX_PLATFORM_BRANCH} -c core.symlinks=true ${repo}
            elif [ "$name" == "amc" ]; then
                git clone -b ${AMC_BRANCH} -c core.symlinks=true ${repo}
            elif [ "$name" == "edx-theme-codebase" ]; then
                mkdir -p "${PLATFORM_THEMES_DIR}"
                cd "${PLATFORM_THEMES_DIR}"
                sudo rm -rf edx-theme-codebase  # Clean up stale/broken repo
                git clone -b ${THEME_CODEBASE_BRANCH} -c core.symlinks=true ${repo}
                cd "${DEVSTACK_WORKSPACE}"
            elif [ "$name" == "edx-theme-customers" ]; then
                cd "${DEVSTACK_WORKSPACE}/edx-theme-codebase"
                sudo rm -rf customer_specific  # Clean up stale/broken repo
                git clone -b ${THEME_CUSTOMERS_BRANCH} -c core.symlinks=true ${repo} customer_specific
                cd "${DEVSTACK_WORKSPACE}"
            elif [ "$name" == "edxapp-envs" ]; then
                sudo rm -rf "${DEVSTACK_WORKSPACE}/src/edxapp-envs"
                git clone -b ${OPENEDX_GIT_BRANCH} -c core.symlinks=true ${repo} "${DEVSTACK_WORKSPACE}/src/edxapp-envs"
            else
                if [ "${SHALLOW_CLONE}" == "1" ]; then
                    git clone --single-branch -b ${OPENEDX_GIT_BRANCH} -c core.symlinks=true --depth=1 ${repo}
                else
                    git clone --single-branch -b ${OPENEDX_GIT_BRANCH} -c core.symlinks=true ${repo}
                fi
            fi
        fi
    done
    cd - &> /dev/null
}

_checkout_and_update_branch ()
{
    GIT_SYMBOLIC_REF="$(git symbolic-ref HEAD 2>/dev/null)"
    BRANCH_NAME=${GIT_SYMBOLIC_REF##refs/heads/}
    if [ "${BRANCH_NAME}" == "${OPENEDX_GIT_BRANCH}" ]; then
        git pull origin ${OPENEDX_GIT_BRANCH}
    else
        git fetch origin ${OPENEDX_GIT_BRANCH}:${OPENEDX_GIT_BRANCH}
        git checkout ${OPENEDX_GIT_BRANCH}
    fi
    find . -name '*.pyc' -not -path './.git/*' -delete
}

# our version to handle the fact that both edx-platform and AMC need
# different branches, not `master`
_appsembler_checkout_and_update_branch ()
{
    repo="$1"
    if [ "${repo}" == "edx-platform" ]; then
        OPENEDX_GIT_BRANCH="${APPSEMBLER_EDX_PLATFORM_BRANCH}" _checkout_and_update_branch
    elif [ "${repo}" == "amc" ]; then
        OPENEDX_GIT_BRANCH="${AMC_BRANCH}" _checkout_and_update_branch
    elif [ "${repo}" == "edx-theme-codebase" ]; then
        OPENEDX_GIT_BRANCH="${THEME_CODEBASE_BRANCH}" _checkout_and_update_branch
    elif [ "${repo}" == "edx-theme-customers" ]; then
        OPENEDX_GIT_BRANCH="${THEME_CUSTOMERS_BRANCH}" _checkout_and_update_branch
    else
        # default to the old behavior
        _checkout_and_update_branch
    fi
}

clone ()
{
    _clone "${repos[@]}"
}

clone_ssh ()
{
    _clone "${ssh_repos[@]}"
}

clone_private ()
{
    _clone "${private_repos[@]}"
}

reset ()
{
    currDir=$(pwd)
    for repo in ${repos[*]}
    do
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[2]}"

        if [ -d "$name" ]; then
            if [ "$name" == "edx-platform" ]; then
                cd $name;git reset --hard HEAD;git checkout ${APPSEMBLER_EDX_PLATFORM_BRANCH};git reset --hard origin/${APPSEMBLER_EDX_PLATFORM_BRANCH};git pull;cd "$currDir"
            elif [ "$name" == "edx-theme-codebase" ]; then
                cd $name;git reset --hard HEAD;git checkout ${THEME_CODEBASE_BRANCH};git reset --hard origin/${THEME_CODEBASE_BRANCH};git pull;cd "$currDir"
            elif [ "$name" == "edx-theme-customers" ]; then
                cd edx-theme-codebase/customer_specific;git reset --hard HEAD;git checkout ${THEME_CUSTOMERS_BRANCH};git reset --hard origin/${THEME_CUSTOMERS_BRANCH};git pull;cd "$currDir"
            elif [ "$name" == "edxapp-envs" ]; then
                cd src/edxapp-envs;git reset --hard HEAD;git checkout ${OPENEDX_GIT_BRANCH};git reset --hard origin/${OPENEDX_GIT_BRANCH};git pull;cd "$currDir"
            elif [ "$name" == "amc" ]; then
                cd $name;git reset --hard HEAD;git checkout ${AMC_BRANCH};git reset --hard origin/${AMC_BRANCH};git pull;cd "$currDir"
            else
                cd $name;git reset --hard HEAD;git checkout ${OPENEDX_GIT_BRANCH};git reset --hard origin/open-release/juniper.master;git pull;cd "$currDir"
            fi
        else
            printf "The [%s] repo is not cloned. Continuing.\n" "$name"
        fi
    done
    cd - &> /dev/null
}

status ()
{
    currDir=$(pwd)
    for repo in ${repos[*]}
    do
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[2]}"

        if [ -d "$name" ]; then
            printf "\nGit status for [%s]:\n" "$name"
            cd "$name";git status;cd "$currDir"
        else
            printf "The [%s] repo is not cloned. Continuing.\n" "$name"
        fi
    done
    cd - &> /dev/null
}

if [ "$1" == "checkout" ]; then
    checkout
elif [ "$1" == "clone" ]; then
    clone
elif [ "$1" == "clone_ssh" ]; then
    clone_ssh
elif [ "$1" == "whitelabel" ]; then
    clone_private
elif [ "$1" == "reset" ]; then
    read -p "This will override any uncommited changes in your local git checkouts. Would you like to proceed? [y/n] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reset
    fi
elif [ "$1" == "status" ]; then
    status
fi
