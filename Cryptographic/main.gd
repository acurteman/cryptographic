extends Control

var activityLog = [] # Stores list of recent activities and results
var adminCommands = {
	"/announce": "Broadcast message to all users from the server",
	"/ban": "<username> Bans user from the server",
	"/kick": "<username> Kicks user from the server",
	"/resetgame": "Resets all game data",
	"/setserverpass": "Change the server password",
	"/shutdown": "Shuts down the game server",
	"/startgame": "Forces the game to start",
	"/stopgame": "Forces the game to stop",
	"/users": "View the usernames of connected users"}
var commandHistory = []
var commandHistoryIndex = -1
var commandList = {
	"/bank": "<amount> <duration> Bank credits for a specified number of cycles, earning interest.",
	"/buy": "<item name> <quanitity> Purchase an item",
	"/changepass": "<newpassword> Change your current password",
	"/color": "<newcolor> Change your current color",
	"/cycle": "<action> <target> Set your action for the current cycle, with optional target user",
	# "/cyclelist": "Show a list of available cycle actions",
	"/exec": "<item> <target> Execute a purchased item",
	"/help": "Show list of commands",
	"/inv": "Show current inventory",
	"/listmodes": "Show a list of process modes",
	"/resetpass": "Reset your password to the default network password",
	"/rtd": "<amount> Roll the dice and gamble your credits",
	"/setmode": "<mode> Set your current process mode",
	"/shoplist": "Show a list of items to buy",
	"/transfer": "<target> <amount> Transfer credits to another user",
	"/w": "<username> <message> Send whisper to another user"}
var cycleActionList = {
	"dox": "Reveal users details to entire network",
	"forceSkip": "Force the network to skip a user on the next cycle",
	"fortFirewall": "Fortify your firewall, which will prevent one succesfull attack",
	"hackWallet": "Attempt to steal credits from another users wallet",
	"shuffleProc": "Shuffle the process order list",
	"stealID": "Attempt to swap aliases with another user",
	"traceRoute": "Log information of anyone who breaches your network"}
var cycleScript = false
var editPopup
var extCycleScript = false
var filePopup
var helpPopup
var IP_ADDRESS = "127.0.0.1"
var localLog = []
var outputTimer
var PORT = 42420
var prefs = {
	"lastIP": "127.0.0.1",
	"userName": "defaultUser",
	"userAlias": "defaultAlias",
	"userColor": "red",
	"sysColor": "gray",
	"sysName": "system",
	"dispTimeStamps": true}
var processModes = {
	"balanced": "Attack, defence, and creditMult stat each recieve a .1 increase each cycle",
	"attack": "Attack stat recieves a .2 increase each cycle, others a .5",
	"defense": "Defense stat recieves a .2 increase each cycle, others a .5",
	"creditMult": "Credit multiplier stat recieves a .2 increase each cycle, others a .5"}
var scriptCommands = {
	"buy": "<item name> <quanitity> Purchase an item",
	"cycle": "<action> Set cycle action",
	"exec": "<item> <target> Execute a purchased item",
	"setMode": "<mode> Set your current process mode"}
var scriptIndex = 0
var scriptSettings = []
var scriptTimer
var sharedNetworkInfo = {
	"networkName":"temp",
	"messageLog": [],
	"connectedUsers": {},
	"processOrder": [],
	"shopTax" : 2,
	"userMaxCreds": {}}
var shopItems = {
	"changeAlias": 250,
	"dox": 125,
	"forceSkip": 150,
	"fortFirewall": 20,
	"hackWallet": 100,
	"shuffleProc": 15,
	"stealID": 300,
	"traceRoute": 25}
var userInfo = {}
var userPass = ""
var userScript = []
var version = "0.0.2"

