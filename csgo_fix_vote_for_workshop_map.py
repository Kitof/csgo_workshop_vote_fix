import requests
import sys
import os.path
from bs4 import BeautifulSoup

if len(sys.argv) != 2:
    print("Usage: python csgo_fix_vote_for_workshop_map.py <collectionID>")
    sys.exit(1)

collection_id = sys.argv[1]
collection_url = "https://steamcommunity.com/sharedfiles/filedetails/?id=" + collection_id
api_url = "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/"


response = requests.get(collection_url)
soup = BeautifulSoup(response.content, "html.parser")

template_begin = """
"GameModes.txt"
{
    "gameTypes"
    {
        "classic"
        {
            "gameModes"
            {
                "casual"
                {
                    "mapgroupsMP"
                    {
                        "my_custom_group" ""
                    }
                }
            }
        }
    }

    "mapgroups"
    {
        "my_custom_group"
        {
            "maps"
            {
"""
print(f"{template_begin}")
    
ids = []
for card in soup.find_all("div", class_="workshopItem"):
    link = card.find("a")["href"]
    id = link.split("=")[-1]
    
    params = {"itemcount": 1, "publishedfileids[0]": id}
    response = requests.post(api_url, data=params)
    json_data = response.json()
    filename = json_data["response"]["publishedfiledetails"][0]["filename"]
    basename = os.path.splitext(os.path.basename(filename))[0]

    print(f"\"workshop/{id}/{basename}\" \"\"")

template_end = """
            }
        }
    }
}
"""
print(f"{template_end}")