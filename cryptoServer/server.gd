extends Node

var aliasToID = {} # List of users with alias's as keys and ID's as values
var connectedList = {} # List of connected users, keys are ID's, values are usernames
var cycleTimer
var ddosTimer
var dedicated = false
var emptyInventory = {
	"changeAlias": 0,
	"forceSkip": 0,
	"fortFirewall": 0,
	"hackWallet": 0,
	"shuffleProc": 0,
	"traceRoute": 0}
var gameRunning = false
var IDtoAlais = {} # Reversed list of users with IDs as keys and aliases as values
var MAX_PLAYERS = 32
var messageLog = []
var networkInfo = {
	"adminList": "",
	"autosaveInterval": 10,
	"banList": "",
	"baseCredits": 10,
	"cycleDuration": 10,
	"ddosThreshold": 5,
	"maxFirewallLevel": 1,
	"minUsers": 2,
	"netPass": "password",
	"netPort": 42420,
	"networkName": "defaultNet"}
var rng = RandomNumberGenerator.new()
var saveTimer
var sharedNetworkInfo = {
	"networkName":"temp",
	"messageLog": [],
	"connectedUsers": {},
	"processOrder": [],
	"userMaxCreds": {}}
var shopItems = {
	"changeAlias": 250,
	"forceSkip": 75,
	"fortFirewall": 50,
	"hackWallet": 100,
	"shuffleProc": 15,
	"traceRoute": 75}
var skipList = []
var userList = {} # Saves user data on the network, keys are user names
var version = "0.0.1"

func _ready():
	dedicated = true
	
	print("Starting server...")
	rng.randomize()
	get_tree().connect("network_peer_disconnected",self,"user_left")
	create_dedicated_network()

func _autosave_timeout():
	save_network()

func _ddos_timeout():
	for user in connectedList:
		if userList[connectedList[user]]["ddosLevel"] > 0:
			userList[connectedList[user]]["ddosLevel"] -= 1
			rpc_id(user, "update_userInfo", userList[connectedList[user]].duplicate())

func _process_cycle():
# Function called at end of every game cycle. Awards stats and credits, 
# and processes cycle actions

	# Only run on server
	if get_tree().is_network_server():
			
		# Calculating how many credits to generate
		var cycleCredits = int(networkInfo["baseCredits"] + len(connectedList))
		
		# Giving credits to each connected user and processing user modes
		for user in connectedList:
			# Skip user if on skipList
			if skipList.has(IDtoAlais[user]):
				server_message(user, "sys", "Cycle skipped due to malicious activity")
				return
			
			# Awarding credits
			var userCredits = int(cycleCredits * log(userList[connectedList[user]]["creditMult"]))
			userList[connectedList[user]]["currentCredits"] += userCredits
			if userList[connectedList[user]]["currentCredits"] > userList[connectedList[user]]["maxCredits"]:
				userList[connectedList[user]]["maxCredits"] = userList[connectedList[user]]["currentCredits"]
				sharedNetworkInfo["userMaxCreds"][IDtoAlais[user]] = userList[connectedList[user]]["maxCredits"]
			server_message(user, "sys", "Credit income: " + str(userCredits))
			
			# Processing user modes
			process_user_mode(user)
			
			# Incrementing users active cycles
			userList[connectedList[user]]["activeCycles"] += 1
			
			# Updating each users userInfo
			rpc_id(user, "update_userInfo", userList[connectedList[user]].duplicate())
		
		# Processing user cycle actions
		for userAlias in sharedNetworkInfo["processOrder"]:
			# Skipping player if on skiplist
			if skipList.has(userAlias):
				return
			
			var userID = aliasToID[userAlias]
			var uname = connectedList[userID]
			# Checking if user has added any actions
			if not userList[uname]["cycleActions"].empty():
				# Process action then remove from array
				process_action_server(userList[uname]["cycleActions"][0], userID)
				userList[uname]["cycleActions"].pop_front()
		
		# Clearing network skiplist
		skipList.clear()
		
		# Adjusting process order, putting first user and the end of the array
		var topUser = sharedNetworkInfo["processOrder"][0]
		sharedNetworkInfo["processOrder"].pop_front()
		sharedNetworkInfo["processOrder"].append(topUser)
		rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
		
		# Let users know a new cycle has started
		rpc("new_cycle")

