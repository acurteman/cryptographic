extends Control

var connectedList = {} # Used by the server to track usernames and IDs for connected users
var aliasToID = {} # List of users with alias's as keys and ID's as values
var IDtoAlais = {} # Reversed list of users with IDs as keys and aliases as values
var MAX_PLAYERS = 32
var filePopup
var editPopup
var saveTimer
var cycleTimer
var prefs = {
	"userName": "defaultUser",
	"userAlias": "defaultAlias",
	"userColor": "red",
	"sysColor": "gray",
	"sysName": "system",
	"dispTimeStamps": true,
	"localLogLocation": "user://"}
var userInfo = {}
var localLog = []
var userList = {} # Variable used to save all user data on the network, keys are user names
var networkInfo = {
	"networkName": "defaultNet",
	"messageLog": [],
	"autosaveInterval": 10, 
	"netSavePath": "",
	"netPort": 4242,
	"netPass": "password",
	"userList": userList,
	"minUsers": 2,
	"gameRunning": false,
	"cycleDuration": 10,
	"baseCredits": 10,
	"maxFirewallLevel": 2}
var sharedNetworkInfo = {
	"networkName":"temp",
	"messageLog": [],
	"connectedUsers": {},
	"processOrder": []}
var userPass = ""
var commandList = {
	"/buy": "<item name> <quanitity> Purchase an item",
	"/changealias": "<newalias> Change your current alias",
	"/changecolor": "<newcolor> Change your current color",
	"/changepass": "<newpassword> Change your current password",
	"/cycle": "<action> <target> Set your action for the current cycle, with optional target user",
	"/cyclelist": "Show a list of available cycle actions",
	"/exec": "<item> <target> Execute a purchased item",
	"/help": "Show list of commands",
	"/inv": "Show current inventory",
	"/listmodes": "Show a list of process modes",
	"/resetpass": "Reset your password to the default network password",
	"/setmode": "<mode> Set your current process mode",
	"/shoplist": "Show a list of items to buy",
	"/startgame": "SERVER ONLY, forces the game to start",
	"/stopgame": "SERVER ONLY, forces the game to stop",
	"/w": "<username> <message> Send whisper to another user"}
var processModes = {
	"balanced": "Attack, defence, and creditMult stat each recieve a .1 increase each cycle",
	"attack": "Attack stat recieves a .3 increase each cycle",
	"defense": "Defense stat recieves a .3 increase each cycle",
	"creditMult": "Credit multiplier stat recieves a .3 increase each cycle"}
var cycleActionList = {
	"hackWallet": "Attempt to steal credits from another users wallet",
	"fortFirewall": "Fortify your firewall, which will prevent one succesfull attack"}
var shopItems = {
	"hackWallet": 100,
	"fortFirewall": 50}
var emptyInventory = {
	"hackWallet": 0,
	"fortFirewall": 0}
var rng = RandomNumberGenerator.new()
onready var port = int($joinPopup/portInput.text)
onready var ipAddress = $joinPopup/ipInput.text

func _ready():
	load_prefs()
	rng.randomize()
	
	get_tree().connect("connection_failed", self, "connected_fail")
	get_tree().connect("network_peer_disconnected",self,"user_left")
	get_tree().connect("connected_to_server",self,"connected")
	get_tree().connect("server_disconnected",self,"server_disconnected")
	
	filePopup = $fileButton.get_popup()
	filePopup.add_item("Join Network")
	filePopup.add_item("Host New Network")
	filePopup.add_item("Load Network")
	filePopup.add_item("Disconnect")
	filePopup.set_item_disabled(3, true)
	filePopup.add_item("Exit")
	filePopup.connect("id_pressed", self, "_on_file_item_pressed")
	
	editPopup = $editButton.get_popup()
	editPopup.add_item("User Settings")
	editPopup.connect("id_pressed", self, "_on_edit_item_pressed")
	
	$hostPopup/saveDir.text = $hostPopup/saveDirPopup.current_path

func _on_file_item_pressed(ID):
	if ID == 0: # Join Network
		$joinPopup.popup()
	elif ID == 1: # Host New Network
		$hostPopup.popup()
	elif ID == 2: # Load Network
		$loadPopup.popup()
	elif ID == 3: # Disconnect
		disc()
	elif ID == 4: # Quit
		exit()

func _on_edit_item_pressed(ID):
	if editPopup.get_item_text(ID) == "User Settings":
		$userSettingsPopup.popup()

func _on_hostButton_pressed():
	$hostPopup.visible = false
	networkInfo["networkName"] = $hostPopup/networkName.text
	networkInfo["netSavePath"] = $hostPopup/saveDir.text + $hostPopup/networkName.text + ".dat"
	networkInfo["netPort"] = int($hostPopup/hostPort.text)
	networkInfo["netPass"] = $hostPopup/passInput.text
	check_network(networkInfo["networkName"])