func _ready():
	#$helpBox.popup()
	
	load_prefs()
	
	# Connecting network signals to appropriate functions
	get_tree().connect("network_peer_disconnected",self,"user_left")
	get_tree().connect("connection_failed", self, "connected_fail")
	get_tree().connect("connected_to_server",self,"connected")
	get_tree().connect("server_disconnected",self,"server_disconnected")
	
	filePopup = $fileButton.get_popup()
	filePopup.add_item("Join Network")
	#filePopup.add_item("Host New Network")
	#filePopup.add_item("Load Network")
	filePopup.add_item("Disconnect")
	filePopup.set_item_disabled(1, true)
	filePopup.add_item("Exit")
	filePopup.connect("id_pressed", self, "_on_file_item_pressed")
	
	editPopup = $editButton.get_popup()
	editPopup.add_item("User Settings")
	editPopup.connect("id_pressed", self, "_on_edit_item_pressed")
	
	helpPopup = $helpButton.get_popup()
	helpPopup.add_item("Commands")
	helpPopup.add_item("About")
	helpPopup.connect("id_pressed", self, "_on_help_item_pressed")
	
	$joinPopup/serverInput.text = prefs["lastIP"]
	
	$tabs/Script/loopBtn.add_item("None")
	$tabs/Script/loopBtn.add_item("Every Cycle")
	#$tabs/Script/loopBtn.add_item("Continuous")
	
#	$userSettingsPopup/outputButton.add_item("Cycle", 1)
#	$userSettingsPopup/outputButton.add_item("Interval", 2)

func _input(event):
	# Checks if there is any command history, and if up or down has been pressed to
	# cycle between previous commands
	if len(commandHistory) > 0:
		if event.is_action_pressed("command_prev"):
			$inputText.text = commandHistory[commandHistoryIndex]
			if commandHistoryIndex > 0:
				commandHistoryIndex -= 1
		elif event.is_action_pressed("command_next"):
			if commandHistoryIndex < len(commandHistory) - 1:
				commandHistoryIndex += 1
				$inputText.text = commandHistory[commandHistoryIndex]
	
	# If tab was pressed, attempt to autocomplete what is written in the command line
	if event.is_action_pressed("auto_complete"):
		auto_complete()

func _interval_execute():
# Local function
# Called when external script interval timer ends. Restarts the process
# of executing the exteral script
	run_script()

func _on_checkBtn_pressed():
	$tabs/Script/statusBox.clear()
	check_script()

func _on_clearBtn_pressed():
	$tabs/Script/scriptText.text = ""
	$tabs/Script/statusBox.clear()

func _on_connectedBox_item_activated(index):
	$inputText.text += $connectedBox.get_item_text(index)

func _on_edit_item_pressed(ID):
	if editPopup.get_item_text(ID) == "User Settings":
		$userSettingsPopup.popup()

func _on_extRunBtn_pressed():
# Local function
# Handles the loading and executing of external scripts
	
	# Toggling local script buttons
	$tabs/Script/checkBtn.disabled = true
	$tabs/Script/clearBtn.disabled = true
	$tabs/Script/loopBtn.disabled = true
	$tabs/Script/runBtn.disabled = true
	$tabs/Script/extStopBtn.disabled = false
	
	# If able to load external script
	if load_ext_script():
		$tabs/Script/scriptText.readonly = true
		print_script()
		
		# Check if connected to network
		if get_tree().has_network_peer():
		
			# If loaded script is valid, execute
			if check_script():
				# If set to single run
				if scriptSettings[1] == "single":
					run_script()
					$tabs/Script/checkBtn.disabled = false
					$tabs/Script/clearBtn.disabled = false
					$tabs/Script/loopBtn.disabled = false
					$tabs/Script/runBtn.disabled = false
					$tabs/Script/extStopBtn.disabled = true
				
				# If set to run each cycle
				elif scriptSettings[1] == "cycle":
					run_script()
					extCycleScript = true
				
				# If set to run after given interval
				elif scriptSettings[1] == "interval":
					scriptTimer = Timer.new()
					add_child(scriptTimer)
					scriptTimer.connect("timeout", "_interval_execute")
					scriptTimer.wait_time = float(scriptSettings[2])
					scriptTimer.one_shot = false
					run_script()
					scriptTimer.start()
					
		else:
			# Not connected to network
			$tabs/Script/statusBox.clear()
			$tabs/Script/statusBox.append_bbcode("[color=red]" +
			"Not connected to network[/color]\n")
	
	# Error opening script file
	else:
		print("Error opening script file")
		$tabs/Script/statusBox.clear()
		$tabs/Script/statusBox.append_bbcode("[color=red]" +
		"Error opening script file[/color]\n")

func _on_extStopBtn_pressed():
	extCycleScript = false
	scriptTimer.stop()
	
	# Toggling local script buttons
	$tabs/Script/checkBtn.disabled = false
	$tabs/Script/clearBtn.disabled = false
	$tabs/Script/loopBtn.disabled = false
	$tabs/Script/runBtn.disabled = false

