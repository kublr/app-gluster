Build:

```
./build.sh
```

Publish:

```
./publish.sh
```

Use:
```
# add repository
helm repo add apps https://nexus.dev.ebt-devops-rnd.eastbanctech.com/repository/testraw/

# check that the app is available in the repository
helm search apps

# install app
helm install apps/app-jenkins
```