func _on_joinButton_pressed():
	$joinPopup.visible = false
	filePopup.set_item_disabled(3, false)
	editPopup.set_item_disabled(0, true)
	userPass = $joinPopup/passInput.text
	ipAddress = $joinPopup/ipInput.text
	port = int($joinPopup/portInput.text)
	
	#Create a  client that will connect to the server
	var client : NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	client.create_client(ipAddress, port)
	get_tree().set_network_peer(client)
	
	#Update status and username for chatroom
	update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Trying to join to " + ipAddress)

func _on_inputText_text_entered(newText):
	if newText.length() > 0: # check for blank input
		if newText[0] == "/": # check for command input
			process_command(newText)
			$inputText.clear()
		else:
			if get_tree().has_network_peer():
				#Create the message and tell everyone else to add it to their history
				rpc("send_message", "network", OS.get_datetime(), prefs["userColor"], prefs["userAlias"], newText)
				$inputText.clear()
			else:
				update_message("local", OS.get_datetime(), prefs["userColor"], prefs["userAlias"], newText)
				$inputText.clear()

func _on_userApplyButton_pressed():
	$userSettingsPopup.visible = false
	prefs["userName"] = $userSettingsPopup/usernameInput.text
	prefs["userColor"] = $userSettingsPopup/userColor.text
	prefs["dispTimeStamps"] = $userSettingsPopup/timeBtn.pressed
	prefs["localLogLocation"] = $userSettingsPopup/logLocInput.text
	prefs["userAlias"] = $userSettingsPopup/aliasInput.text
	save_prefs()

func _on_yesBtn_pressed():
	$overwriteSave.visible = false
	sharedNetworkInfo["networkName"] = networkInfo["networkName"]
	save_localLog()
	create_userInfo(prefs["userName"], networkInfo["netPass"])
	create_network()
	save_network()

func _on_noBtn_pressed():
	$overwriteSave.visible = false

func _on_loadPopup_confirmed(): # Network selected to load
	load_network($loadPopup.current_path)
	create_network()

func _on_saveDirPopup_confirmed():
	$hostPopup/saveDir.text = $hostPopup/saveDirPopup.current_path

func _on_saveDirPopup_dir_selected(dir):
	$hostPopup/saveDir.text = dir

func _on_saveBrowseBtn_pressed():
	$hostPopup/saveDirPopup.popup()

func _on_logLocBrowseBtn_pressed():
	$userSettingsPopup/logLocPopup.popup()

func _on_logLocPopup_dir_selected(dir):
	$userSettingsPopup/logLocInput.text = dir

func _on_connectedBox_item_activated(index):
	$inputText.text += $connectedBox.get_item_text(index)

func process_command(newCommand):
	var command = newCommand.split(" ")
	if not commandList.has(command[0]):
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Invalid command, type /help for a list of commands')
	
	elif command[0] == "/buy":
		check_buy(command)
	
	elif command[0] == "/changealias":
		#change_alias(command)
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Command currently disabled')
	
	elif command[0] == "/changecolor":
		change_color(command)
	
	elif command[0] == "/changepass":
		rpc_id(1, "change_password", command)
	
	elif command[0] == "/cycle":
		add_cycle_action(command)
	
	elif command[0] == "/cyclelist":
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Cycle Actions: ")
		for item in cycleActionList:
			$messageBox.append_bbcode(item + ": " + cycleActionList[item])
			$messageBox.newline()
	
	elif command[0] == "/exec":
		check_execute(command)
	
	elif command[0] == "/help":
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Commands: ")
		for item in commandList:
			$messageBox.append_bbcode(item + ": " + commandList[item])
			$messageBox.newline()
	
	elif command[0] == "/inv":
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Inventory: ")
		for item in userInfo["inventory"]:
			$messageBox.append_bbcode(item + ": " + str(userInfo["inventory"][item]))
			$messageBox.newline()
	
	elif command[0] == "/listmodes":
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Cycle Modes: ")
		for mode in processModes:
			$messageBox.append_bbcode(mode + ": " + processModes[mode])
			$messageBox.newline()
	
	elif command[0] == "/resetpass":
		reset_password(command)
	
	elif command[0] == "/setmode":
		set_mode(command)
	
	elif command[0] == "/shoplist":
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Items: ")
		for item in shopItems:
			$messageBox.append_bbcode(item + ": " + str(shopItems[item]))
			$messageBox.newline()
	
	elif command[0] == "/startgame":
		if not get_tree().get_network_unique_id() == 1:
			update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Error: Server only command')
		else:
			start_game("Game started by host")
	
	elif command[0] == "/stopgame":
		if not get_tree().get_network_unique_id() == 1:
			update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Error: Server only command')
		else:
			stop_game("Game stopped by host")
	
	elif command[0] == "/w":
		# /w [userAlias] [message]
		send_whisper(command)