func activate_traceRoute(userID, tracedID):
# Alerts user if their traceRoute is activated, then gives them an attack bonus vs traced user
	
	# Remove used trace route
	userList[connectedList[userID]]["traceRoute"] -= 1
	server_message(userID, "sys", 'Trace Route activated, network breached by ' + IDtoAlais[tracedID])
	rpc_id(userID, "Trace Route activated", IDtoAlais[tracedID])
	rpc_id(userID, "update_userInfo", userList[connectedList[userID]].duplicate())
	
	# Add attack bonus to traced user
	if userList[connectedList[userID]]["hackModifier"].has(connectedList[tracedID]):
		userList[connectedList[userID]]["hackModifier"][connectedList[tracedID]] += .5
	else:
		userList[connectedList[userID]]["hackModifier"][connectedList[tracedID]] = .5

func add_user(ID, userName, alias):
# Called when a user connects to the network. Adds their info to various lists,
# and sends info to other connected users. If minimum players reached to start
# game, the game is started.

	if dedicated:
		print(userName + " connected")
	connectedList[ID] = userName
	sharedNetworkInfo["connectedUsers"][alias] = ID
	sharedNetworkInfo["userMaxCreds"][alias] = userList[userName]["maxCredits"]
	sharedNetworkInfo["processOrder"].append(alias)
	aliasToID[alias] = ID
	IDtoAlais[ID] = alias
	
	rpc_id(ID, "update_userInfo", userList[userName].duplicate())
	
	rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
	rpc("refresh_connectedList")
	rpc("receive_message", "notice", OS.get_datetime(), "silver", "SERVER", alias + " connected")
	if not gameRunning:
		if len(connectedList) >= networkInfo["minUsers"]:
			start_game("Sufficient users connected, beginning game")

func attack_outcome(defAlias, attID, attackType):
# Calculates whether an attack is succesfull based on users attack
# and defense stats, firewall status, and ddos protection.
# Returns true if successful, false if you suck 

	var defID = aliasToID[defAlias]
	var outcome = false
	
	var def = userList[connectedList[defID]]["defense"]
	var att = userList[connectedList[attID]]["attack"]
	
	# Check for attack modifiers
	if userList[connectedList[attID]]["hackModifier"].has(connectedList[defID]):
		att += userList[connectedList[attID]]["hackModifier"][connectedList[defID]]
	
	# Because you can never be too random
	rng.randomize()
	
	# Attempt attack
	if rng.randf_range(0, def + att) <= att:
		# If defender has sufficient ddos level
		if userList[connectedList[defID]]["ddosLevel"] > networkInfo["ddosThreshold"]:
			server_message(attID, "sys", "Hack stopped by network DDOS protection")
			rpc_id(attID, "log_activity", attackType, defAlias, "fail", "Hack stopped by DDOS protection!")
		
		# If successful, check for firewall
		elif userList[connectedList[defID]]["firewallLevel"] > 0:
			server_message(attID, "sys", "Hack was blocked by firewall!")
			rpc_id(attID, "log_activity", attackType, defAlias, "fail", "Hack was blocked by firewall!")
			userList[connectedList[defID]]["firewallLevel"] -= 1
			server_message(defID, "sys", "Firewall blocked a hack attempt, and lost 1 level")
			rpc_id(defID, "log_activity", "Firewall Breach", "self")
			rpc_id(defID, "update_userInfo", userList[connectedList[defID]].duplicate())
		
		# Else attack successfull
		else:
			outcome = true
			
			# If defender had active traceRoute
			if userList[connectedList[defID]]["traceRoute"] > 0:
				activate_traceRoute(defID, attID)
			
			# Increase defenders ddos level
			userList[connectedList[defID]]["ddosLevel"] += 5
	
	return outcome