func _on_file_item_pressed(ID):
	if ID == 0: # Join Network
		$joinPopup.popup()
	elif ID == 1: # Disconnect
		disc()
	elif ID == 2: # Quit
		exit()

func _on_help_item_pressed(ID):
	# Commands button
	if ID == 0: 
		# Print available commands, same as typing /help
		update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Commands: ")
		for item in commandList:
			$tabs/Messages/messageBox.append_bbcode(item + ": " + commandList[item])
			$tabs/Messages/messageBox.newline()
		
	# About button
	elif ID == 1: 
		$aboutBox.popup()

func _on_inputText_text_entered(newText):
	if newText.length() > 0: # check for blank input
		
		# Add text to commandHistory
		commandHistory.append(newText)
		commandHistoryIndex = len(commandHistory) - 1
		
		if newText[0] == "/": # check for command input
			process_command(newText)
			$inputText.clear()
		else:
			# If connected to a server
			if get_tree().has_network_peer():
				#Create the message and tell everyone else to add it to their history
				rpc_id(1, "broadcast_message", "network", OS.get_datetime(), prefs["userColor"], prefs["userAlias"], newText)
				$inputText.clear()
			else:
				update_message("local", OS.get_datetime(), prefs["userColor"], prefs["userAlias"], newText)
				$inputText.clear()

func _on_joinButton_pressed():
	$joinPopup.visible = false
	filePopup.set_item_disabled(1, false)
	editPopup.set_item_disabled(0, true)
	userPass = $joinPopup/passInput.text
	
	IP_ADDRESS = $joinPopup/serverInput.text
	prefs["lastIP"] = IP_ADDRESS
	
	#Create a  client that will connect to the server
	var client : NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	client.create_client(IP_ADDRESS, PORT)
	get_tree().set_network_peer(client)
	
	#Update status and username for chatroom
	update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Trying to join to " + IP_ADDRESS)

func _on_logLocBrowseBtn_pressed():
	$userSettingsPopup/logLocPopup.popup()

func _on_logLocPopup_dir_selected(dir):
	$userSettingsPopup/logLocInput.text = dir

func _on_noBtn_pressed():
	$overwriteSave.visible = false

func _on_runBtn_pressed():
	$tabs/Script/scriptText.readonly = true
	$tabs/Script/loopBtn.disabled = true
	$tabs/Script/stopBtn.disabled = false
	$tabs/Script/runBtn.disabled = true
	$tabs/Script/extRunBtn.disabled = true
	$tabs/Script/scriptBrowse.disabled = true
	
	# Check if connected to network
	if get_tree().has_network_peer():
	
		# Check for valid script before running
		if check_script():
			userScript.clear()

			for i in range(0, $tabs/Script/scriptText.get_line_count()):
				var line = $tabs/Script/scriptText.get_line(i)
				userScript.append(line.split(" "))
		
			# If loop button set to None
			if $tabs/Script/loopBtn.get_selected_id() == 0:
				$tabs/Script/statusBox.append_bbcode("[color=white]" +
				"Running script[/color]\n")
				run_script()
				$tabs/Script/scriptText.readonly = false
				$tabs/Script/loopBtn.disabled = false
				$tabs/Script/stopBtn.disabled = true
				$tabs/Script/runBtn.disabled = false
			
			# If loop button set to cycle
			elif $tabs/Script/loopBtn.get_selected_id() == 1:
				$tabs/Script/statusBox.append_bbcode("[color=white]" +
				"Running script every cycle[/color]\n")
				run_script()
				cycleScript = true
	else:
		# Not connected to network
		$tabs/Script/statusBox.clear()
		$tabs/Script/statusBox.append_bbcode("[color=red]" +
		"Not connected to network[/color]\n")

func _on_saveBrowseBtn_pressed():
	$hostPopup/saveDirPopup.popup()

func _on_saveDirPopup_confirmed():
	$hostPopup/saveDir.text = $hostPopup/saveDirPopup.current_path

func _on_saveDirPopup_dir_selected(dir):
	$hostPopup/saveDir.text = dir

func _on_scriptBrowse_pressed():
	$tabs/Script/scriptDialog.popup()

func _on_scriptDialog_file_selected(path):
	$tabs/Script/scriptLocation.text = path