func check_execute(command):
	# Check for valid item to execute
	if not shopItems.has(command[1]):
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid item")
		return
	
	var newItem = []
	newItem.append(command[1])
	
	# Check if item has a target
	if len(command) > 2:
		newItem.append(command[2])
	
	if get_tree().get_network_unique_id() == 1:
		execute_item(newItem, 1)
	else:
		rpc_id(1, "execute_item", newItem, get_tree().get_network_unique_id())

remote func execute_item(item, userID):
	# Check if user has item in inventory
	if networkInfo["userList"][connectedList[userID]]["inventory"][item[0]] == 0:
		server_message(userID, "Unable to execute, inventory empty")
		return
	
	# Check for target
	if len(item) > 1:
		if not sharedNetworkInfo["connectedUsers"].has(item[1]):
			server_message(userID, item[0] + " failed. " + item[1] + " not connected.")
			return
	
	# Remove item from inventory and execute
	networkInfo["userList"][connectedList[userID]]["inventory"][item[0]] -= 1
	
	if item[0] == "hackWallet":
		server_message(userID, "Attempting to hack the wallet of " + item[1])
		attempt_hackWallet(item[1], userID)
	
	elif item[0] == "fortFirewall":
		fortify_firewall(userID)

func check_buy(command):
	var quantity = 1

	# Check that command is complete
	if len(command) < 2:
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Command incomplete, /buy <item> <quantity>')
		return

	# Check for valid item
	elif not shopItems.has(command[1]):
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Unknown item, type /shoplist for list of items.')
		return
	
	# Check for quantity
	if len(command) > 2:
		if typeof(command[2]) != TYPE_INT:
			update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid item quantity")
			return
		else:
			quantity = command[2]	
	
	# Send buy request
	if get_tree().get_network_unique_id() == 1:
		buy_item(command[1], quantity, 1)
	else:
		rpc_id(1, "buy_item", command[1], quantity, get_tree().get_network_unique_id())

remote func buy_item(item, quantity, userID):
	var total = shopItems[item] * quantity
	
	# Check if user has enough for purchse
	if networkInfo["userList"][connectedList[userID]]["currentCredits"] < total:
		server_message(userID, "Insufficient credits for purchase")
	
	# Make purshase
	else:
		networkInfo["userList"][connectedList[userID]]["currentCredits"] -= total
		networkInfo["userList"][connectedList[userID]]["inventory"][item] += quantity
		server_message(userID, "Purchase successful")
		if userID == 1:
			update_userInfo(networkInfo["userList"][connectedList[userID]].duplicate())
		else:
			rpc_id(1, "update_userInfo", networkInfo["userList"][connectedList[userID]].duplicate())

func add_cycle_action(command):
	# Checking for valid cycle action
	if not cycleActionList.has(command[1]):
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Invalid cycle action, type /cyclelist for a list of actions')
		return
	
	# If action has a target user, checking for valid user alias
	elif len(command) > 2:
		if not sharedNetworkInfo["connectedUsers"].has(command[2]):
			update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Unknown user: ' + command[2])
			return
	
	# If user, send action to server
	if get_tree().get_network_unique_id() != 1:
		rpc_id(1, "set_cycle_action", get_tree().get_network_unique_id(), command)
	
	# If server, add action
	else:
		set_cycle_action(1, command)

remote func set_cycle_action(senderID, command):
	# Formatting users cycle action into array, with first element being the action,
	# and the second being an optional target
	var formattedAction = []
	formattedAction.append(command[1])
	if len(command) > 2:
		formattedAction.append(command[2])
	
	networkInfo["userList"][connectedList[senderID]]["cycleActions"].append(formattedAction)
	server_message(senderID, "Cycle action added")

func create_network():
	# Adjusting popup buttons
	filePopup.set_item_disabled(3, false)
	editPopup.set_item_disabled(0, true)
	
	# Creating multiplayer server
	var server : NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	server.create_server(networkInfo["netPort"],MAX_PLAYERS)
	get_tree().set_network_peer(server)
	
	# Loading and setting network variables
	autosave_network(networkInfo["autosaveInterval"])
	sharedNetworkInfo["networkName"] = networkInfo["networkName"]
	sharedNetworkInfo["messageLog"] = networkInfo["messageLog"].duplicate()
	load_localLog()
	sync_messages()
	cycleTimer = Timer.new()
	add_child(cycleTimer)
	cycleTimer.wait_time = networkInfo["cycleDuration"]
	cycleTimer.connect("timeout", self, "_process_cycle")
	
	# Loading network host data
	update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Server hosted on port " + str(port))
	add_user(get_tree().get_network_unique_id(), prefs["userName"], prefs["userAlias"])
	refresh_connectedList()
	if not networkInfo["userList"].has(prefs["userName"]):
		create_userInfo(prefs["userName"], networkInfo["netPass"])
	update_userInfo(networkInfo["userList"][prefs["userName"]].duplicate())

