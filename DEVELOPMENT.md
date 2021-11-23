## Multi-base-image variants

The [docker-versions-create.sh](docker-versions-create.sh) script is configured with the branches to maintain and is used to merge changes from the master branch into the mulit-base variant branches. The script also manages git tagging the master branch along with the merged branches. So a typical use of the script would be like:

```shell script
./docker-versions-create.sh -s -t 1.2.0
```

> Most often the major version will be bumped unless a bug or hotfix needs to be published in which case the patch version should be incremented.

> The build and publishing of those branches and their tags is currently performed within Docker Hub.

## Generating release notes

The following git command can be used to provide the bulk of release notes content:

```shell script
git log --invert-grep --grep "^ci:" --grep "^misc:" --grep "^docs:" --pretty="* %s" 1.1.0..1.2.0
```