func _on_stopBtn_pressed():
	$tabs/Script/scriptText.readonly = false
	$tabs/Script/loopBtn.disabled = false
	$tabs/Script/stopBtn.disabled = true
	$tabs/Script/runBtn.disabled = false
	$tabs/Script/extRunBtn.disabled = false
	$tabs/Script/scriptBrowse.disabled = false
	cycleScript = false
	$tabs/Script/statusBox.append_bbcode("[color=white]" +
		"Script stopped[/color]\n")

func _on_userApplyButton_pressed():
	$userSettingsPopup.visible = false
	prefs["userName"] = $userSettingsPopup/usernameInput.text
	prefs["userColor"] = $userSettingsPopup/userColor.text
	prefs["dispTimeStamps"] = $userSettingsPopup/timeBtn.pressed
	prefs["userAlias"] = $userSettingsPopup/aliasInput.text
	save_prefs()

func add_cycle_action(command):
# Client function
# Handles the /cycle command, checks for valid syntax, then sends request to server

	# Checking for valid cycle action
	if not cycleActionList.has(command[1]):
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Invalid cycle action, type /cyclelist for a list of actions')
		return
	
	# If action has a target user, checking for valid user alias
	elif len(command) > 2:
		if not sharedNetworkInfo["connectedUsers"].has(command[2]):
			update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Unknown user: ' + command[2])
			return
	
	# Send action to server
	rpc_id(1, "add_cycle_action", get_tree().get_network_unique_id(), command)

func auto_complete():
# Called when a user presses tab, attempts to auto complete what
# they have written in the command line
	
	# First check for blank input
	if $inputText.text == "":
		pass
	else:
		# Split up input and get the length of array
		var inputArray = $inputText.text.split(" ")
		var inputLength = inputArray.size()
		
		# If attempting to autocomplete first element of command
		if inputLength == 1:
			var commandArray = commandList.keys()
			var matches = []
			
			# Loop through commands, checking if any element with what is in the inputArray[0]
			for item in commandArray:
				if item.begins_with(inputArray[0]):
					matches.append(item)
			
			# If only a single command matches, autocomplete with that command
			if matches.size() == 1:
				$inputText.text = matches[0] + " "
				$inputText.set_cursor_position($inputText.text.length())
			
		# If attempting to autocomplete second element of command
		elif inputLength == 2:
			# Check the first element and find matching command
			if inputArray[0] == "/buy":
				pass
			
			elif inputArray[0] == "/cycle":
				pass
			
			elif inputArray[0] == "/exec":
				pass
			
			elif inputArray[0] == "/help":
				pass
			
			elif inputArray[0] == "/setmode":
				pass
			
			elif inputArray[0] == "/transfer":
				pass
			
			elif inputArray[0] == "/w":
				pass

func change_color(command):
# Client function
# Changes users bbcode color preference

	if len(command) != 2:
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid syntax: /color <newcolor>")
	else:
		prefs["userColor"] = command[1]
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "User color changed to " + command[1])

func check_buy(command):
# Client function
# Checks syntax for buy command, then sends request to server
# Expected syntax: /buy <item> <quantity>
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
			quantity = int(command[2])
			if typeof(quantity) != TYPE_INT:
				update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Invalid item quantity')
				return
				
	# Send buy request
	rpc_id(1, "buy_item", command[1], quantity, get_tree().get_network_unique_id())

func check_execute(command):
# Client function
# Checks for valid execute command, then sends request to server

	# Check for valid item to execute
	if not shopItems.has(command[1]):
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid item")
		return
	
	var newItem = []
	newItem.append(command[1])
	
	# Check if item has a target
	if len(command) > 2:
		newItem.append(command[2])
	
	# Send execute request
	rpc_id(1, "execute_item", newItem, get_tree().get_network_unique_id())

func check_script():
# Client function
# Checks the script written in the scriptBox, making sure only valid
# commands are written. Udpates the script status accordingly
	$tabs/Script/scriptText.readonly = true
	
	var totalLines = $tabs/Script/scriptText.get_line_count()
	
	for i in range(0, totalLines):
		var line = $tabs/Script/scriptText.get_line(i)
		var splitLine = line.split(" ")
		
		# Skip if line is blank
		if not splitLine[0] == "":
			if not scriptCommands.has(splitLine[0]):
				$tabs/Script/statusBox.clear()
				$tabs/Script/statusBox.append_bbcode("[color=red]" +
				"Error on line: " + str(i +1) + "[/color]\n")
				$tabs/Script/statusBox.append_bbcode("[color=red]" +
				"Unknown command: " + splitLine[0] + "[/color]\n")
				$tabs/Script/scriptText.readonly = false
				return false
	
	$tabs/Script/statusBox.clear()
	$tabs/Script/statusBox.append_bbcode("[color=green]" +
	"Script check passed[/color]\n")
	
	$tabs/Script/scriptText.readonly = false
	return true