func start_game(startMessage):
	rpc("send_message", "network", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], startMessage)
	cycleTimer.start()
	
	# creating process order list
	sharedNetworkInfo["processOrder"].clear()
	for userAlias in sharedNetworkInfo["connectedUsers"]:
		sharedNetworkInfo["processOrder"].append(userAlias)
	sharedNetworkInfo["processOrder"].shuffle()
	rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())

func stop_game(stopMessage):
	rpc("send_message", "network", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], stopMessage)
	cycleTimer.stop()

func _process_cycle():
	# Calculating how many credits to generate
	var cycleCredits = networkInfo["baseCredits"] * len(connectedList)
	
	rpc("send_message", "network", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Generated " + str(cycleCredits) + " credits this cycle")
	
	# Giving credits to each connected user and processing user modes
	for user in connectedList:
		# Awarding credits
		networkInfo["userList"][connectedList[user]]["currentCredits"] += cycleCredits * networkInfo["userList"][connectedList[user]]["creditMult"]
		networkInfo["userList"][connectedList[user]]["totalCredits"] += cycleCredits * networkInfo["userList"][connectedList[user]]["creditMult"]
		
		# Processing user modes
		if networkInfo["userList"][connectedList[user]]["processMode"] == "balanced":
			networkInfo["userList"][connectedList[user]]["attack"] += .1
			networkInfo["userList"][connectedList[user]]["defense"] += .1
			networkInfo["userList"][connectedList[user]]["creditMult"] += .1
			
		elif networkInfo["userList"][connectedList[user]]["processMode"] == "attack":
			networkInfo["userList"][connectedList[user]]["attack"] += .3
			
		elif networkInfo["userList"][connectedList[user]]["processMode"] == "defense":
			networkInfo["userList"][connectedList[user]]["defense"] += .3
			
		elif networkInfo["userList"][connectedList[user]]["processMode"] == "creditMult":
			networkInfo["userList"][connectedList[user]]["creditMult"] += .3
		
		# Incrementing users active cycles
		networkInfo["userList"][connectedList[user]]["activeCycles"] += 1
		
		# Updating each users userInfo
		if user == 1:
			update_userInfo(networkInfo["userList"][connectedList[user]].duplicate())
		else:
			rpc_id(user, "update_userInfo", networkInfo["userList"][connectedList[user]].duplicate())
	
	# Processing user cycle actions
	for userAlias in sharedNetworkInfo["processOrder"]:
		var userID = aliasToID[userAlias]
		var uname = connectedList[userID]
		# Checking if user has added any actions
		if not networkInfo["userList"][uname]["cycleActions"].empty():
			# Process action then remove from array
			process_action(networkInfo["userList"][uname]["cycleActions"][0], userID)
			networkInfo["userList"][uname]["cycleActions"].pop_front()
	
	# Adjusting process order, putting first user and the end of the array
	var topUser = sharedNetworkInfo["processOrder"][0]
	sharedNetworkInfo["processOrder"].pop_front()
	sharedNetworkInfo["processOrder"].append(topUser)
	rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
	rpc("refresh_statusBox")

func process_action(action, userID):
	# NEED TO CHECK IF ACTION HAS A TARGET, AND IF THAT TARGET IS STILL CONNECTED FIRST
	if len(action) > 1:
		# Action has a target, checking if alias still connected
		if not sharedNetworkInfo["connectedUsers"].has(action[1]):
			server_message(userID, action[0] + " failed. " + action[1] + " not connected.")
			return

	if action[0] == "hackWallet":
		server_message(userID, "Attempting to hack the wallet of " + action[1])
		attempt_hackWallet(action[1], userID)
	
	elif action[0] == "fortFirewall":
		fortify_firewall(userID)

func fortify_firewall(userID):
	# If current firewall level is less than max level, increase by 1
	if networkInfo["userList"][connectedList[userID]]["firewallLevel"] < networkInfo["maxFirewallLevel"]:
		networkInfo["userList"][connectedList[userID]]["firewallLevel"] += 1
		
		var curLevel = networkInfo["userList"][connectedList[userID]]["firewallLevel"]
		server_message(userID, "Firewall level increased to " + str(curLevel))
		if userID != 1: # Preventing self rpc_id call for server
			rpc_id(userID, "update_userInfo", networkInfo["userList"][connectedList[userID]].duplicate())
		else:
			update_userInfo(networkInfo["userList"][connectedList[userID]].duplicate())
	
	else:
		server_message(userID, "Firewall already at max level")

func attempt_hackWallet(targetAlias, attemptUserID):
	# If attack is successful
	if attack_outcome(targetAlias, attemptUserID):
		var defID = aliasToID[targetAlias]
		
		# If defender has active firewall
		if networkInfo["userList"][connectedList[defID]]["firewallLevel"] > 0:
			server_message(attemptUserID, "Hack was blocked by firewall!")
			networkInfo["userList"][connectedList[defID]]["firewallLevel"] -= 1
			server_message(defID, "Firewall blocked a hack attempt, and lost 1 level")
			if defID != 1: # Preventing self rpc_id call for server
				rpc_id(defID, "update_userInfo", networkInfo["userList"][connectedList[defID]].duplicate())
			else:
				update_userInfo(networkInfo["userList"][connectedList[defID]].duplicate())
		
		# No active firewall, attack fully successful
		else:
			# Determine how much is stolen, random between 5-15%
			var hackPct = rng.randf_range(0.05, 0.15)
			var hackAmount = int(round(networkInfo["userList"][connectedList[defID]]["currentCredits"] * hackPct))
			
			# Subtract funds for defender and send message
			networkInfo["userList"][connectedList[defID]]["currentCredits"] -= hackAmount
			server_message(defID, "ALERT! Wallet was succesfully hacked for " + str(hackAmount) + " credits!")
			if defID != 1: # Prevent self rpc_id call for server
				rpc_id(defID, "update_userInfo", networkInfo["userList"][connectedList[defID]].duplicate())
			else:
				update_userInfo(networkInfo["userList"][connectedList[defID]].duplicate())
			
			# Add funds for attacker and send message
			networkInfo["userList"][connectedList[attemptUserID]]["currentCredits"] += hackAmount
			networkInfo["userList"][connectedList[attemptUserID]]["totalCredits"] += hackAmount
			server_message(attemptUserID, targetAlias + " succesfully hacked for " + str(hackAmount) + " credits!")
			if attemptUserID != 1: # Prevent self rpc_id call for server
				rpc_id(attemptUserID, "update_userInfo", networkInfo["userList"][connectedList[attemptUserID]].duplicate())
			else:
				update_userInfo(networkInfo["userList"][connectedList[attemptUserID]].duplicate())
		
	# Attack failed
	else:
		server_message(attemptUserID, "Failed to hack wallet of " + targetAlias)

func attack_outcome(defAlias, attID):
	# Return true if an attack is succesful
	var defID = aliasToID[defAlias]
	var def = networkInfo["userList"][connectedList[defID]]["defense"]
	var att = networkInfo["userList"][connectedList[attID]]["attack"]
	
	rng.randomize()
	
	if rng.randf_range(0, def + att) <= att:
		return(true)
	else:
		return(false)

func connected():
	update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Connection succesful, attempting login...")
	rpc_id(1, "net_login", prefs["userName"], userPass, prefs["userAlias"])

func connected_fail():
	print("Failed to connect")
	update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Couldn't connect try again, or host?")

func server_disconnected():
	#Server just closed
	print("server_disconnected")
	save_localLog()
	$connectedBox.clear()
	$messageBox.clear()
	filePopup.set_item_disabled(3, true)
	editPopup.set_item_disabled(0, false)
	update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Server Closed")

func add_user(ID, userName, alias):
	connectedList[ID] = userName
	sharedNetworkInfo["connectedUsers"][alias] = ID
	sharedNetworkInfo["processOrder"].append(alias)
	aliasToID[alias] = ID
	IDtoAlais[ID] = alias
	
	if ID == 1:
		update_userInfo(networkInfo["userList"][userName].duplicate())
	else:
		rpc_id(ID, "update_userInfo", networkInfo["userList"][userName].duplicate())
	
	rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
	rpc("refresh_connectedList")
	rpc("send_message", "network", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], alias + " connected")
	if not networkInfo["gameRunning"]:
		if len(connectedList) >= networkInfo["minUsers"]:
			start_game("Sufficient users connected, beginning game")

