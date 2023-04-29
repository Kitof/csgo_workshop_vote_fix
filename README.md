# Fix for the CS:GO end-of-match votes on the workshop maps 

![Alt text](imgs/VoteWithThumbnails.png?raw=true "Vote With Thumbnails")

## Why a fix for CS:GO ?

CS:GO offers a very interesting feature: The ability to subscribe to a Workshop map collection to play a series of original maps that will follow each other.

This feature works well, but another feature is broken when coupled with it: the end-of-match vote for next map.

Indeed, there are two distinct problems:

**On the server side:** Despite the use of the subscribed_collection_ids.txt file, the end of game vote on maps from the workshop only works if the list of cards is explicitly filled in the gamemodes_server.txt file, which removes the interest of using a collection because it becomes tedious to generate a configuration with individual maps names, which are moreover complex to find.

**On the client side:** Once the server is configured, the vote is displayed at the end of the game, but it is impossible to display thumbnails of map. Only a name and a generic thumbnail are displayed, making the vote much less readable, especially on large collections.

## What is this fix ?

It is composed of 2 distinct scripts:

**A python script for the server:** I chose not to directly modify the server configuration which can sometimes have been largely customized by the administrator. The script generates the configuration to be added manually to the gamemodes_server.txt file. To do this, it needs to retrieve the names of the bsp files that are not directly readable on the website. They are therefore retrieved via the Steam API[^1].

**A PowerShell script for Windows clients:** Unlike the server script, I have chosen a plug and play script that does not require any prior installation. This script will retrieve the thumbnails of the cards and modify the gamemodes.txt file to allow them to be displayed[^2].

## How use it ?

1. Identify your [collection ID](https://steamcommunity.com/workshop/browse/?section=collections&appid=730)

### On Dedicated Server (Linux): 

2. Launch `python csgo_fix_vote_for_workshop_map.py <collection ID>`

3. Use & adapt generated content in `csgo/gamemodes_server.txt`

4. Add `mapgroup my_custom_group` to `csgo/cfg/server.txt`

5. Launch your server with additionnal parameters `+host_workshop_collection <collection ID> +workshop_start_map <first map ID>`

### On Dedicated Server (Windows): 

2. Change `collection_id` in `csgo_fix_vote_for_workshop_map.bat`

3. Launch `csgo_fix_vote_for_workshop_map.bat`

4. Use & adapt generated content in `csgo/gamemodes_server.txt`

5. Add `mapgroup my_custom_group` to `csgo/cfg/server.txt`

6. Launch your server with additionnal parameters `+host_workshop_collection <collection ID> +workshop_start_map <first map ID>`

### On Clients side (Windows) : 

6. Change `collection_id` in `csgo_fix_thumbnails_launcher.bat`

7. Launch  `csgo_fix_thumbnails_launcher.bat`

[^1]: Thanks to @karl-police2023[GER] from https://github.com/ValveSoftware/csgo-osx-linux/issues/2025
[^2]: Thanks to @Bacari et @wanko from https://forums.alliedmods.net/showthread.php?t=312268&page=2
