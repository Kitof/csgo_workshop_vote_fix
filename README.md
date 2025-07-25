# Fix for the CS:GO end-of-match votes on the workshop maps 

![Alt text](imgs/VoteWithThumbnails.png?raw=true "Vote With Thumbnails")

## Version for CS2 here : https://github.com/Kitof/CS2-EomVotesFix ##

## Why a fix for CS:GO ?

CS:GO offers a very interesting feature: The ability to subscribe to a workshop map collection to play a series of original maps that will follow each other.

This feature works well, but another feature is broken when coupled with it: the end-of-match vote for next map.

Indeed, there are two distinct problems:

**On the server side:** Despite the use of the subscribed_collection_ids.txt file, the end of game vote on maps from the workshop only works if the list of cards is explicitly filled in the gamemodes_server.txt file, which removes the interest of using a collection because it becomes tedious to generate a configuration with individual maps names, which are moreover complex to find.

**On the client side:** Once the server is configured, the vote is displayed at the end of the game, but it is impossible to display thumbnails of map. Only a name and a generic thumbnail are displayed, making the vote much less readable, especially on large collections.

## What is this fix ?

It is composed of 2 distincts fixes:

**A fix for the server (Linux or Windows):** I chose not to directly modify the server configuration which can sometimes have been largely customized by the administrator. The script generates the configuration to be added or merged manually to the gamemodes_server.txt file. To do this, it needs to retrieve the names of the bsp files that are not directly readable on the website. They are therefore retrieved via the Steam API[^1].

**A fix for clients (Windows only):** The goal is to have a plug and play script that does not require any prior installation to make installation by players very easy. This script will retrieve the thumbnails of the cards, convert it in png, and modify the gamemodes.txt file to allow them to be displayed[^2].

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

7. Change `collection_id` in `csgo_fix_thumbnails_launcher.bat`

8. Launch  `csgo_fix_thumbnails_launcher.bat`

[^1]: Thanks to @valeologist from https://github.com/ValveSoftware/csgo-osx-linux/issues/2025
[^2]: Thanks to @Bacari et @wanko from https://forums.alliedmods.net/showthread.php?t=312268&page=2

## Advanced Usage

You could launch 'csgo_fix_thumbnails_script.ps1' directly. It support several parameters :
```
Usage: csgo_fix_thumbnails_script.ps1 [MODE] [COLLECTION_ID] [OPTIONS]


Modes :
-ca, --client-append    Client Append mode: Add maps to configuration (default)
-cx, --client-replace   Client Replace mode: Replace maps of current configuration
-cr, --client-restore   Client Restore original gamemodes.txt
-so, --server-output    Server Output mode: Output new gamemodes_server.txt
-sa, --server-append    Server Append mode: If exists, add maps to gamemodes_server.txt in working directory.
-sx, --server-replace   Server Replace file mode: Create or replace example gamemodes_server.txt in working directory

Options :
-wd, --working-directory  Specified a working directory
```