func user_left(ID):
	if get_tree().get_network_unique_id() == 1: # Only run on server
		if connectedList.has(ID): # If client failed to login, skip
			var discAlias = IDtoAlais[ID]
			rpc("send_message", "network", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], IDtoAlais[ID] + " disconnected")
			connectedList.erase(ID) # remove  from connectedList
			aliasToID.erase(discAlias)
			IDtoAlais.erase(ID)
			sharedNetworkInfo["connectedUsers"].erase(discAlias)
			sharedNetworkInfo["processOrder"].erase(discAlias)
			rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
			rpc("refresh_connectedList")
			rpc("refresh_statusBox")
			if len(connectedList) < networkInfo["minUsers"]:
				stop_game("Insufficient users, game stopped")

remote func update_sharedNetworkInfo(newInfo):
	sharedNetworkInfo = newInfo.duplicate()
	refresh_statusBox()

remotesync func refresh_connectedList():
	$connectedBox.clear()
	var current_aliases = sharedNetworkInfo["connectedUsers"].keys()
	for line in current_aliases:
		$connectedBox.add_item(line)

remote func update_message(messageType, dateTime, color, name, newText):
	var newMessage = "[color=" + color + "]" + name + ": "+"[/color]" + newText + "\n"
	if prefs["dispTimeStamps"] == false:
		$messageBox.append_bbcode(newMessage)
	else:
		$messageBox.append_bbcode(get_formatted_time(dateTime) + newMessage)
	if messageType == "network":
		if get_tree().get_network_unique_id() == 1:
			networkInfo["messageLog"].append([dateTime, newMessage])
			sharedNetworkInfo["messageLog"].append([dateTime, newMessage])
			rset("sharedNetworkInfo", sharedNetworkInfo.duplicate())
	elif messageType == "local":
		localLog.append([dateTime, newMessage])
		save_localLog()
	elif messageType == "sys":
		pass
	else:
		pass

