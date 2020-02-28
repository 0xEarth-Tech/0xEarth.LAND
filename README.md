# 0xEarth.LAND
ERC-721 smart contract that enables fully trustless ownership of unique land on Earth

## High level
0xEarth LAND is an ERC-721 non-fungible token, which each token representing a unique parcle of earth using the ZXY tile standard. The source code for the contract can be found in this repo.


## Metadata
This repo also holds the optional metadata backing each LAND. By default each LAND will use the base LAND meta uri, though you can put in a pull request to add in specifics for your LAND. Once approved, simply toggle the boolean for your given LAND to use custom meta data.


# Metadata Standard Example
    {
     //Address within bounds of LAND
     "name": "Central Park", 
     //Use any tile server, but must use ZXY of LAND
     "image": "https://a.tile.openstreetmap.org/18/77200/98507.png", 
     //Add a descriptor of your liking
      "description": "LAND on the corner of Central Park and Columbus Circle", 
      "attributes": [
      //optional 
     {
      "trait_type": "country", 
      "value": "United States"
     }, {
     //optional (city, state, neighborhood, etc)
      "trait_type": "sublocale",
      "value": "New York City"
      }, {
      //Must match contract set value
     "display_type": "number", 
     "trait_type": "z",
     "value": 18
     },{
     //Must match your LANDs plot
     "display_type": "number",
     "trait_type": "x",
     "value": 77200
     },{
     //Must match your LANDs plot
     "display_type": "number", 
     "trait_type": "y",
     "value": 98507
     }],
     "external_url": "https://0xearth.github.io",
     "background_color": "141414"
     }

