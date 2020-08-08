This is a Docker image of [BungeeCord](https://www.spigotmc.org/wiki/bungeecord/)
and is intended to be used at the front-end of a cluster of
[itzg/minecraft-server](https://hub.docker.com/r/itzg/minecraft-server/) containers.

[![Docker Automated buil](https://img.shields.io/docker/automated/itzg/bungeecord.svg)](https://hub.docker.com/r/itzg/bungeecord/)

## Using with itzg/minecraft-server image

When using with the server image [itzg/minecraft-server](https://hub.docker.com/r/itzg/minecraft-server/)
you can disable online mode, which is required by bungeecord, by setting `ONLINE_MODE=FALSE`, such as

```bash
docker run ... -e ONLINE_MODE=FALSE itzg/minecraft-server
```

[Here](docs/docker-compose.yml) is an example Docker Compose file.

## Healthcheck

This image contains [mc-monitor](https://github.com/itzg/mc-monitor) and uses
its `status` command to continually check on the container's. That can be observed
from the `STATUS` column of `docker ps`

```
CONTAINER ID    IMAGE    COMMAND                         CREATED           STATUS                     PORTS                       NAMES
b418af073764    mc       "/usr/bin/run-bungeecord.sh"    43 seconds ago    Up 41 seconds (healthy)    0.0.0.0:25577->25577/tcp    mc
```

You can also query the container's health in a script friendly way:

```
> docker container inspect -f "{{.State.Health.Status}}" mc
healthy
```

## Environment Settings

* **TYPE**=BUNGEECORD

  The type of the server. When the type is set to `CUSTOM`, the environment setting `BUNGEE_JAR_URL` is required.

  Possible values: `BUNGEECORD`, `WATERFALL`, `CUSTOM`

* **MEMORY**=512m

  The Java memory heap size to specify to the JVM.

* **INIT_MEMORY**=${MEMORY}

  Can be set to use a different initial heap size.

* **MAX_MEMORY**=${MEMORY}

  Can be set to use a different max heap size.

* **JVM_OPTS**

  Additional -X options to pass to the JVM.

* **PLUGINS**

  Used to download a comma seperated list of *.jar urls to the plugins folder.

  ```
  -e PLUGINS=https://www.example.com/plugin1.jar,https://www.example.com/plugin2.jar
  ```

* **ENABLE_RCON**

  Enable the rcon server (that uses a third-party plugin to work, [orblazer/bungee-rcon](https://github.com/orblazer/bungee-rcon), which is automatically downloaded)

* **RCON_PORT**

  Define the port for rcon

* **RCON_PASSWORD**

  Define the password for rcon

## Optional Environment Settings

* **BUNGEE_JOB_ID**=lastStableBuild

  The Jenkins job ID of the artifact to download and run and is used when deriving the default value of `BUNGEE_JAR_URL`

* **BUNGEE_JAR_REVISION**

  Defaults to the value of `${BUNGEE_JOB_ID}`, but can be set to an arbitrarily incremented value to force an upgrade of the downloaded BungeeCord jar file.

* **BUNGEE_BASE_URL**

  Default to:

  * (type `BUNGEECORD`): <https://ci.md-5.net/job/BungeeCord>
  * (type `WATERFALL`): <https://papermc.io/ci/job/Waterfall/>

  Used to derive the default value of `BUNGEE_JAR_URL`

* **BUNGEE_JAR_URL**

  If set, can specify a custom, fully qualified URL  of the BungeeCord.jar; however, you won't be able reference the other environment variables from within a `docker run` a compose file. Defaults to:

  * (type: `BUNGEECORD`): `${BUNGEE_BASE_URL}/${BUNGEE_JOB_ID}/artifact/bootstrap/target/BungeeCord.jar`

* **WATERFALL_VERSION**=latest

  Only applies when `TYPE=WATERFALL`. If set, allows downloading a specific release stream of Waterfall.

* **WATERFALL_BUILD_ID**=latest

  Only applies when `TYPE=WATERFALL`. If set, allows downloading a specific build of Waterfall within the given version.

## Volumes

* **/server**

  The working directory where BungeeCord is started. This is the directory
  where its `config.yml` will be loaded.

* **/plugins**

  Plugins will be copied across from this directory before the server is started.

* **/config**

  The `/config/config.yml` file in this volume will be copied accross on startup if it is newer than the config in `/server/config.yml`.

  If `server-icon.png`, `modules.yml` or `waterfall.yml` also exists in the volume, they will also be copied if newer.

## Ports

* **25577**

  The listening port of BungeeCord, which you will typically want to port map
  to the standard Minecraft server port of 25565 using:

  ```
  -p 25565:25577
  ```

## Interacting with the server

[RCON](http://wiki.vg/RCON) is enabled by default, so you can `exec` into the container to
access the Bungeecord server console:

```
docker exec -i mc rcon-cli
```

Note: The `-i` is required for interactive use of rcon-cli.

To run a simple, one-shot command, such as stopping a Bungeecord server, pass the command as
arguments to `rcon-cli`, such as:

```
docker exec mc rcon-cli en
```

_The `-i` is not needed in this case._

In order to attach and interact with the Bungeecord server, add `-it` when starting the container, such as

    docker run -d -it -p 25565:25577 --name mc itzg/docker-bungeecord

With that you can attach and interact at any time using

    docker attach mc

and then Control-p Control-q to **detach**.

For remote access, configure your Docker daemon to use a `tcp` socket (such as `-H tcp://0.0.0.0:2375`)
and attach from another machine:

    docker -H $HOST:2375 attach mc

Unless you're on a home/private LAN, you should [enable TLS access](https://docs.docker.com/articles/https/).

## BungeeCord Configuration

[BungeeCord Configuration Guide](https://www.spigotmc.org/wiki/bungeecord-configuration-guide/)

### Replacing variables inside configs

Sometimes you have mods or plugins that require configuration information that is only available at runtime.
For example if you need to configure a plugin to connect to a database,
you don't want to include this information in your Git repository or Docker image.
Or maybe you have some runtime information like the server name that needs to be set
in your config files after the container starts.

For those cases there is the option to replace defined variables inside your configs
with environment variables defined at container runtime.

If you set the enviroment variable `REPLACE_ENV_VARIABLES` to `TRUE` the startup script
will go thru all files inside your `/server` volume and replace variables that match your
defined environment variables. Variables that you want to replace need to be wrapped
inside `${YOUR_VARIABLE}` curly brackets and prefixed with a dollar sign. This is the regular
syntax for enviromment variables inside strings or config files.

Optionally you can also define a prefix to only match predefined enviroment variables.

`ENV_VARIABLE_PREFIX="CFG_"` <-- this is the default prefix

If you want use file for value (like when use secrets) you can add suffix `_FILE` to your variable name (in  run command).

There are some limitations to what characters you can use.

| Type  | Allowed Characters  |
| ----- | ------------------- |
| Name  | `0-9a-zA-Z_-`       |
| Value | `0-9a-zA-Z_-:/=?.+` |

Variables will be replaced in files with the following extensions:
`.yml`, `.yaml`, `.txt`, `.cfg`, `.conf`, `.properties`.

Here is a full example where we want to replace values inside a `database.yml`.

```yml

---
database:
  host: ${CFG_DB_HOST}
  name: ${CFG_DB_NAME}
  password: ${CFG_DB_PASSWORD}
```

This is how your `docker-compose.yml` file could look like:

```yml
version: "3"
# Other docker-compose examples in /examples

services:
  proxy:
    image: itzg/bungeecord
    ports:
      - "25577:25577"
    volumes:
      - "proxy:/server"
    environment:
      # enable env variable replacement
      REPLACE_ENV_VARIABLES: "TRUE"
      # define an optional prefix for your env variables you want to replace
      ENV_VARIABLE_PREFIX: "CFG_"
      # and here are the actual variables
      CFG_DB_HOST: "http://localhost:3306"
      CFG_DB_NAME: "minecraft"
      CFG_DB_PASSWORD_FILE: "/run/secrets/db_password"
    restart: always

volumes:
  proxy:

secrets:
  db_password:
    file: ./db_password
```

The content of `db_password`:

    ug23u3bg39o-ogADSs

## Scenarios

### Running non-root

This image may be run as a non-root user but does require an attached `/server`
volume that is writable by that uid, such as:

    docker run ... -u $uid -v $(pwd)/data:/server itzg/bungeecord