remote func client_update_alias(newAlias):
# Client function
# Called by server when user gets a new alias
	prefs["userAlias"] = newAlias
	refresh_statusBox()

func connected():
# Client function
# Called when connection established to server, makes login request to server
	update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Connection succesful, attempting login...")
	rpc_id(1, "net_login", prefs["userName"], userPass, prefs["userAlias"], version)

func connected_fail():
# Client function
# Called when connection to server failed

	print("Failed to connect")
	update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Couldn't connect try again, or host?")

func disc():
# Disconnects without closing the program
	get_tree().network_peer = null
	save_localLog()
	$connectedBox.clear()
	$tabs/Messages/messageBox.clear()
	$statusBox.clear()
	filePopup.set_item_disabled(1, true)
	editPopup.set_item_disabled(0, false)
	if prefs["outputFreq"] == "interval":
		outputTimer.stop()

func exit():
# Handles closing the program when the exit option is selected
		get_tree().network_peer = null
		save_localLog()
		get_tree().quit()

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

func load_ext_script():
# Local function
# Attempts to load a script file. If succesful, sets scriptSettings variable,
# and loads script into userScript var, then returns true. If script file opens, but has not been
# changed, simply returns true. If file fails to open, returns false.

	var scriptFile = File.new()
	var err = scriptFile.open($tabs/Script/scriptLocation.text, File.READ)
	
	if err == 0:
		# Check for new script flag
		scriptSettings = scriptFile.get_line().split(",")
		if scriptSettings[0] == "true":
			userScript.clear()
			# Append each line to userScript, delimitted by ,
			while not scriptFile.eof_reached():
				userScript.append(scriptFile.get_line().split(","))
			scriptFile.close()
			scriptSettings[0] = "false"
			
			# Rewrite file with new script flag set to false
			scriptFile.open($tabs/Script/scriptLocation.text, File.WRITE)
			scriptFile.store_csv_line(scriptSettings)
			for line in userScript:
				scriptFile.store_csv_line(line)
		
		scriptFile.close()
		return(true)
	
	else:
		scriptFile.close()
		return(false)

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

func load_prefs():
# Local function
# Loads the user preferences from the save file
	var prefsPath = "user://preferences.dat"
	var file = File.new()
	if not file.file_exists(prefsPath):
		save_prefs()
	file.open(prefsPath, File.READ)
	prefs = file.get_var()
	file.close()
	
	$userSettingsPopup/usernameInput.text = prefs["userName"]
	$userSettingsPopup/userColor.text = prefs["userColor"]
	$userSettingsPopup/aliasInput.text = prefs["userAlias"]

remote func log_activity(activity, target, status="", message = ""):
# Local function
# Manages the activity log array, adding new elements, and deleting old ones
	var logTime = get_formatted_time(OS.get_datetime())
	var newLog = [logTime, activity, target, status, message]
	
	# Check if array is at max size, if so, pop front element first
	if activityLog.size() >= 10:
		activityLog.pop_front()
	
	activityLog.append(newLog)

remote func login_fail(message):
	update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], message)
	get_tree().network_peer = null
	filePopup.set_item_disabled(3, true)
	editPopup.set_item_disabled(0, false)

remote func login_success():
# Network function
# Called by the server when login info is accepted
	
	# Loading and syncing server messages
	load_localLog()
	$tabs/Messages/messageBox.clear()
	sync_messages()
	update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Login succesful")
	
	# If output set to interval, starting output timer
	outputTimer = Timer.new()
	add_child(outputTimer)
	outputTimer.connect("timeout", self, "save_output")
	outputTimer.wait_time = prefs["outputInterval"]
	outputTimer.start()

remote func new_cycle():
# Called by the server every time a new cycle starts
	
	# If user has output preferences set to cycle, save output
	if prefs["outputFreq"] == "cycle":
		save_output()

	# If user has a script set to run on new cycle, run script
	if cycleScript:
		run_script()
	elif extCycleScript:
		run_script()

