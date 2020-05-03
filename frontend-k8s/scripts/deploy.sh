#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

### get project dir
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

readonly PROJECT_ROOT="$(dirname $DIR)"
readonly BUILDOUT_DIR=${BUILDOUT_DIR:-"$PROJECT_ROOT/build"}
readonly BUCKET_HOST=${BUCKET_HOST:-""}
readonly APPLICATION_NAME=${APPLICATION_NAME:-"frontendexamples"}
readonly RESOURCES_PREFIX=${RESOURCES_PREFIX:-"wixland/pro"}
readonly BUCKET=${BUCKET:-"bp-stage"}
readonly QINIU_AK=${QINIU_AK:-""}
readonly QINIU_SK=${QINIU_SK:-""}

cd $PROJECT_ROOT
VERSION=""

### application version
get_current_version() {
    if [[ -z "$VERSION" ]]; then
        echo -e "Enter version:" >&2
        read -r VERSION
    fi
    echo $VERSION;
    #echo $(date +%Y%m%d%H%M%S)
}

### build code
build() {
    echo "building..."
    version=${1:-""}
    appVersion=${version} appResourcesPrefix=${RESOURCES_PREFIX} cdnHost=${BUCKET_HOST} yarn build
}

### upload builded code to qiniu cdn
upload() {
    echo "uploading..."
    version=${1:-""}
    /Users/albert/code/github/qiniu-uploader/bin/qiniu-upload.js -r 1 -es 1000000 \
    --verbose -b ${BUCKET} \
    -p "${RESOURCES_PREFIX}/${version}" \
    --base ./build --ak ${QINIU_AK} --sk ${QINIU_SK} 'build/**'
}

### Auto install [qiniu2uploader](https://github.com/work4fun/qiniu-uploader)
### An small resume upload qiniu tools
dectect_autoinstall_qiniu2uploader() {
    if ! [ -x "$(command -v qiniu-upload)" ]; then
        yarn global add -g qiniu2uploader
    fi
}

dectect_autoinstall_qiniu2uploader

version=$(get_current_version)

build $version
upload $version


### Generate helm values.
### Examples:
### cdnHost: "http://bg-stage.wkcoding.com/"
### cdnPrefix: "wixland/pro/20000"
### htmlList: 
###  - /index.html
###
htmlList=""
for html in $(find "$BUILDOUT_DIR" -type f -name "*.html")
do
    ### Replace string
    ### ${content/search/replace}
    html=${html/$BUILDOUT_DIR/''}
    htmlList="- $html
  $htmlList
"
done

cat << EOF > "$PROJECT_ROOT/docker/$APPLICATION_NAME/html.yaml"
# Default values for $APPLICATION_NAME.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.
cdnHost: "https:$BUCKET_HOST"
cdnPrefix: "$RESOURCES_PREFIX/$version"
htmlList: 
  $htmlList
EOF

### deploy with helm
helm upgrade $APPLICATION_NAME ./docker/$APPLICATION_NAME --install --values ./docker/$APPLICATION_NAME/html.yaml