func attempt_hackWallet(targetAlias, attemptUserID):
# Determines if an attackWallet attempt is succesfull, and transferes
# credits accordingly
	
	# Check if target is connected
	if not sharedNetworkInfo["connectedUsers"].has(targetAlias):
		server_message(attemptUserID, "sys", "hackWallet failed. " + targetAlias + " not connected.")
		rpc_id(attemptUserID, "log_activity", "hackWallet", targetAlias, "fail", "User not connected")
	
	# Checking for self hack
	if targetAlias == IDtoAlais[attemptUserID]:
		server_message(attemptUserID, "sys", "hackWallet failed. Self hacks not allowed.")
		rpc_id(attemptUserID, "log_activity", "hackWallet", targetAlias, "fail", "Self hacks not allowed")
		return
	
	server_message(attemptUserID, "sys", "Attempting to hack the wallet of " + targetAlias)
	
	# If attack is successful
	if attack_outcome(targetAlias, attemptUserID, "hackWallet"):
		var defID = aliasToID[targetAlias]
			
		# Determine how much is stolen, random between 5-15%
		var hackPct = rng.randf_range(0.05, 0.15)
		var hackAmount = int(round(userList[connectedList[defID]]["currentCredits"] * hackPct))
			
		# Subtract funds and notify defender
		userList[connectedList[defID]]["currentCredits"] -= hackAmount
		server_message(defID, "sys", "ALERT! Wallet was succesfully hacked for " + str(hackAmount) + " credits!")
		rpc_id(defID, "log_activity", "Wallet Hacked", "self", "", "Hack amount: " + str(hackAmount))
		rpc_id(defID, "update_userInfo", userList[connectedList[defID]].duplicate())
		
		# Add funds to attacker
		userList[connectedList[attemptUserID]]["currentCredits"] += hackAmount
		
		# Check max creds for attacker
		if userList[connectedList[attemptUserID]]["currentCredits"] > userList[connectedList[attemptUserID]]["maxCredits"]:
			userList[connectedList[attemptUserID]]["maxCredits"] = userList[connectedList[attemptUserID]]["currentCredits"]
			sharedNetworkInfo["userMaxCreds"][IDtoAlais[attemptUserID]] = userList[connectedList[attemptUserID]]["maxCredits"]
		
		# Notify and update attacker
		server_message(attemptUserID, "sys", targetAlias + " succesfully hacked for " + str(hackAmount) + " credits!")
		rpc_id(attemptUserID, "log_activity", "hackWallet", targetAlias, "success", "Hack amount: " + str(hackAmount))
		rpc_id(attemptUserID, "update_userInfo", userList[connectedList[attemptUserID]].duplicate())
		
	# Attack failed
	else:
		server_message(attemptUserID, "sys", "Failed to hack wallet of " + targetAlias)
		rpc_id(attemptUserID, "log_activity", "hackWallet", targetAlias, "fail")

func autosave_network(interval):
# Sets up and starts network autosave timer
	saveTimer = Timer.new()
	add_child(saveTimer)
	saveTimer.wait_time = interval
	saveTimer.connect("timeout", self, "_autosave_timeout")
	saveTimer.start()

remote func ban_user(banAlias):
# Remote admin function for banning a player
	var senderID = get_tree().get_rpc_sender_id()
	var banUser

	# Check for admin rights
	if check_admin(senderID):
		# Check for valid alias to ban
		if aliasToID.has(banAlias):
			# Getting the username of the alias
			banUser = connectedList[aliasToID[banAlias]]
		# Invalid alias
		else:
			server_message(senderID, "notice", "Invalid alias")
			return
		
		# Add user to ban list
		if networkInfo["banList"].length() == 0:
			networkInfo["banList"] += banUser
		else:
			networkInfo["banList"] += ("," + banUser)
		
		# Kick user from server
		rpc_id(aliasToID[banAlias], "remote_quit")
		print(connectedList[aliasToID[banAlias]] + " banned by admin")
	
	else:
		server_message(senderID, "notice", "No admin rights")