func simple_update(datedMessage):
	if prefs["dispTimeStamps"] == false:
		$messageBox.append_bbcode(datedMessage[1])
	else:
		$messageBox.append_bbcode(get_formatted_time(datedMessage[0]) + datedMessage[1])

func sync_messages(): # Printing shared and local message in order of time stamp
	var totalMessages = len(sharedNetworkInfo["messageLog"]) + len(localLog)
	var localIndex = 0
	var sharedIndex = 0
	
	for i in range(totalMessages - 0):
		# At end of local log, only print network
		if localIndex == len(localLog):
			simple_update(sharedNetworkInfo["messageLog"][sharedIndex])
			sharedIndex += 1
			
		# At end of network log, only print local
		elif sharedIndex == len(sharedNetworkInfo["messageLog"]):
			simple_update(localLog[localIndex])
			localIndex += 1

		# Network message is more recent
		elif OS.get_unix_time_from_datetime(sharedNetworkInfo["messageLog"][sharedIndex][0]) <= OS.get_unix_time_from_datetime(localLog[localIndex][0]):
			simple_update(sharedNetworkInfo["messageLog"][sharedIndex])
			sharedIndex += 1
			
		# Local message is more recent
		else:
			simple_update(localLog[localIndex])
			localIndex += 1

remotesync func send_message(messageType, curTime, color, name, newText):
	update_message(messageType, curTime, color, name, newText)

func disc(): # Disconnect but dont close
	# If not server host
	if get_tree().get_network_unique_id() != 1:
		get_tree().network_peer = null
		connectedList.clear()
		save_localLog()
		$connectedBox.clear()
		$messageBox.clear()
		$statusBox.clear()
		filePopup.set_item_disabled(3, true)
		editPopup.set_item_disabled(0, false)
	else:
		get_tree().network_peer = null
		saveTimer.stop()
		save_localLog()
		save_network()
		connectedList.clear()
		$connectedBox.clear()
		$messageBox.clear()
		$statusBox.clear()
		filePopup.set_item_disabled(3, true)
		editPopup.set_item_disabled(0, false)

func exit():
	# If not server host
	if get_tree().get_network_unique_id() != 1:
		get_tree().network_peer = null
		save_localLog()
		get_tree().quit()
	
	else:
		get_tree().network_peer = null
		saveTimer.stop()
		save_localLog()
		save_network()
		connectedList.clear()
		$connectedBox.clear()
		$messageBox.clear()
		get_tree().quit()

func save_prefs():
	var prefsPath = "user://preferences.dat"
	var file = File.new()
	file.open(prefsPath, File.WRITE)
	file.store_var(prefs)
	file.close()

func load_prefs():
	var prefsPath = "user://preferences.dat"
	var file = File.new()
	if not file.file_exists(prefsPath):
		save_prefs()
	file.open(prefsPath, File.READ)
	prefs = file.get_var()
	file.close()
	
	$userSettingsPopup/usernameInput.text = prefs["userName"]
	$userSettingsPopup/userColor.text = prefs["userColor"]
	$userSettingsPopup/logLocInput.text = prefs["localLogLocation"]
	$userSettingsPopup/aliasInput.text = prefs["userAlias"]

func create_userInfo(userName, password):
	networkInfo["userList"][userName] = {}
	networkInfo["userList"][userName]["userName"] = userName
	networkInfo["userList"][userName]["userPass"] = password
	networkInfo["userList"][userName]["currentCredits"] = 100
	networkInfo["userList"][userName]["creditMult"] = 1.0
	networkInfo["userList"][userName]["attack"] = 1.0
	networkInfo["userList"][userName]["defense"] = 1.0
	networkInfo["userList"][userName]["totalCredits"] = 100
	networkInfo["userList"][userName]["processMode"] = "balanced"
	networkInfo["userList"][userName]["cycleActions"] = []
	networkInfo["userList"][userName]["activeCycles"] = 0
	networkInfo["userList"][userName]["firewallLevel"] = 0
	networkInfo["userList"][userName]["inventory"] = emptyInventory.duplicate()

remote func update_userInfo(newUserInfo):
	userInfo = newUserInfo.duplicate()
	refresh_statusBox()

remote func refresh_statusBox():
	# Formatting process order
