#!/bin/bash

check () {
  retval=$1
  if [ $retval -ne 0 ]; then
    >&2 echo "Return code was not zero but $retval"
    exit 999
  fi
}
MESSAGE=$(git log -1 --pretty=%B)
echo Last commit message is "'"$MESSAGE"'"
RELEASE_DIR="$HOME/transempregos-portal-release"
echo Release dir is "'"$RELEASE_DIR"'".
shopt -s extglob #enable globbing
shopt extglob

dev() {
  #last commit message:
  if [ -d "$RELEASE_DIR" ]; then
    echo Deleting release dir "'"$RELEASE_DIR"'"...
    rm -rf "$RELEASE_DIR"
  fi
  echo Cloning to "'"$RELEASE_DIR"'"...
  git clone --depth 10 --no-single-branch git@github.com:TransEmpregos/transempregos-portal-release.git "$RELEASE_DIR"
  check $?
  echo Deleting old files...
  cd $RELEASE_DIR
  rm !(.git|.|..) -rf
  check $?
  if [ ! -d dist ]; then
    mkdir dist
  fi
  echo Copying release files from "'"$SNAP_WORKING_DIR"'" to "'"$RELEASE_DIR"'"...
  cp -R "$SNAP_WORKING_DIR/dist/." "$RELEASE_DIR/dist/"
  check $?
  cp "$SNAP_WORKING_DIR/package.json" "$RELEASE_DIR/package.json"
  check $?
  echo Adding files to git...
  git add -A
  check $?
  if [[ $(git status -s) ]]; then
    echo Adding version file...
    echo '{ "buildNumber":'" $SNAP_PIPELINE_COUNTER, "'"commit": "'"$SNAP_COMMIT"'" }' > dist/public/version.json
    git add -A
    echo Committing...
    git commit -m "#$SNAP_PIPELINE_COUNTER $MESSAGE
  Original commit: $SNAP_COMMIT
  https://github.com/TransEmpregos/transempregos-portal/commit/$SNAP_COMMIT
  On Branch: $SNAP_BRANCH"
    check $?
    echo Pushing files to git...
    git push origin master
    check $?
  fi
}

staging() {
  cd $RELEASE_DIR
  check $?
  echo Finding original commit...
  ORIGINAL_COMMIT=$(git log --grep="Original commit: $SNAP_COMMIT" --format=format:%H)
  check $?
  echo Checking out staging branch...
  git checkout staging
  check $?
  echo Pulling staging branch...
  git pull --ff-only origin staging
  check $?
  echo Merging $ORIGINAL_COMMIT commit - from master - into staging...
  git merge --ff-only $ORIGINAL_COMMIT
  check $?
  echo Pushing staging branch...
  git push origin staging
  check $?
  echo Pushed!
}

prod() {
  cd $RELEASE_DIR
  check $?
  echo Finding original commit...
  ORIGINAL_COMMIT=$(git log --grep="Original commit: $SNAP_COMMIT" --format=format:%H)
  check $?
  echo Checking out staging branch...
  git checkout prod
  check $?
  echo Pulling staging branch...
  git pull --ff-only origin prod
  check $?
  echo Merging $ORIGINAL_COMMIT commit - from staging - into prod...
  git merge --ff-only $ORIGINAL_COMMIT
  check $?
  echo Pushing staging branch...
  git push origin prod
  check $?
  echo Pushed!
}

while getopts ":dsp" opt; do
  case $opt in
    d)
      dev
      exit 0
      ;;
    s)
      staging
      exit 0
      ;;
    p)
      prod
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
echo "No option supplied." >&2
exit 1