remote func broadcast_message(messageType, curTime, color, name, newText):
# Used as the main method of sending messages between users

	# Send message to connected users
	rpc("receive_message", messageType, curTime, color, name, newText)

	# Log message
	var newMessage = "[color=" + color + "]" + name + ": "+"[/color]" + newText + "\n"
	messageLog.append([curTime, newMessage])
	sharedNetworkInfo["messageLog"].append([curTime, newMessage])

remote func buy_item(item, quantity, userID):
# Checks if user has enough credits to make purchase, then
# adds items to users inventory

	# Only run on server
	if get_tree().is_network_server():
		var total = shopItems[item] * quantity
		
		# Check if user has enough for purchase
		if userList[connectedList[userID]]["currentCredits"] < total:
			server_message(userID, "sys", "Insufficient credits for purchase")
		
		# Make purchase
		else:
			userList[connectedList[userID]]["currentCredits"] -= total
			userList[connectedList[userID]]["inventory"][item] += quantity
			server_message(userID, "sys", "Purchase successful")
			rpc_id(userID, "update_userInfo", userList[connectedList[userID]].duplicate())

func change_alias(newAlias, userID):
# Called when user executes a changeAlias item
# Replaces old alias with a new one for the user

	# Check that alias is not already in use
	var checkedAlias = check_alias(newAlias, userID)
	
	# Update relevant lists with new alias
	var oldAlias = IDtoAlais[userID]
	IDtoAlais[userID] = checkedAlias
	aliasToID.erase(oldAlias)
	aliasToID[checkedAlias] = userID
	
	sharedNetworkInfo["connectedUsers"].erase(oldAlias)
	sharedNetworkInfo["connectedUsers"][checkedAlias] = userID
	
	var procPlace = sharedNetworkInfo["processOrder"].find(oldAlias)
	sharedNetworkInfo["processOrder"][procPlace] = checkedAlias
	
	var maxCreds = sharedNetworkInfo["userMaxCreds"][oldAlias]
	sharedNetworkInfo["userMaxCreds"].erase(oldAlias)
	sharedNetworkInfo["userMaxCreds"][checkedAlias] = maxCreds
	
	# Update users with new info
	rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
	server_message(userID, "sys", "Alias changed to " + checkedAlias)
	rpc_id(userID, "client_update_alias", checkedAlias)

remote func change_password(command):
# Changes users network password. Also handles /resetpass request by
# settings users password back to the default net pass

	# Only run on server
	if get_tree().is_network_server():
		
		var senderID = get_tree().get_rpc_sender_id()
		
		# User requested password reset
		if command[0] == "/resetpass":
			userList[connectedList[get_tree().get_rpc_sender_id()]]["userPass"] = networkInfo["netPass"]
			server_message(senderID, "notice", "Password succesfully reset")
		
		# Checking for correct number of arguments
		if not len(command) >= 2:
			server_message(senderID, "notice", "Invalid syntax: /changepass <new password>")
		
		# Settings new password for user
		else:
			var newPass = command[1]
			userList[connectedList[get_tree().get_rpc_sender_id()]]["userPass"] = newPass
			save_network()
			server_message(senderID, "notice", "Password succesfully changed")

func check_admin(userID):
# Simple function to check if a user has admin access
	var adminArray = Array(networkInfo["adminList"].split(","))
	if adminArray.has(connectedList[userID]):
		return(true)
	else:
		return(false)

func check_alias(alias, senderID):
# Checks if an alias is already in use. Returns original alias if not,
# appends a number before return if it is already in use.

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

