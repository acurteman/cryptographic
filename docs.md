# Cryptographic Documentation

## About 

Cryptographic is a multiplayer idle game, where users compete to get the most credits using technical know-how and subterfuge

## External Script Format

External scripts should be formatted in .csv files. The first line should contain required metadata. Each following line should be script commands.

- Metadata requirements:

    - New script bool: Contains true if the script has been updated and needs to be loaded. After loading, will be changed to false

    - Run mode string: Sets how frequently script will be executed. Run mode options:

        - "single": Script will be run once

        - "interval": Script will be executed repeatedly after given duration

        - "cycle": Script will be executed once at the start of each cycle
    
    - Interval float: Used to set the duration if run mode is interval. Default to 1.0

    - Example script:

    > true,interval,1.0
    >
    > cycle,fortFirewall
    >
    > buy,hackWallet
    >
    > exec,hackWallet,targetAlias

## Variables

*Note: Variable names are written in camel case, example: exampleVariableName*


### activityLog: Array

- Client variable. Array containing results of recent activities. Each activity log is itself another array with the following format:

    - Element 0: String, Datetime stamp of when activity occured

    - Element 1: String, Activity type

    - Element 2: String, Activity target

    - Element 3: String, Activity success or failure status

    - Element 4: String, Optional message

### adminCommands: Dictionary

- Client variable. Contains all commands that can be used by server admins, keys are commands, values are command descriptions.

- Admin commands:

    - "/announce": "Broadcast message to all users from the server"

	- "/ban": "< alias > Bans user from the server"

	- "/kick": "< alias > Kicks user from the server"

	- "/shutdown": "Shuts down the game server"

	- "/startgame": "Forces the game to start"

	- "/stopgame": "Forces the game to stop"

### aliasToID: Dictionary

- Server variable. Dictionary of connected users, keys are user aliases, values are network IDs.

### commandList: Dictionary

- Client variable. Contains all the commands that users can use. Keys are the commands (with forward slashes, ex: "/help"), values are command descriptions.

- Commands:

    - "/bank": "< amount > < duration > Bank credits for a specified number of cycles, earning interest."

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

    - "/transfer": < target > < amount > Transfer credits to another user
	
    - "/w": "< username> < message> Send whisper to another user"}

### connectedList: Dictionary

- Server variable. Dictionary of connected users, keys are user network ID's, values are usernames

### cycleActionList: Dictionary

- Client variable. Contains all the actions that can be performed by the /cycle command. Keys are actions, and values are action descriptions

- Dictionary contents:

    - "forceSkip": "Force the network to skip a user on the next cycle"

    - "fortFirewall": "Fortify your firewall, which will prevent one succesfull attack"

    - "hackWallet": "Attempt to steal credits from another users wallet"

    - "shuffleProc": "Shuffle the process order list"

    - "stealID": "Attempt to swap aliases with another user"
	
    - "traceRoute": "Log information of anyone who breaches your network"

### cycleTimer: Timer

- Server variable. Used to create Timer object that triggers the _process_cycle method

### cycleScript: Bool

- Client variable. Used to detrmine if user is waiting to execute a script once a new cycle starts. If set to true, the run_script function will be called at the start of the cycle

### depositList: Array

- Server variable, used to store user bank deposits. Each deposit is an array with the following format:

    - Element 0: Username, string

    - Element 1: Deposit amount, int

    - Element 2: Deposit duration in number of cycles, int

### editPopup: Popup

- Client variable. Used to create the Edit dropdown menu

### emptyInventory: Dictionary

- Server variable. Used to create new inventory for user. Contains a dictionary with keys for every item, and values of 0 representing no items in inventory

### filePopup: Popup

- Client variable. Used to create the File dropdown menu

### gameRunning: Bool

- Server variable, true when the game is running

### localLog: Array

- Client variable. Used to store local messages

- Each item in the array is another array containing two items:

    - First is the message time stamp in dateTime format

    - Second is the actual message

### MAX_PLAYERS: Int

- Server variable, sets maximum number of connected users

### messageLog: Array

- Server variable, each element is a message sent between players. This variable is loaded and saved to the file messageLog.dat

    - message format: [dateTime, "message string"]

### networkInfo: Dict

- Server variable for storing network settings. Saved to the file networkInfo.text. Due to the format of the save file, all dict values need to be either strings or ints. This allows the file to be easily edited to change game settings externally.