#	var totalUsers = len(sharedNetworkInfo["processOrder"])
#	var userPlace = sharedNetworkInfo["processOrder"].find(prefs["userAlias"])
#	var procPlace = str(userPlace + 1) + "/" + str(totalUsers)
	
	$statusBox.clear()
	$statusBox.add_item("User name: " + userInfo["userName"])
	$statusBox.add_item("Alias: " + prefs["userAlias"])
	$statusBox.add_item("Process Mode: " + userInfo["processMode"])
	$statusBox.add_item("Firewall Level: " + str(userInfo["firewallLevel"]))
	# Process order turned off because it was not working for the server
	# clients seemed to display correctly, but the server would duplicate
	# a random clients process place
	#$statusBox.add_item("Process Order: " + procPlace)
	$statusBox.add_item("Credits: " + str(userInfo["currentCredits"]))
	$statusBox.add_item("Credit mult: " + str(userInfo["creditMult"]))
	$statusBox.add_item("Attack: " + str(userInfo["attack"]))
	$statusBox.add_item("Defense: " + str(userInfo["defense"]))
	$statusBox.add_item("Total credits: " + str(userInfo["totalCredits"]))
	$statusBox.add_item("Active Cycles: " + str(userInfo["activeCycles"]))

func check_network(networkName): # Check if save already exists before overwriting
	var file = File.new()
	if file.file_exists(networkInfo["netSavePath"]):
		$overwriteSave/warningLabel.text = "File " + networkName + ".dat already exists. Overwrite?"
		$overwriteSave.visible = true
	else:
		save_network()
		save_localLog()
		create_userInfo(prefs["userName"], networkInfo["netpass"])
		create_network()

func load_localLog():
	var logPath = prefs["localLogLocation"] + sharedNetworkInfo["networkName"] + "Log.dat"
	print("loading local log at: " + str(prefs["localLogLocation"]))
	var file = File.new()
	if file.file_exists(logPath):
		file.open(logPath, File.READ)
		localLog = file.get_var()
		file.close()
	else:
		file.close()
		save_localLog()

func save_localLog():
	var logPath = prefs["localLogLocation"] + sharedNetworkInfo["networkName"] + "Log.dat"
	var file = File.new()
	file.open(logPath, File.WRITE)
	file.store_var(localLog)
	file.close()

func save_network():
	print("saving network file at: " + networkInfo["netSavePath"])
	var file = File.new()
	file.open(networkInfo["netSavePath"], File.WRITE)
	file.store_var(networkInfo)
	file.close()

func load_network(filePath):
	networkInfo["netSavePath"] = filePath
	print("opening file: " + filePath)
	var file = File.new()
	file.open(filePath, File.READ)
	networkInfo = file.get_var()
	file.close()

func autosave_network(interval):
	saveTimer = Timer.new()
	add_child(saveTimer)
	saveTimer.wait_time = interval
	saveTimer.connect("timeout", self, "_autosave_timeout")
	saveTimer.start()

func _autosave_timeout():
	print("autosave network")
	save_network()

remote func net_login(userName, password, alias):
	var senderID = get_tree().get_rpc_sender_id()
	var currentList = connectedList.values()
	print(userName + " connected with pass: " + str(password))
	
	if get_tree().get_network_unique_id() == 1: # Checking that only run by server
		if currentList.has(userName): # Checking if username is already connected
			rpc_id(get_tree().get_rpc_sender_id(), "login_fail", "User already logged in")
		
		# Checking if the user has logged in before
		elif networkInfo["userList"].has(userName): 
			# Login success for returning user
			if networkInfo["userList"][userName]["userPass"] == password:
				rpc_id(get_tree().get_rpc_sender_id(), "update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
				rpc_id(get_tree().get_rpc_sender_id(), "login_success")
				rpc_id(get_tree().get_rpc_sender_id(), "update_userInfo", networkInfo["userList"][userName].duplicate())
				add_user(senderID, userName, check_alias(alias, senderID))
			else:
				# Returning user used incorrect password
				rpc_id(get_tree().get_rpc_sender_id(), "login_fail", "Invalid password")
			
		# First time user
		elif password == networkInfo["netPass"]:
			# Login success for first time user
			create_userInfo(userName, password)
			rpc_id(get_tree().get_rpc_sender_id(), "update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
			rpc_id(get_tree().get_rpc_sender_id(), "login_success")
			rpc_id(get_tree().get_rpc_sender_id(), "update_userInfo", networkInfo["userList"][userName].duplicate())
			add_user(senderID, userName, check_alias(alias, senderID))
		
		else:
			rpc_id(get_tree().get_rpc_sender_id(), "login_fail", "Invalid login info")

func check_alias(alias, senderID):
	# Checking if alias is already in use
	if not sharedNetworkInfo["connectedUsers"].has(alias):
		return(alias)
	# Alias already in use,
	# Appending number to alias to avoid duplicates
	else: 
		var aliasNum = 1
		var newAlias = alias + str(aliasNum)
		while sharedNetworkInfo["connectedUsers"].has(newAlias):
			aliasNum +=1
			newAlias = alias + str(aliasNum)
		rpc_id(senderID, "client_update_alias", newAlias)
		return(newAlias)

remote func login_success():
	load_localLog()
	$messageBox.clear()
	sync_messages()
	update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Login succesful")

remote func login_fail(message):
	update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], message)
	get_tree().network_peer = null
	filePopup.set_item_disabled(3, true)
	editPopup.set_item_disabled(0, false)