func check_target(action, targetAlias, userID):
	if not sharedNetworkInfo["connectedUsers"].has(targetAlias):
		server_message(userID, "sys", action + " failed. " + targetAlias + " not connected.")
		return(false)
	else:
		return(true)

func create_dedicated_network():
# Creates a dedicated server with no starting host
	
	# Creating multiplayer server
	var server : NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	server.create_server(networkInfo["netPort"],MAX_PLAYERS)
	get_tree().set_network_peer(server)
	print("Server created")
	
	# Checking for saved network info
	var netFile = File.new()
	if netFile.file_exists("user://networkInfo.text"):
		load_network()
	
	# Loading and setting network variables
	autosave_network(networkInfo["autosaveInterval"])
	sharedNetworkInfo["networkName"] = networkInfo["networkName"]
	sharedNetworkInfo["messageLog"] = messageLog.duplicate()
	cycleTimer = Timer.new()
	add_child(cycleTimer)
	cycleTimer.wait_time = networkInfo["cycleDuration"]
	cycleTimer.connect("timeout", self, "_process_cycle")

func create_userInfo(userName, password):
# Called when a new user connects to server. Creates userList entry and populates
# with default user values

	userList[userName] = {}
	userList[userName]["userName"] = userName
	userList[userName]["userPass"] = password
	userList[userName]["currentCredits"] = 100
	userList[userName]["creditMult"] = 1.0
	userList[userName]["attack"] = 1.0
	userList[userName]["defense"] = 1.0
	userList[userName]["maxCredits"] = 100
	userList[userName]["processMode"] = "balanced"
	userList[userName]["cycleActions"] = []
	userList[userName]["activeCycles"] = 0
	userList[userName]["firewallLevel"] = 0
	userList[userName]["inventory"] = emptyInventory.duplicate()
	userList[userName]["traceRoute"] = 0
	userList[userName]["hackModifier"] = {}
	userList[userName]["ddosLevel"] = 0

remote func execute_item(item, userID):
# Called by client wanting to execute an item.
# Checks if user has item in their inventory, then executes the item
# item[0] should be a string with the name of the item to be executed
# item[1] should be any optional arguments, often the alias of the item target

	if get_tree().is_network_server():
		# Check if user has item in inventory
		if userList[connectedList[userID]]["inventory"][item[0]] == 0:
			server_message(userID, "sys", "Unable to execute, inventory empty")
			return
		
		# Remove item from inventory and execute
		userList[connectedList[userID]]["inventory"][item[0]] -= 1
		
		if item[0] == "changeAlias":
			change_alias(item[1], userID)
		
		elif item[0] == "forceSkip":
			# Check for valid target, then execute
			if check_target(item[0], item[1], userID):
				force_skip(item[1], userID)
		
		elif item[0] == "fortFirewall":
			fortify_firewall(userID)
		
		elif item[0] == "hackWallet":
			# Check for valid target, then execute
			if check_target(item[0], item[1], userID):
				attempt_hackWallet(item[1], userID)
		
		elif item[0] == "shuffleProc":
			shuffle_process(userID)
			
		elif item[0] == "traceRoute":
			init_traceRoute(userID)

func force_skip(targetUser, userID):
# Handles the forceSkip action. Adding the target to the network skipList
# Target will not be awarded credits, stats, or have their cycle action 
# be executed for one cycle
	server_message(userID, "sys", str(targetUser) + " will be skipped next cycle")
	skipList.append(targetUser)

remote func fortify_firewall(userID):
# Increase the level of the users firewall
	
	# If current firewall level is less than max level, increase by 1
	if userList[connectedList[userID]]["firewallLevel"] < networkInfo["maxFirewallLevel"]:
		userList[connectedList[userID]]["firewallLevel"] += 1
		
		var curLevel = userList[connectedList[userID]]["firewallLevel"]
		server_message(userID, "sys", "Firewall level increased to " + str(curLevel))
		rpc_id(userID, "log_activity", "fortFirewall", "self", "success")
		rpc_id(userID, "update_userInfo", userList[connectedList[userID]].duplicate())
	
	else:
		server_message(userID, "sys", "Firewall already at max level")
		rpc_id(userID, "log_activity", "fortFirewall", "self", "fail", "Firewall already at max level")