- Dictionary contents:

    - "adminList": String, contains user names for users with admin rights. Names are comma seperated with no spaces.

    - "autosaveInterval": Int, duration between autosaves

    - "bankInterest": Int, used as the percentage users earn on deposited credits

    - "banList": String, contains user names of banned users. Names are comma seperated with no spaces

    - "baseCredits": Int, number used to calculate how many credits each user earns each cycle. The current formula for calculating credits for each user is: baseCredits * ln(users creditMult stat). Example, if a user has a creditMult of 5, and the networks base credits is 10, the credits they would receive is 10 * ln(5) = 16.09, truncated down to 16, since all credits are ints.

    - "cycleDuration": Int, how many seconds between each game cycle

    - "ddosThreshold": Int, ddos level above which users will be placed into ddos protection, preventing further hacks until their ddos level falls back below the threshold

    - "maxFirewallLevel": Int, maximum level for users firewalls

    - "minUsers": Int, minimum number of users that need to be connected for the game to start

    - "netSavePath": String, file path for network save file

    - "netPass": String, password required to join network

    - "netPort": Int, port used to listen

    - "networkName": String, name of the network

    - "shopTax": Int, percentage of users maxCredits that gets added to every purchase

### prefs: Dictionary

- Client variable. Used to store all local user preferences

- Dictionary contents:

    - "userName": String, users username

    - "userAlias": String, users alias

    - "userColor": String, bbcode for users color

    - "sysColor": String, bbcode for users system color

    - "sysName": String, users system name

    - "dispTimeStamps": Bool, toggles if time stamps are printed with messages

    - "localLogLocation": String, file path used to save network local message logs

    - "outputFreq": String, Sets how often the game output is written to file. Available options:

        - "cycle": Output is written once every cycle

        - "interval": Output is written once every given interval

    - "outputInterval": Float, Sets how often output is written to file if the outputFreq is set to "interval"

### processModes: Dictionary

- Client variable. Contains all the available process modes, keys are modes, values are mode descriptions

    - Process Modes:

        - "balanced": Users attack, defense, and credit multiplier stats each recieve a .1 increase

        - "attack": Users attack stat recieves a .3 increase

        - "defense": Users defense stat recieves a .3 incrase

        - "creditMult": Users credit multiplier stat recieves a .3 increase

### rng: Random Number Generator

- Server variable. Used to create pseudo random numbers as needed in various functions

### saveTimer: Timer

- Server variable. Used to create the Timer object that triggers the autosave method

### sharedNetworkInfo: Dictionary

- Server and client shared variable. Smaller version of the networkInfo dictionary. This one is shared with all connected users.

- Dictionary contents:

    - "networkName": String, the networks name

    - "messageLog": Array, contains all the network messages in array format

        - message array: [dateTime, "message string"]

    - "connectedUsers": Dictionary, contains currently connected users. Keys are user aliases, values are user network ID's

    - "processOrder": Array, current order that user commands will be executed. Values are user aliases

    - "userMaxCreds": Dictionary, contains connected users high scores, keys are aliases, values are high scores

### shopItems: Dictionary

- Contains all the items available to buy. Keys are item names, values are item prices

- Dictionary contents:

    - "changeAlias": 250,

	- "forceSkip": 150,

	- "fortFirewall": 50,

	- "hackWallet": 100,

	- "shuffleProc": 15,

	- "stealID": 300,

	- "traceRoute": 75

### skipList: Array

- Server variable. Contains aliases of users who will be skipped during the next cycle as a result of a successful forceSkip attack

### userInfo: Dictionary

- Server variable. Used by network to save individual user information

- Dictionary contents:

    - "activeCycles": Int, number of cycles the user has been active

    - "attack": Float, users attack rating

    - "creditMult": Float, users credit multiplier

    - "currentCredits": Int, users current available credits

    - "cycleActions": Array, List of users actions to execute at end of cycle, action and front of list will be executed then removed each cycle

        - Each action in the array, is itself an array. The first element being the type of action, and the second is the optional target of the action

    - "ddosLevel": Int, current level of users DDOS activity. Increased when user is successfully hacked, slowly decreases over time. If above a certain level, will prevent further attacks

    - "defense": Float, users defense rating

    - "firewallLevel": Int, current level of users firewall. 0 being no firewall.

    - "hackModifier": Dict, keys are usernames, values are hack modifier floats

    - "inventory": Dictionary, keys are item names, values are number of items owned by user

        - Inventory keys:

            - fortFirewall

            - hackWallet

    - "logoutTime": Int, unix time the user last logged out. Used to prevent users from rapid disconnect/reconnect

    - "maxCredits": Int, most credits a user has had at one time. Used as a high score

    - "processMode": String, the current process mode for the user. 

        - Process Modes:

            - "balanced": Users attack, defense, and credit multiplier stats each recieve a .1 increase

            - "attack": Users attack stat recieves a .3 increase

            - "defense": Users defense stat recieves a .3 incrase

            - "creditMult": Users credit multiplier stat recieves a .3 increase

    - "traceRoute" Int, how many traceRoute programs the user has activated

    - "userName": String, users username

    - "userPass": String, users network password, by default is the network password

### userList: Dictionary

- Server variable. Contains all of the userInfo dictionaries, keys are usernames, values are userInfo dicts. This variable is saved to the file userData.dat

### userPass: String

- Client variable. Passoword the user is currently using to connect to a network


### version: string

- Server and client variable. Contains the current version number, server and client must have matching version numbers for a client to log in. 

## Methods

