# docker with sshd suppoer

## use sh scripts

```

c2 devTool docker[press TAB]


c2 devTool docker.status
c2 devTool docker.build         (uses entrypoint/build.sh)
c2 devTool docker.run           (uses entrypoint/start.sh)
c2 devTool docker.stop
c2 devTool docker.clean

c2 devTool config
c2 devTool config.edit 

## deprecated
#buidDockerfile
#runDockerfile
```

## changes

change image names and versions in
```
c2 devTool docker.config.edit
```

to change the image build change
```
entrypoint/build.sh
```

to change the image start change
```
entrypoint/start.sh
```

this is a hard link to the src/sh/init/once.sh file and ignored in git
```
entrypoint/once.sh
```