func init_traceRoute(userID):
# Adds one traceroute action. If a traceroute is available, anyone who breaches your network
# will have their info revealed, and you will get an attack bonus against them
	if get_tree().is_network_server():
		userList[connectedList[userID]]["traceRoute"] += 1
		server_message(userID, "sys", "Trace route added")
		rpc_id(userID, "log_activity", "Trace route added", "self")
		rpc_id(userID, "update_userInfo", userList[connectedList[userID]].duplicate())

remote func kick_alias(kickAlias):
# Remote admin function to kick a player from the network
	
	var senderID = get_tree().get_rpc_sender_id()
	# Checking for admin rights
	if check_admin(senderID):
		# Checking for valid kickAlias
		if aliasToID.has(kickAlias):
			rpc_id(aliasToID[kickAlias], "remote_quit")
			print(connectedList[aliasToID[kickAlias]] + " kicked by admin")
		else:
			server_message(senderID, "notice", "Invalid alias")
	else:
		server_message(senderID, "notice", "No admin rights")

func load_network():
	print("Loading network data")
	
	# Loading data in networkInfo.text
	var netInfoFile = File.new()
	netInfoFile.open("user://networkInfo.text", File.READ)
	var line
	while not netInfoFile.eof_reached():
		line = netInfoFile.get_line().split(":")
		
		# Checking for end of file
		if netInfoFile.eof_reached():
			pass
		
		# If line[1] contains an int, load as int
		elif line[1].is_valid_integer():
			networkInfo[line[0]] = int(line[1])
		
		# Else load as string
		else:
			networkInfo[line[0]] = line[1]
	netInfoFile.close()
	
	# Loading message log
	var messageFile = File.new()
	messageFile.open("user://messageLog.dat", File.READ)
	messageLog = messageFile.get_var()
	messageFile.close()
	
	# Loading userInfo
	var userFile = File.new()
	userFile.open("user://userData.dat", File.READ)
	userList = userFile.get_var()
	userFile.close()