remote func server_message(targetID, message):
	if targetID == 1:
		update_message("local", OS.get_datetime(), "silver", "SERVER", message)
	else:
		rpc_id(targetID, "update_message", "local", OS.get_datetime(), "silver", "SERVER", message)

func get_formatted_time(dateTime):
	var hour = str(dateTime["hour"])
	var minute = str(dateTime["minute"])
	var second = str(dateTime["second"])
	
	if len(hour) == 1:
		hour = "0" + hour
	if len(minute) == 1:
		minute = "0" + minute
	if len(second) == 1:
		second = "0" + second
	
	var formattedTime = hour + ":" + minute + ":" + second
	return(formattedTime)

remote func client_update_alias(newAlias):
	prefs["userAlias"] = newAlias

func send_whisper(command):
	var wMessage = ""
	for i in range(2, len(command)):
		wMessage += " " + command[i]
	if not sharedNetworkInfo["connectedUsers"].has(command[1]):
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Unknown user: " + command[1])
	else:
		rpc_id(sharedNetworkInfo["connectedUsers"][command[1]], "send_message", "local",
		OS.get_datetime(), prefs["userColor"], prefs["userAlias"], "<w>" + command[1] + ": " + wMessage)
		update_message("local", OS.get_datetime(), prefs["userColor"], prefs["userAlias"], "<w>" + command[1] + ": " + wMessage)

remote func change_password(command):
	if command[0] == "/resetpass": # User requested password reset
		networkInfo["userList"][connectedList[get_tree().get_rpc_sender_id()]]["userPass"] = networkInfo["netPass"]
		rpc_id(get_tree().get_rpc_sender_id(), "server_message", "Password succesfully reset")

	elif get_tree().get_network_unique_id() == 1: # Only run following on server
		if not len(command) >= 2:
			rpc_id(get_tree().get_rpc_sender_id(), "server_message", "Invalid syntax: /changepass <new password>")
	
		else:
			var newPass = command[1]
			networkInfo["userList"][connectedList[get_tree().get_rpc_sender_id()]]["userPass"] = newPass
			save_network()
			rpc_id(get_tree().get_rpc_sender_id(), "server_message", "Password succesfully changed")

func reset_password(command):
	if not get_tree().get_network_unique_id() == 1: # If user is reseting their own pass
		rpc_id(1, "change_password", command)
	
	elif not len(command) >= 2:
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid syntax: /resetpass <user>")
		
	elif not networkInfo["userList"].has(command[1]):
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Unknown user: " + str(command[1]))
		
	else:
		networkInfo["userList"][command[1]]["userPass"] = networkInfo["netPass"]
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Password reset for " + str(command[1]))

func change_alias(command):
	if len(command) != 2:
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid syntax: /changealias <newalias>")
	else:
		if not get_tree().get_network_unique_id() == 1: # If not server
			rpc_id(1, "update_alias", command[1], prefs["userAlias"], get_tree().get_network_unique_id())
		else:
			update_alias(command[1], prefs["userAlias"], 1)

remote func update_alias(alias, oldAlias, ID):
	if get_tree().get_network_unique_id() == 1: # Only run on server
		var newAlias = check_alias(alias, ID)
		sharedNetworkInfo["connectedUsers"].erase(oldAlias)
		aliasToID.erase(oldAlias)
		IDtoAlais.erase(ID)
		sharedNetworkInfo["connectedUsers"][newAlias] = ID
		aliasToID[newAlias] = ID
		IDtoAlais[ID] = newAlias
		if ID != 1:
			rpc_id(ID, "client_update_alias", newAlias)
		rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
		rpc("refresh_connectedList")

func change_color(command):
	if len(command) != 2:
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid syntax: /changecolor <newcolor>")
	else:
		prefs["userColor"] = command[1]
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "User color changed to " + command[1])

func set_mode(command):
	if len(command) != 2:
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid syntax: /changemode <newmode>")
	elif not processModes.has(command[1]):
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Unknown process mode, type /listmodes to see all available modes")
	else:
		if get_tree().get_network_unique_id() == 1: # If server
			networkInfo["userList"][prefs["userName"]]["processMode"] = command[1]
			update_userInfo(networkInfo["userList"][prefs["userName"]].duplicate())
		else:
			rpc_id(1, "update_user_mode", command[1])

remote func update_user_mode(newMode):
	var sender = connectedList[get_tree().get_rpc_sender_id()]
	networkInfo["userList"][sender]["processMode"] = newMode
	rpc_id(get_tree().get_rpc_sender_id(), "update_userInfo", networkInfo["userList"][sender].duplicate())

