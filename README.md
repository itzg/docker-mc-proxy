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

## Environment Settings

* **BUNGEE_JOB_ID**=lastStableBuild

  The Jenkins job ID of the artifact to download and run and is used when
  deriving the default value of `BUNGEE_JAR_URL`

* **BUNGEE_BASE_URL**=https://ci.md-5.net/job/BungeeCord

  Used to derive the default value of `BUNGEE_JAR_URL`

* **BUNGEE_JAR_URL**=${BUNGEE_BASE_URL}/${BUNGEE_JOB_ID}/artifact/bootstrap/target/BungeeCord.jar

  If set, can specify a custom, fully qualified URL  of the BungeeCord.jar

* **MEMORY**=512m

  The Java memory heap size to specify to the JVM.

* **INIT_MEMORY**=${MEMORY}

  Can be set to use a different initial heap size.

* **MAX_MEMORY**=${MEMORY}

  Can be set to use a different max heap size.

* **JVM_OPTS**

  Additional -X options to pass to the JVM.

## Volumes

* **/server**

  The working directory where BungeeCord is started. This is the directory
  where its `config.yml` will be loaded.
  
* **/plugins**

  Plugins will be copied across from this directory before the server is started.

* **/config**
  
  Configs will be copied accros from this directory before the server is started.
  Will **not** overwrite existing configs in the mounted `/server` volume.

## Ports

* **25577**

  The listening port of BungeeCord, which you will typically want to port map
  to the standard Minecraft server port of 25565 using:

  ```
  -p 25565:25577
  ```

## BungeeCord Configuration

[BungeeCord Configuration Guide](https://www.spigotmc.org/wiki/bungeecord-configuration-guide/)

## Scenarios

### Running non-root

This image may be run as a non-root user but does require an attached `/server`
volume that is writable by that uid, such as:

    docker run ... -u $uid -v $(pwd)/data:/server itzg/bungeecord