remote func net_login(userName, password, alias, clientVersion):
# Called when user connected to server. Checks login credentials and handles success
# or failuer to login
	print("User attempting login")

	var senderID = get_tree().get_rpc_sender_id()
	var currentList = connectedList.values()
	var bannedUsers = Array(networkInfo["banList"].split(","))
	
	if get_tree().get_network_unique_id() == 1: # Checking that only run by server
		# Checking for matching versions of the game
		if clientVersion != version:
			rpc_id(get_tree().get_rpc_sender_id(), "login_fail", "Version mismatch, server running version " + version)
		
		# Checking if user has been banned
		elif bannedUsers.has(userName):
			rpc_id(get_tree().get_rpc_sender_id(), "login_fail", "User banned")
		
		# Checking if username is already connected
		elif currentList.has(userName):
			rpc_id(get_tree().get_rpc_sender_id(), "login_fail", "User already logged in")
		
		# Checking if the user has logged in before
		elif userList.has(userName): 
			# Login success for returning user
			if userList[userName]["userPass"] == password:
				rpc_id(get_tree().get_rpc_sender_id(), "update_userInfo", userList[userName].duplicate())
				rpc_id(get_tree().get_rpc_sender_id(), "update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
				rpc_id(get_tree().get_rpc_sender_id(), "login_success")
				add_user(senderID, userName, check_alias(alias, senderID))
			else:
				# Returning user used incorrect password
				rpc_id(get_tree().get_rpc_sender_id(), "login_fail", "Invalid password")
			
		# First time user
		elif password == networkInfo["netPass"]:
			# Login success for first time user
			create_userInfo(userName, password)
			rpc_id(get_tree().get_rpc_sender_id(), "update_userInfo", userList[userName].duplicate())
			rpc_id(get_tree().get_rpc_sender_id(), "update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
			rpc_id(get_tree().get_rpc_sender_id(), "login_success")
			add_user(senderID, userName, check_alias(alias, senderID))
		
		# First time user, wrong network password
		else:
			rpc_id(get_tree().get_rpc_sender_id(), "login_fail", "Invalid password")

func process_action_server(action, userID):
# Handles actions queued in clients cycle action array
# The action parameter is an array, with first element being the action,
# and further elements being action targets or options depending on the action

	if action[0] == "forceSkip":
		# Checking that target exists
		if len(action) > 1:
			force_skip(action[1], userID)
		else:
			server_message(userID, "sys", "Error, no target for forceSkip")
		
	elif action[0] == "fortFirewall":
		fortify_firewall(userID)
	
	elif action[0] == "hackWallet":
		# Checking that target exists
		if len(action) > 1:
			attempt_hackWallet(action[1], userID)
		else:
			server_message(userID, "sys", "Error, no target for hackWallet")
		
	elif action[0] == "shuffleProc":
		shuffle_process(userID)
		
	elif action[0] == "traceRoute":
		init_traceRoute(userID)

func process_user_mode(user):
	if userList[connectedList[user]]["processMode"] == "balanced":
		userList[connectedList[user]]["attack"] += .1
		userList[connectedList[user]]["defense"] += .1
		userList[connectedList[user]]["creditMult"] += .1
	
	elif userList[connectedList[user]]["processMode"] == "attack":
		userList[connectedList[user]]["attack"] += .2
		userList[connectedList[user]]["defense"] += .05
		userList[connectedList[user]]["creditMult"] += .05
		
	elif userList[connectedList[user]]["processMode"] == "defense":
		userList[connectedList[user]]["attack"] += .05
		userList[connectedList[user]]["defense"] += .2
		userList[connectedList[user]]["creditMult"] += .05
		
	elif userList[connectedList[user]]["processMode"] == "creditMult":
		userList[connectedList[user]]["attack"] += .05
		userList[connectedList[user]]["defense"] += .05
		userList[connectedList[user]]["creditMult"] += .2

remote func remote_start():
# Remote admin function to force the game to start
	var senderID = get_tree().get_rpc_sender_id()
	if check_admin(senderID):
		start_game("Game started by admin")
	else:
		server_message(senderID, "notice", "No admin rights")

remote func remote_stop():
# Remote admin function to force the game to stop
	var senderID = get_tree().get_rpc_sender_id()
	if check_admin(senderID):
		stop_game("Game stopped by admin")
	else:
		server_message(senderID, "notice", "No admin rights")

func save_network():
	# First saving networkInfo to a text file
	var netInfoFile = File.new()
	netInfoFile.open("user://networkInfo.text", File.WRITE)
	
	# Looping through networkInfo, writing one line for each item
	for item in networkInfo:
		netInfoFile.store_line(item + ":" + str(networkInfo[item]))
	netInfoFile.close()
	
	# Next saving message log
	var messageFile = File.new()
	messageFile.open("user://messageLog.dat", File.WRITE)
	messageFile.store_var(messageLog)
	messageFile.close()
	
	# Next saving userInfo
	var userFile = File.new()
	userFile.open("user://userData.dat", File.WRITE)
	userFile.store_var(userList)
	userFile.close()

remotesync func send_message(_messageType, curTime, color, name, newText):
# Used as the main method of sending messages to other users

	# Server version simply logs messages
	var newMessage = "[color=" + color + "]" + name + ": "+"[/color]" + newText + "\n"
	messageLog.append([curTime, newMessage])
	sharedNetworkInfo["messageLog"].append([curTime, newMessage])

func server_message(targetID, messageType, message):
# Server function
	rpc_id(targetID, "update_message", messageType, OS.get_datetime(), "silver", "SERVER", message)

remote func set_cycle_action(senderID, command):
# Adds users cycle action to their cyclaActions array

	# Formatting users cycle action into array, with first element being the action,
	# and the second being an optional target
	var formattedAction = []
	formattedAction.append(command[1])
	if len(command) > 2:
		formattedAction.append(command[2])
	
	userList[connectedList[senderID]]["cycleActions"].append(formattedAction)
	server_message(senderID, "sys", "Cycle action added")

func shuffle_process(userID):
# Shuffles the process action list, which determines the player order during cycle processing
	server_message(userID, "sys", "Suffling process order")
	sharedNetworkInfo["processOrder"].shuffle()

func start_game(startMessage):
# Called when sufficient users are connected, starts the game cycle mechanics

	# Set game to on
	gameRunning = true

	# Start up game timers
	cycleTimer.start()
	ddosTimer = Timer.new()
	add_child(ddosTimer)
	ddosTimer.wait_time = 1.0
	ddosTimer.connect("timeout", self, "_ddos_timeout")
	ddosTimer.start()
	
	# creating process order list
	sharedNetworkInfo["processOrder"].clear()
	for userAlias in sharedNetworkInfo["connectedUsers"]:
		sharedNetworkInfo["processOrder"].append(userAlias)
	sharedNetworkInfo["processOrder"].shuffle()
	rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
	
	# Clear any previous cycle action lists
	for user in userList:
		userList[user]["cycleActions"].clear()
	
	if dedicated:
		print("Game started")
	
	rpc("receive_message", "sys", OS.get_datetime(), "silver", "SERVER", startMessage)

func stop_game(stopMessage):
# Called when too many users leave, stops the game cycle mechanics

	# Set game to not running
	gameRunning = false

	# Stop game timers
	cycleTimer.stop()
	ddosTimer.stop()
	
	# Notify users
	rpc("receive_message", "sys", OS.get_datetime(), "silver", "SERVER", stopMessage)
	
	if dedicated:
		print("Game stopped")

remote func update_alias(alias, oldAlias, ID):
# Currently disabled command, allowed user to change alias during game
# Need to make item to handle instead, so user can't change alias for free
	var newAlias = check_alias(alias, ID)
	sharedNetworkInfo["connectedUsers"].erase(oldAlias)
	aliasToID.erase(oldAlias)
	IDtoAlais.erase(ID)
	sharedNetworkInfo["connectedUsers"][newAlias] = ID
	aliasToID[newAlias] = ID
	IDtoAlais[ID] = newAlias
	rpc_id(ID, "client_update_alias", newAlias)
	rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
	rpc("refresh_connectedList")

remote func update_user_mode(newMode):
# Changes to users cycle mode
	var sender = connectedList[get_tree().get_rpc_sender_id()]
	userList[sender]["processMode"] = newMode
	rpc_id(get_tree().get_rpc_sender_id(), "update_userInfo", userList[sender].duplicate())

func user_left(ID):
# Called when user disconnects, removes their information from game lists and dicts
	if get_tree().get_network_unique_id() == 1: # Only run on server
		
		if connectedList.has(ID): # If client failed to login, skip
			if dedicated:
				print(connectedList[ID] + " disconnected")
			var discAlias = IDtoAlais[ID]
			rpc("receive_message", "notice", OS.get_datetime(), "silver", "SERVER", IDtoAlais[ID] + " disconnected")
			connectedList.erase(ID) # remove  from connectedList
			aliasToID.erase(discAlias)
			IDtoAlais.erase(ID)
			sharedNetworkInfo["connectedUsers"].erase(discAlias)
			sharedNetworkInfo["userMaxCreds"].erase(discAlias)
			sharedNetworkInfo["processOrder"].erase(discAlias)
			rpc("update_sharedNetworkInfo", sharedNetworkInfo.duplicate())
			rpc("refresh_connectedList")
			rpc("refresh_statusBox")
			if len(connectedList) == networkInfo["minUsers"] - 1:
				stop_game("Insufficient users, game stopped")
