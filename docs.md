# IdleChat Documentation

## About 

IdleChat is a multiplayer idle game, where users compete to get the most credits using technical know-how and subterfuge

## Variables

*Note: Variable names are written in camel case, example: exampleVariableName*

### aliasToID: Dictionary

- Dictionary of connected users, keys are user aliases, values are network IDs

### commandList: Dictionary

- Contains all the commands that users can use. Keys are the commands (with forward slashes, ex: "/help"), values are command descriptions

- Commands:

	- "/buy": "< item name> < quanitity> Purchase an item",
	
    - "/changealias": "< newalias> Change your current alias",
	
    - "/changecolor": "< newcolor> Change your current color",
	
    - "/changepass": "< newpassword> Change your current password",
	
    - "/cycle": "< action> < target> Set your action for the current cycle, with optional target user",
	
    - "/cyclelist": "Show a list of available cycle actions",
	
    - "/exec": "< item> < target> Execute a purchased item",
	
    - "/help": "Show list of commands",
	
    - "/inv": "Show current inventory"

    - "/listmodes": "Show a list of process modes",
	
    - "/resetpass": "Reset your password to the default network password",
	
    - "/setmode": "< mode> Set your current process mode",
	
    - "/shoplist": "Show a list of items to buy",
	
    - "/startgame": "SERVER ONLY, forces the game to start",
	
    - "/stopgame": "SERVER ONLY, forces the game to stop",
	
    - "/w": "< username> < message> Send whisper to another user"}

### connectedList: Dictionary

- Dictionary of connected users, keys are user network ID's, values are usernames

### cycleActionList: Dictionary

- Contains all the actions that can be performed by the /cycle command. Keys are actions, and values are action descriptions

- Dictionary contents:

    - "hackWallet": "Attempt to steal credits from another users wallet"

    - "fortFirewall": "Fortify your firewall, which will prevent one succesfull attack"

### cycleTimer: Timer

- Variable used to create Timer object that triggers the _process_cycle method

### editPopup: Popup

- Variable used to create the Edit dropdown menu

### emptyInventory: Dictionary

- Variable used to create new inventory for user. Contains a dictionary with keys for every item, and values of 0 representing no items in inventory

### filePopup: Popup

- Variabled used to create the File dropdown menu

### localLog: Array

- Used to store local messages

- Each item in the array is another array containing two items:

    - First is the message time stamp in dateTime format

    - Second is the actual message

### MAX_PLAYERS: Int


- Server variable, sets maximum number of connected users

### networkInfo: Dict

- Main variable for storing network data

- Dictionary contents:

    - "autosaveInterval": Int, duration between autosaves

    - "baseCredits": Int, the number of credits the network will generate each cycle, which is then multiplied by the number of connected users

    - "cycleDuration": Int, how many seconds between each game cycle

    - "gameRunning": Bool, true if game is currently running

    - "maxFirewallLevel": Int, maximum level for users firewalls

    - "messageLog": Array, contains all network messages in array format

        - message format: [dateTime, "message string"]

    - "minUsers": Int, minimum number of users that need to be connected for the game to start

    - "netSavePath": String, file path for network save file

    - "netPass": String, password required to join network

    - "netPort": Int, port used to listen

    - "networkName": String, name of the network

    - "userList": Dictionary, contains all userInfo dictionaries for users who have joine the network. Keys are usernames, values are userInfo dicts

### prefs: Dictionary

- Variable used to store all local user preferences

- Dictionary contents:

    - "userName": String, users username

    - "userAlias": String, users alias

    - "userColor": String, bbcode for users color

    - "sysColor": String, bbcode for users system color

    - "sysName": String, users system name

    - "dispTimeStamps": Bool, toggles if time stamps are printed with messages

    - "localLogLocation"L: String, file path used to save network local message logs

### processModes: Dictionary

- Dictionary containing all the available process modes, keys are modes, values are mode descriptions

    - Process Modes:

        - "balanced": Users attack, defense, and credit multiplier stats each recieve a .1 increase

        - "attack": Users attack stat recieves a .3 increase

        - "defense": Users defense stat recieves a .3 incrase

        - "creditMult": Users credit multiplier stat recieves a .3 increase

### rng: Random Number Generator

- Used to create pseudo random numbers as needed in various functions

### saveTimer: Timer

- Variable used to create the Timer object that triggers the autosave method

### sharedNetworkInfo: Dictionary

- Smaller version of the networkInfo dictionary. This one is shared with all connected users.

- Dictionary contents:

    - "networkName": String, the networks name

    - "messageLog": Array, contains all the network messages in array format

        - message array: [dateTime, "message string"]

    - "connectedUsers": Dictionary, contains currently connected users. Keys are user aliases, values are user network ID's

    - "processOrder": Array, current order that user commands will be executed. Values are user aliases

### userInfo: Dictionary

- Variable used by network to save individual user information

- Dictionary contens:

    - "activeCycles": Int, number of cycles the user has been active

    - "attack": Float, users attack rating

    - "creditMult": Float, users credit multiplier

    - "currentCredits": Int, users current available credits

    - "cycleActions": Array, List of users actions to execute at end of cycle, action and front of list will be executed then removed each cycle

        - Each action in the array, is itself an array. The first element being the type of action, and the second is the optional target of the action

    - "defense": Float, users defense rating

    - "firewallLevel": Int, current level of users firewall. 0 being no firewall.

    - "inventory": Dictionary, keys are item names, values are number of items owned by user

        - Inventory keys:

            - fortFirewall

            - hackWallet

    - "processMode": String, the current process mode for the user. 

        - Process Modes:

            - "balanced": Users attack, defense, and credit multiplier stats each recieve a .1 increase

            - "attack": Users attack stat recieves a .3 increase

            - "defense": Users defense stat recieves a .3 incrase

            - "creditMult": Users credit multiplier stat recieves a .3 increase

    - "totalCredits": Int, total credits generated by user, used as a high score 

    - "userName": String, users username

    - "userPass": String, users network password, by default is the network password

### userList: Dictionary

- Dictionary containing all of the userInfo dictionaries, keys are usernames, values are userInfo dicts

### userPass: String

- Passoword the user is currently using to connect to a network

## Methods

