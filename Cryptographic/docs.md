# IdleChat Documentation

## About 

IdleChat is a multiplayer idle game, where users compete to get the most credits using technical know-how and subterfuge

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

- Array containing results of recent activities. Each activity log is itself another array with the following format:

    - Element 0: String, Datetime stamp of when activity occured

    - Element 1: String, Activity type

    - Element 2: String, Activity target

    - Element 3: String, Activity success or failure status

    - Element 4: String, Optional message

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

    - "forceSkip": "Force the network to skip a user on the next cycle"

    - "fortFirewall": "Fortify your firewall, which will prevent one succesfull attack"

    - "hackWallet": "Attempt to steal credits from another users wallet"

    - "shuffleProc": "Shuffle the process order list"
	
    - "traceRoute": "Log information of anyone who breaches your network"

### cycleTimer: Timer

- Variable used to create Timer object that triggers the _process_cycle method

### cycleScript: Bool

- Used to detrmine if user is waiting to execute a script once a new cycle starts. If set to true, the run_script function will be called at the start of the cycle

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

    - "skipList": Array, contains aliases of users who will be skipped during the next cycle

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

    - "localLogLocation": String, file path used to save network local message logs

    - "outputFreq": String, Sets how often the game output is written to file. Available options:

        - "cycle": Output is written once every cycle

        - "interval": Output is written once every given interval

    - "outputInterval": Float, Sets how often output is written to file if the outputFreq is set to "interval"

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

    - "userMaxCreds": Dictionary, contains connected users high scores, keys are aliases, values are high scores

### userInfo: Dictionary

- Variable used by network to save individual user information

- Dictionary contens:

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

- Dictionary containing all of the userInfo dictionaries, keys are usernames, values are userInfo dicts

### userPass: String

- Passoword the user is currently using to connect to a network

## Methods