func print_script():
# Local function
# Takes the contents of userScript, and loads them into the scriptText box
	$tabs/Script/scriptText.text = ""
	for line in userScript:
		for i in range(0, len(line)):
			$tabs/Script/scriptText.text += line[i] + " "
		$tabs/Script/scriptText.text += "\n"

func process_action_script(action, userID):
# Client function
# Handles actions executed by scripts
	if action[0] == "buy":
		check_buy(action)
	
	elif action[0] == "cycle":
		add_cycle_action(action)
	
	elif action[0] == "exec":
		check_execute(action)
	
	elif action[0] == "setMode":
		set_mode(action)

func process_command(newCommand):
# Main function for processing commands entered by users using the / format
	var command = newCommand.split(" ")
	
	# Check if entered command was an admin command
	if adminCommands.has(command[0]):
		# Make an announcment from the server
		if command[0] == "/announce":
			rpc_id(1, "announce", command)
		
		# Kick then block a user from returning
		elif command[0] == "/ban":
			rpc_id(1, "ban_user", command[1])
		
		# Kick a user from the network
		elif command[0] == "/kick":
			rpc_id(1, "kick_user", command[1])
		
		elif command[0] == "/resetgame":
			rpc_id(1, "reset_game")
		
		# Shut down the game server
		elif command[0] == "/shutdown":
			rpc_id(1, "remote_shutdown")
		
		# Change the server password
		elif command[0] == "/setserverpass":
			rpc_id(1, "set_server_pass", command)
		
		# Force start the game
		elif command[0] == "/startgame":
			rpc_id(1, "remote_start")
	
		# Force stop the game
		elif command[0] == "/stopgame":
			rpc_id(1, "remote_stop")
		
		# View list of username
		elif command[0] == "/users":
			rpc_id(1, "view_usernames")
	
	# Check for valid user command
	elif not commandList.has(command[0]):
		update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Invalid command, type /help for a list of commands')
	
	# Bank credits
	elif command[0] == "/bank":
		rpc_id(1, "bank_credits", command)
	
	# Buy an item
	elif command[0] == "/buy":
		check_buy(command)
	
	# Change your user color
	elif command[0] == "/color":
		change_color(command)
	
	# Change your password
	elif command[0] == "/changepass":
		rpc_id(1, "change_password", command)
	
	# Add a command to be executed at the end of a cycle
	elif command[0] == "/cycle":
		add_cycle_action(command)
	
	# List commands that can be executed as cycle actions
	elif command[0] == "/cyclelist":
		update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Cycle Actions: ")
		for item in cycleActionList:
			$tabs/Messages/messageBox.append_bbcode(item + ": " + cycleActionList[item])
			$tabs/Messages/messageBox.newline()
	
	# Execute an item you have purchased
	elif command[0] == "/exec":
		check_execute(command)
	
	# List all available commands
	elif command[0] == "/help":
		update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Commands: ")
		for item in commandList:
			$tabs/Messages/messageBox.append_bbcode(item + ": " + commandList[item])
			$tabs/Messages/messageBox.newline()
	
	# List all the items you currently own
	elif command[0] == "/inv":
		update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Inventory: ")
		for item in userInfo["inventory"]:
			$tabs/Messages/messageBox.append_bbcode(item + ": " + str(userInfo["inventory"][item]))
			$tabs/Messages/messageBox.newline()
	
	# List the different types of cycle modes you can choose from
	elif command[0] == "/listmodes":
		update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Cycle Modes: ")
		for mode in processModes:
			$tabs/Messages/messageBox.append_bbcode(mode + ": " + processModes[mode])
			$tabs/Messages/messageBox.newline()
	
	# Change your password back to the default network password
	elif command[0] == "/resetpass":
		# SAME AS /STARTGAME, NEED TO CREATE SOME SORT OF ADMIN STATUS FOR USERS FOR THIS TO
		# WORK AS INTENDED
		update_message("sys", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Command currently borked')
		#reset_password(command)
	
	# RTD
	elif command[0] == "/rtd":
		rpc_id(1, "rtd", command)
	
	# Change your cycle mode
	elif command[0] == "/setmode":
		set_mode(command)
	
	# List items that can be purchases along with prices
	elif command[0] == "/shoplist":
		# Calculating tax added to purchase
		var userTax = int(userInfo["maxCredits"] * (float(sharedNetworkInfo["shopTax"]) / 100))
		
		# Printing shop items and prices with tax
		update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Items: ")
		for item in shopItems:
			$tabs/Messages/messageBox.append_bbcode(item + ": " + str(shopItems[item] + userTax))
			$tabs/Messages/messageBox.newline()
	
	# Transfer credits to another user
	elif command[0] == "/transfer":
		rpc_id(1, "transfer_credits", command)
	
	# Send a whisper to another user
	elif command[0] == "/w":
		# /w [userAlias] [message]
		send_whisper(command)

remote func receive_message(messageType, curTime, color, name, newText):
# Main function for receiving messages from other users
	update_message(messageType, curTime, color, name, newText)

remote func refresh_connectedList():
	$connectedBox.clear()
	var current_aliases = sharedNetworkInfo["connectedUsers"].keys()
	for alias in current_aliases:
		$connectedBox.add_item(alias)
		$connectedBox.add_item(str(sharedNetworkInfo["userMaxCreds"][alias]))

remote func refresh_statusBox():
	# Formatting process order
	var totalUsers = len(sharedNetworkInfo["processOrder"])
	var userPlace = sharedNetworkInfo["processOrder"].find(prefs["userAlias"])
	var procPlace = str(userPlace + 1) + "/" + str(totalUsers)
	
	$statusBox.clear()
	$statusBox.add_item("User name: " + userInfo["userName"])
	$statusBox.add_item("Alias: " + prefs["userAlias"])
	$statusBox.add_item("Process Mode: " + userInfo["processMode"])
	$statusBox.add_item("Firewall Level: " + str(userInfo["firewallLevel"]))
	$statusBox.add_item("DDOS Level: " + str(userInfo["ddosLevel"]))
	$statusBox.add_item("Trace routes: " + str(userInfo["traceRoute"]))
	$statusBox.add_item("Process Order: " + procPlace)
	$statusBox.add_item("Credits: " + str(userInfo["currentCredits"]))
	$statusBox.add_item("Credit mult: " + str(userInfo["creditMult"]))
	$statusBox.add_item("Attack: " + str(userInfo["attack"]))
	$statusBox.add_item("Defense: " + str(userInfo["defense"]))
	$statusBox.add_item("Max credits: " + str(userInfo["maxCredits"]))
	$statusBox.add_item("Active Cycles: " + str(userInfo["activeCycles"]))

remote func remote_quit():
# Remote function for server to disconnect users
	
	# Checking that only server called
	if get_tree().get_rpc_sender_id() == 1:
		disc()

func reset_password(command):
	rpc_id(1, "change_password", command)

func run_script():
	for line in userScript:
		process_action_script(line, get_tree().get_network_unique_id())

func save_localLog():
	var logPath = prefs["localLogLocation"] + sharedNetworkInfo["networkName"] + "Log.dat"
	var file = File.new()
	file.open(logPath, File.WRITE)
	file.store_var(localLog)
	file.close()

func save_output():
# Local function
# Writes the output file accesible to external scripts. Contains all information about the 
# current state of the game available to the player.
	
	var outputPath = "user://output.dat"
	var file = File.new()
	file.open(outputPath, File.WRITE)
	
	var userStats : PoolStringArray
	userStats.append(userInfo["activeCycles"])
	userStats.append(userInfo["attack"])
	userStats.append(userInfo["creditMult"])
	userStats.append(userInfo["currentCredits"])
	userStats.append(userInfo["defense"])
	userStats.append(userInfo["firewallLevel"])
	userStats.append(userInfo["processMode"])
	userStats.append(userInfo["maxCredits"])
	var statsHeader = ["activeCycles", "attack", "creditMult", "currentCredits", "defense",
		"firewallLevel", "processMode", "maxCredits"]
	
	# First storing the current userStats, first line is header, second is stat values
	file.store_csv_line(statsHeader)
	file.store_csv_line(userStats)
	
	# Next, storing current user cycle actions, if empty write "none"
	if userInfo["cycleActions"].empty():
		file.store_csv_line(["none"])
	else:
		file.store_csv_line(userInfo["cycleActions"])
	
	# Next, storing inventory in two lines, first is item names, second is item quantity
	file.store_csv_line(userInfo["inventory"].keys())
	file.store_csv_line(userInfo["inventory"].values())
	
	# Next storing the current connected player
	file.store_csv_line(PoolStringArray(sharedNetworkInfo["connectedUsers"].values()))
	
	file.close()

func save_prefs():
# Local function
# Saves the current user preferences
	var prefsPath = "user://preferences.dat"
	var file = File.new()
	file.open(prefsPath, File.WRITE)
	file.store_var(prefs)
	file.close()

func send_whisper(command):
	var wMessage = ""
	for i in range(2, len(command)):
		wMessage += " " + command[i]
	if not sharedNetworkInfo["connectedUsers"].has(command[1]):
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Unknown user: " + command[1])
	else:
		rpc_id(sharedNetworkInfo["connectedUsers"][command[1]], "receive_message", "local",
		OS.get_datetime(), prefs["userColor"], prefs["userAlias"], "<w>" + command[1] + ": " + wMessage)
		update_message("local", OS.get_datetime(), prefs["userColor"], prefs["userAlias"], "<w>" + command[1] + ": " + wMessage)

func server_disconnected():
	#Server just closed
	print("server_disconnected")
	save_localLog()
	$connectedBox.clear()
	$statusBox.clear()
	$tabs/Messages/messageBox.clear()
	filePopup.set_item_disabled(3, true)
	editPopup.set_item_disabled(0, false)
	update_message("notice", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Server Closed")

func server_log_activity(userID, activity, target, status="", message = ""):
# Server function
# Used to prevent self rpc_id calls for server when calling log_activity function
	if userID == 1:
		log_activity(activity, target, status, message)
	else:
		rpc_id(userID, activity, target, status, message)

func server_update_userInfo(userID, newUserInfo):
# Server function
# Used to prevent self rpc_id calls for server when calling update_userInfo
	if userID == 1:
		update_userInfo(newUserInfo)
	else:
		rpc_id(userID, "update_userInfo", newUserInfo)

func set_mode(command):
# Checks command syntax, then sends request to server to change mode
	if len(command) != 2:
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid syntax: /changemode <newmode>")
	elif not processModes.has(command[1]):
		update_message("local", OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Unknown process mode, type /listmodes to see all available modes")
	else:
		rpc_id(1, "update_user_mode", command[1])

func simple_update(datedMessage):
	if prefs["dispTimeStamps"] == false:
		$tabs/Messages/messageBox.append_bbcode(datedMessage[1])
	else:
		$tabs/Messages/messageBox.append_bbcode(get_formatted_time(datedMessage[0]) + datedMessage[1])

func sync_messages(): # Printing shared and local message in order of time stamp
	var totalMessages = len(sharedNetworkInfo["messageLog"]) + len(localLog)
	var localIndex = 0
	var sharedIndex = 0
	
	for _i in range(totalMessages - 0):
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

remote func update_message(messageType, dateTime, color, name, newText):
	var newMessage = "[color=" + color + "]" + name + ": "+"[/color]" + newText + "\n"
	
	# Network messages are displayed in the message box, and saved to the network message log
	if messageType == "network":
		if prefs["dispTimeStamps"] == false:
			$tabs/Messages/messageBox.append_bbcode(newMessage)
		else:
			$tabs/Messages/messageBox.append_bbcode(get_formatted_time(dateTime) + newMessage)
	
	# Local messages are displayed in the message box, and saved to the local message log
	elif messageType == "local":
		localLog.append([dateTime, newMessage])
		save_localLog()
		if prefs["dispTimeStamps"] == false:
			$tabs/Messages/messageBox.append_bbcode(newMessage)
		else:
			$tabs/Messages/messageBox.append_bbcode(get_formatted_time(dateTime) + newMessage)

	# Notification messages are displayed in the message box and not saved
	elif messageType == "notice":
		if prefs["dispTimeStamps"] == false:
			$tabs/Messages/messageBox.append_bbcode(newMessage)
		else:
			$tabs/Messages/messageBox.append_bbcode(get_formatted_time(dateTime) + newMessage)

	# System messages are displayed in the console box, and are not saved
	elif messageType == "sys":
		if prefs["dispTimeStamps"] == false:
			$tabs/Console/consoleBox.append_bbcode(newMessage)
		else:
			$tabs/Console/consoleBox.append_bbcode(get_formatted_time(dateTime) + newMessage)

	else:
		pass

remotesync func update_sharedNetworkInfo(newInfo):
	sharedNetworkInfo = newInfo.duplicate()
	refresh_statusBox()
	refresh_connectedList()

remote func update_userInfo(newUserInfo):
	userInfo = newUserInfo.duplicate()
	refresh_statusBox()
