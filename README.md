This is a Docker image that provides a choice of Minecraft proxies, such as [BungeeCord](https://www.spigotmc.org/wiki/bungeecord/) and [Velocity](https://papermc.io/software/velocity). It is intended to be used in combination with [itzg/minecraft-server](https://hub.docker.com/r/itzg/minecraft-server/) containers.

[![Build and Publish](https://github.com/itzg/docker-bungeecord/actions/workflows/build.yml/badge.svg)](https://github.com/itzg/docker-bungeecord/actions/workflows/build.yml)

## Using with itzg/minecraft-server image

When using with the server image [itzg/minecraft-server](https://hub.docker.com/r/itzg/minecraft-server/)
you can disable online mode, which is required by bungeecord, by setting `ONLINE_MODE=FALSE`, such as

```bash
docker run ... -e ONLINE_MODE=FALSE itzg/minecraft-server
```

The following is an example that can be started with `docker compose up -d`:

```yaml
services:
  mc:
    image: itzg/minecraft-server
    environment:
      EULA: "TRUE"
      ONLINE_MODE: "FALSE"
    volumes:
      - mc-data:/data
  proxy:
    image: itzg/mc-proxy
    environment:
      BUNGEE_JAR_REVISION: "1"
      CFG_MOTD: Powered by Docker
      REPLACE_ENV_VARIABLES: "true"
    ports:
      - "25565:25577"
    volumes:
      - ./config.yml:/config/config.yml
      - proxy-data:/server

volumes:
  mc-data:
  proxy-data:
```

## Healthcheck

This image contains [mc-monitor](https://github.com/itzg/mc-monitor) and uses its `status` command to continually check on the container's. That can be observed from the `STATUS` column of `docker ps`

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

  Possible values: 
  - [`BUNGEECORD`](https://www.spigotmc.org/wiki/bungeecord/)
  - [`WATERFALL`](https://github.com/PaperMC/Waterfall)
  - [`VELOCITY`](https://velocitypowered.com/)
  - `CUSTOM`

* **MEMORY**=512m

  The Java memory heap size to specify to the JVM. Setting this to an empty string will let the JVM calculate the heap size from the container declared memory limit. Be sure to consider adding `-XX:MaxRAMPercentage=<n>` (with `<n>` replaced) to `JVM_XX_OPTS`, where the JVM default is 25%.

* **ICON**

  Setting this to an image URL will download and (if required) convert the icon to a 64x64 PNG, and place it in `/server/server-icon.png`.

* **OVERRIDE_ICON**

  Will override any pre-existing server-icon.png file in the /server directory if `ICON` is set.

* **INIT_MEMORY**=${MEMORY}

  Can be set to use a different initial heap size.

* **MAX_MEMORY**=${MEMORY}

  Can be set to use a different max heap size.

* **JVM_OPTS** / **JVM_XX_OPTS**

  Additional space-separated options to pass to the JVM, where `JVM_XX_OPTS` will be added to the java command-line before `JVM_OPTS`.

* **NETWORKADDRESS_CACHE_TTL**=60

  Number of seconds to cache the successful network address lookups. A lower value is helpful when Minecraft server containers are restarted and/or rescheduled and re-assigned a new container IP address.

* **PLUGINS**

  Used to download a comma seperated list of *.jar urls to the plugins folder.

  ```
  -e PLUGINS=https://www.example.com/plugin1.jar,https://www.example.com/plugin2.jar
  ```

* **PLUGINS_FILE**

  An alternative to `PLUGINS`. This variable `PLUGINS_FILE` can be set with the container path or URL of a text file listing a mod/plugin URLs on each line. For example, the following

  ```
  -e PLUGINS_FILE=/extras/plugins.txt
  ```
  would load a file in the container at `/extras/plugins.txt`. The file might look like:

  ```
  https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/bungeecord
  # This line will be ignored
  https://download.luckperms.net/1567/bungee/loader/LuckPerms-Bungee-5.4.150.jar
  ```

  It works exactly the same as [Mod/Plugin URL Listing File for itzg/minecraft-server](https://docker-minecraft-server.readthedocs.io/en/latest/mods-and-plugins/#modsplugins-list).

* **SPIGET_PLUGINS**

  The `SPIGET_PLUGINS` variable can be set with a comma-separated list of SpigotMC resource IDs to automatically download [SpigotMC plugins](https://www.spigotmc.org/resources/) using [the spiget API](https://spiget.org/). Resources that are zip files will be expanded into the plugins directory and resources that are simply jar files will be moved there.
  
  > NOTE: the variable is purposely spelled SPIG**E**T with an "E"
  
  The **resource ID** can be located from the numerical part of the URL after the shortname and a dot. For example, the ID is **313** from

  ```
  https://www.spigotmc.org/resources/bungeetablistplus.313/
                                                       ===
  ```

* **MODRINTH_PROJECTS**

  Comma or newline separated list of project slugs (short name) or IDs. The project ID is located in the "Technical information" section. The slug is the part of the page URL that follows `/mod/`:
  ```
    https://modrinth.com/mod/fabric-api
                             ----------
                              |
                              +-- project slug
  ```
  Also, a specific version/type can be declared using colon symbol and version id/type after the project slug. The version id can be found in the 'Metadata' section. Valid version types are `release`, `beta`, `alpha`.

  Dependency resolution can be adjusted by setting `MODRINTH_DOWNLOAD_DEPENDENCIES` to `none`, `optional`, or `required` (the default).

  **NOTE** The variable `MINECRAFT_VERSION` must be set to the corresponding Minecraft version. 

* **ENABLE_RCON**

  Enable the rcon server (uses a third-party plugin to work).
  - [orblazer/bungee-rcon](https://github.com/orblazer/bungee-rcon) for `BUNGEECORD`, `WATERFALL`, and `CUSTOM`
  - [TribuFuForks/VelocityRcon](https://github.com/TribufuForks/VelocityRcon) for `VELOCITY`

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
  
  This takes precedence over `BUNGEE_JAR_FILE`.

* **BUNGEE_JAR_FILE**

  For `TYPE=CUSTOM`, allows setting a custom BungeeCord JAR that is located inside the container.
  
  Must be a valid path of an existing file.

* **WATERFALL_VERSION**=latest

  For `TYPE=WATERFALL`, allows downloading a specific release stream of Waterfall.

* **WATERFALL_BUILD_ID**=latest

  For `TYPE=WATERFALL`, allows downloading a specific build of Waterfall within the given version.

* **VELOCITY_VERSION**=latest

  For `TYPE=VELOCITY`, specifies the version of Velocity to download and run.

* **VELOCITY_BUILD_ID**=latest

  For `TYPE=VELOCITY`, allows downloading a specific build of Velocity within the given version.

* **HEALTH_HOST**=localhost

  Allows for configuring the host contacted for container health check.

* **HEALTH_USE_PROXY**=false

  Set to "true" when using Bungeecord's `proxy_protocol` option

* **ENABLE_JMX**=false

  To enable remote JMX, such as for profiling with VisualVM or JMC, add the environment variable `ENABLE_JMX=true`, set `JMX_HOST` to the IP/host running the Docker container, and add a port forwarding of TCP port 7091

## Volumes

* **/server**

  The working directory where BungeeCord is started. This is the directory
  where its `config.yml` will be loaded.

* **/plugins**

  Plugins will be copied across from this directory before the server is started.

* **/config**

  The contents of this directory will be synchronized into the `/server` directory. Variable placeholders within the files will be processed as described [in the section below](#replacing-variables-inside-configs) unless `REPLACE_ENV_DURING_SYNC` is set to "false".

## Ports

* **25577**

  The listening port of BungeeCord, which you will typically want to port map
  to the standard Minecraft server port of 25565 using:

  ```
  -p 25565:25577
  ```

## Java Versions

The following table shows the Java versions and CPU architectures supported by the image tags:

| Tag    | Java | Architectures       |
|--------|------|---------------------|
| latest | 17   | amd64, arm64, armv7 |
| java8  | 8    | amd64, arm64, armv7 |
| java11 | 11   | amd64, arm64, armv7 |

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

    docker run -d -it -p 25565:25577 --name mc itzg/mc-proxy

With that you can attach and interact at any time using

    docker attach mc

and then Control-p Control-q to **detach**.

For remote access, configure your Docker daemon to use a `tcp` socket (such as `-H tcp://0.0.0.0:2375`)
and attach from another machine:

    docker -H $HOST:2375 attach mc

Unless you're on a home/private LAN, you should [enable TLS access](https://docs.docker.com/articles/https/).

## BungeeCord Configuration

[BungeeCord Configuration Guide](https://www.spigotmc.org/wiki/bungeecord-configuration-guide/)

### Generic pack files

To install all the server content (jars, mods, plugins, configs, etc.) from a zip or tgz file, then set `GENERIC_PACK` to the container path or URL of the archive file.

If multiple generic packs need to be applied together, set `GENERIC_PACKS` instead, with a comma separated list of archive file paths and/or URLs to files.

To avoid repetition, each entry will be prefixed by the value of `GENERIC_PACKS_PREFIX` and suffixed by the value of `GENERIC_PACKS_SUFFIX`, both of which are optional. For example, the following variables

```
GENERIC_PACKS=configs-v9.0.1,mods-v4.3.6
GENERIC_PACKS_PREFIX=https://cdn.example.org/
GENERIC_PACKS_SUFFIX=.zip
```

would expand to `https://cdn.example.org/configs-v9.0.1.zip,https://cdn.example.org/mods-v4.3.6.zip`.

### Replacing variables inside configs

Sometimes you have mods or plugins that require configuration information that is only available at runtime.
For example if you need to configure a plugin to connect to a database,
you don't want to include this information in your Git repository or Docker image.
Or maybe you have some runtime information like the server name that needs to be set
in your config files after the container starts.

For those cases there is the option to replace defined variables inside your configs
with environment variables defined at container runtime.

If you set the environment variable `REPLACE_ENV_VARIABLES` to `TRUE` the startup script will go through all files inside your `/server` volume and replace variables that match your defined environment variables. Variables that you want to replace need to be declared as `${YOUR_VARIABLE}`, which is common with shell scripting languages.

With `REPLACE_ENV_VARIABLE_PREFIX` you can define a prefix, where the default is `CFG_`, to only match predefined environment variables.

If you want to use a file for a value (such as when using Docker secrets) you can add suffix `_FILE` to your variable name (in  run command). For example, `${CFG_PASSWORD_FILE}` would be replaced with the contents of the file specified by the `CFG_PASSWORD_FILE` environment variable.

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
version: "3.8"
# Other docker-compose examples in /examples

services:
  proxy:
    image: itzg/mc-proxy
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

### Patching existing files

JSON path based patches can be applied to one or more existing files by setting the variable `PATCH_DEFINITIONS` to the path of a directory that contains one or more [patch definition json files](https://github.com/itzg/mc-image-helper#patchdefinition) or a [patch set json file](https://github.com/itzg/mc-image-helper#patchset).

The `file` and `value` fields of the patch definitions may contain `${...}` variable placeholders. The allowed environment variables in placeholders can be restricted by setting `REPLACE_ENV_VARIABLE_PREFIX`, which defaults to "CFG_".

The following example shows a patch-set file were various fields in the `paper.yaml` configuration file can be modified and added:

```json
{
  "patches": [
    {
      "file": "/data/paper.yml",
      "ops": [
        {
          "$set": {
            "path": "$.verbose",
            "value": true
          }
        },
        {
          "$set": {
            "path": "$.settings['velocity-support'].enabled",
            "value": "${CFG_VELOCITY_ENABLED}",
            "value-type": "bool"
          }
        },
        {
          "$put": {
            "path": "$.settings",
            "key": "my-test-setting",
            "value": "testing"
          }
        }
      ]
    }
  ]
}
```

Supports the file formats:
- JSON
- JSON5
- Yaml
- TOML, but processed output is not pretty

## Scenarios

### Running non-root

This image may be run as a non-root user but does require an attached `/server`
volume that is writable by that uid, such as:

    docker run ... -u $uid -v $(pwd)/data:/server itzg/mc-proxy

## Java Versions

The `latest` image tag is based on Java 21, but alternate image tags are available to run with a different java version. 

The image Java variant can be used as shown here:

    itzg/mc-proxy:{variant}

or using release version, such as `2024.5.0`

    itzg/mc-proxy:{release}-{variant}

| Variant | Java Version | CPU types         |
|---------|--------------|-------------------|
| latest  | 21           | amd64,arm64       |
| java21  | 21           | amd64,arm64       |
| java17  | 17           | amd64,arm64,armv7 |
| java11  | 11           | amd64,arm64,armv7 |
| java8   | 8            | amd64,arm64,armv7 |
