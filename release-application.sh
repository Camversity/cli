#!/bin/bash

# This script should behave like maven release plugin - merge the current working into master, make sure the version does not contain
# any SNAPSHOT dependencies, perform the release, prepares the next iteration. It supports working in hotfix mode - where
# a patched version is released.

# Exit on any error to avoid troubles.
# Print the statements before running them
set -e

RELEASE_PROCESS_PROPERTIES="release-application.properties"
MAVEN_PROPERTIES="target/maven-archiver/pom.properties"
APPLICATION_PROPERTIES="src/main/resources/application.properties"
APPLICATION_VERSION_PROPERTY="application_version"

extract_property() {
    local PROPERTIES_FILE=$1
    local PROPERTY_NAME=$2
    PROPERTY_VALUE=`grep "^${PROPERTY_NAME}\s*=" "${PROPERTIES_FILE}" | sed "s/${PROPERTY_NAME}\s*=\s*//"`

    if [ -z  ${PROPERTY_VALUE}  ]
    then
        echo "Could not found property '${PROPERTY_NAME}' in file '${PROPERTIES_FILE}'!"
        exit 1
    fi
}

extract_release_branch_var() {
    extract_property ${RELEASE_PROCESS_PROPERTIES} "releaseBranch"
    RELEASE_BRANCH_NAME=${PROPERTY_VALUE}
}

extract_is_hotfix_var() {
    extract_property ${RELEASE_PROCESS_PROPERTIES} "hotfix"
    if [ ${PROPERTY_VALUE} = "yes" ]
    then
        HOTFIX=1
    else
        HOTFIX=0
    fi
}

extract_development_branch_var() {
    extract_property ${RELEASE_PROCESS_PROPERTIES} "developmentBranch"
    DEVELOPMENT_BRANCH_NAME=${PROPERTY_VALUE}

    if [ ${HOTFIX} = 1 ]
    then
        extract_property ${RELEASE_PROCESS_PROPERTIES} "hotfixBranch"
        DEVELOPMENT_BRANCH_NAME=${PROPERTY_VALUE}
    fi
}

extract_build_profile_var() {
    extract_property ${RELEASE_PROCESS_PROPERTIES} "buildProfile"
    BUILD_PROFILE=${PROPERTY_VALUE}
}

extract_application_versions() {

    # Fast build the current application to be able the extract
    # the version and update it to a proper release version
    mvn package -Pfast-unsafe-build

    extract_property ${MAVEN_PROPERTIES} "version"

    local CURRENT_VERSION=`echo ${PROPERTY_VALUE} | sed -r "s/(-SNAPSHOT|-RELEASE)//"`
    RELEASED_VERSION=${CURRENT_VERSION}-RELEASE

    # Extract the versions
    local MAJOR=`echo ${CURRENT_VERSION} | sed -r 's/([0-9]+).([0-9]+).([0-9]+)/\1/'`
    local MINOR=`echo ${CURRENT_VERSION} | sed -r 's/([0-9]+).([0-9]+).([0-9]+)/\2/'`
    local PATCH=`echo ${CURRENT_VERSION} | sed -r 's/([0-9]+).([0-9]+).([0-9]+)/\3/'`

    if [ ${HOTFIX} = 1 ]
    then
        RELEASED_VERSION="${MAJOR}.${MINOR}.$((PATCH+1))-RELEASE"
    else
        NEXT_VERSION="${MAJOR}.$((MINOR+1)).0-SNAPSHOT"
    fi
}

update_version_in_application_properties() {
    if [ -f ${APPLICATION_PROPERTIES} ]
    then
        sed -i.bak -r "s/^${APPLICATION_VERSION_PROPERTY}\s*=\s*.+/${APPLICATION_VERSION_PROPERTY} = $1/" ${APPLICATION_PROPERTIES}
        rm -f ${APPLICATION_PROPERTIES}.bak
        git add ${APPLICATION_PROPERTIES}
    fi
}

update_current_version() {
    local VERSION=$1
    mvn versions:set -DnewVersion=${VERSION}
    git add pom.xml

    update_version_in_application_properties ${VERSION}
}

init_script_variables() {

    extract_release_branch_var

    extract_is_hotfix_var

    extract_development_branch_var

    extract_build_profile_var
}

# Build the release - we will make sure the tests are passing and the build is immutable and repeatable (no snapshots).
build_release_artifact() {

    # First merge the current development branch into release branch
    git checkout ${RELEASE_BRANCH_NAME}
    git merge --no-ff origin/${DEVELOPMENT_BRANCH_NAME} -m "M"

    extract_application_versions

    update_current_version ${RELEASED_VERSION}

    git commit --amend -m "Released version: ${RELEASED_VERSION}."

    # Perform the build.
    mvn clean install -P${BUILD_PROFILE} -DsnapshotsAllowed=true # TODO(cstan) must be set to false!!!
}

# Deploy the released artifact to Nexus
deploy_artifact() {
    mvn deploy -Pfast-unsafe-build
}

# Update the scm state according to our release workflow.
prepare_next_iteration() {

    # Push the changes to remote.
    git push origin "${RELEASE_BRANCH_NAME}"

    # Create a tag of the current release so we will be able to easily perform hotfixes if needed from this point.
    mvn scm:tag -Dtag="v${RELEASED_VERSION}"

    # For hotfixes we won't do anything after the hotfix branch  was merged in the release.
    if [ ${HOTFIX} = 0 ]
    then
        # Move the current development branch on top of the current release checkpoint.
        git checkout ${DEVELOPMENT_BRANCH_NAME}
        git rebase "v${RELEASED_VERSION}"

        # Update the version of the application to the next snapshot - the start of a new iteration.
        update_current_version ${NEXT_VERSION}
        mvn scm:checkin -Dmessage="Init next development iteration: ${NEXT_VERSION}."
    fi
}

### Perform the release
perform_release() {
    init_script_variables

    build_release_artifact

    deploy_artifact

    prepare_next_iteration
}

perform_release
################################

