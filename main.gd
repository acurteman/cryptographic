extends Control

var connectedList : Dictionary
var MAX_PLAYERS = 32
var filePopup
var editPopup
var saveTimer
var prefs = {"userName": "defaultUser", "userColor": "red", "sysColor": "gray", "sysName": "system",
	"dispTimeStamps": true, "localLogLocation": "user://"}
var userInfo = {"userName": "", "userPass": ""}
var localLog = []
var userList : Dictionary
var networkInfo = {"networkName": "defaultNet", "messageLog": [], "autosaveInterval": 10, 
	"netSavePath": "", "netPort": 4242, "netPass": "password", "userList": userList}
var sharedNetworkInfo = {"networkName":"", "messageLog": []}
var userPass = ""
var commandList = {"/credits": "Display users current credits", "/help": "Show list of commands"}
onready var port = int($joinPopup/portInput.text)
onready var ipAddress = $joinPopup/ipInput.text

func _ready():
	load_prefs()
	
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
	$userSettingsPopup/logLocInput.text = prefs["localLogLocation"]

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
		$userSettingsPopup.visible = true

func _on_hostButton_pressed():
	$hostPopup.visible = false
	networkInfo["networkName"] = $hostPopup/networkName.text
	networkInfo["netSavePath"] = $hostPopup/saveDir.text + $hostPopup/networkName.text + ".dat"
	networkInfo["netPort"] = int($hostPopup/hostPort.text)
	networkInfo["netPass"] = $hostPopup/passInput.text
	checkNetwork(networkInfo["networkName"])

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
	shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Trying to join to " + ipAddress)

func _on_inputText_text_entered(newText):
	if newText.length() > 0: # check for blank input
		if newText[0] == "/": # check for command input
			process_command(newText)
			$inputText.clear()
		else:
			#Create the message and tell everyone else to add it to their history
			rpc("send_chat", OS.get_datetime(), prefs["userColor"], prefs["userName"], newText)
			$inputText.clear()

func _on_userApplyButton_pressed():
	$userSettingsPopup.visible = false
	prefs["userName"] = $userSettingsPopup/usernameInput.text
	prefs["userColor"] = $userSettingsPopup/userColor.text
	prefs["dispTimeStamps"] = $userSettingsPopup/timeBtn.pressed
	prefs["localLogLocation"] = $userSettingsPopup/logLocInput.text
	save_prefs()

func _on_yesBtn_pressed():
	$overwriteSave.visible = false
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

func process_command(newCommand):
	var command = newCommand.split(" ")
	if not commandList.has(command[0]):
		shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], 'Invalid command, type /help for a list of commands')
	elif command[0] == "/help":
		shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Commands: ")
		for item in commandList:
			$messageBox.append_bbcode(item + ": " + commandList[item])
			$messageBox.newline()
	
	elif command[0] == "/credits":
		rpc_id(1, "get_credits", prefs["userName"])

func create_network():
	filePopup.set_item_disabled(3, false)
	editPopup.set_item_disabled(0, true)
	var server : NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	server.create_server(networkInfo["netPort"],MAX_PLAYERS)
	get_tree().set_network_peer(server)
	autosaveNetwork(networkInfo["autosaveInterval"])
	load_localLog()
	sync_messages()
	shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Server hosted on port " + str(port))
	add_connectedList(get_tree().get_network_unique_id(), prefs["userName"])

func connected():
	shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Connection succesful, attempting login...")
	rpc_id(1, "net_login", prefs["userName"], userPass)

func connected_fail():
	print("Failed to connect")
	shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Couldn't connect try again, or host?")

func server_disconnected():
	#Server just closed
	print("server_disconnected")
	shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Server Closed")

remote func add_connectedList(ID, name):
	connectedList[ID] = name
	rpc("update_connectedList", connectedList)
	send_chat(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], name + " connected")

func user_left(ID):
	if connectedList.has(ID): # If client failed to login, skip
		shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], connectedList[ID] + " disconnected")
		connectedList.erase(ID) # remove  from connectedList
		rpc("update_connectedList", connectedList)

func refresh_connectedList():
	$statusBox.clear()
	for i in connectedList:
		$statusBox.add_item(connectedList[i])

remotesync func update_connectedList(new_connectedList):
	connectedList = new_connectedList
	refresh_connectedList()

func shared_message(dateTime, color, name, newText):
	var newMessage = "[b][color=" + color + "]" + name + ": "+"[/color][/b]" + newText + "\n"
	if prefs["dispTimeStamps"] == false:
		$messageBox.append_bbcode(newMessage)
	else:
		$messageBox.append_bbcode(get_formatted_time(dateTime) + newMessage)
	if get_tree().get_network_unique_id() == 1:
		networkInfo["messageLog"].append([dateTime, newMessage])

func local_message(dateTime, color, name, newText):
	var newMessage = "[b][color=" + color + "]" + name + ": "+"[/color][/b]" + newText + "\n"
	if prefs["dispTimeStamps"] == false:
		$messageBox.append_bbcode(newMessage)
	else:
		$messageBox.append_bbcode(get_formatted_time(dateTime) + newMessage)
	localLog.append([get_formatted_time(dateTime), newMessage])
	save_localLog()

func sync_messages(): # Printing shared and local message in order of time stamp
	var totalMessages = len(sharedNetworkInfo["messageLog"]) + len(localLog)
	var localIndex = 0
	var sharedIndex = 0
	print("totalMessages: " + str(totalMessages))
	if len(localLog) == 0: # Check if local log is empty
		for line in sharedNetworkInfo["messageLog"]:
			$messageBox.append_bbcode(line)
	else:
		for i in range(totalMessages):
			if OS.get_unix_time_from_datetime(sharedNetworkInfo["messageLog"][sharedIndex][0])  >= OS.get_unix_time_from_datetime(localLog[localIndex][0]):
				if prefs["dispTimeStamps"] == false:
					$messageBox.append_bbcode(sharedNetworkInfo["messageLog"][sharedIndex][1])
				else:
					$messageBox.append_bbcode(get_formatted_time(sharedNetworkInfo["messageLog"][sharedIndex][0]) + 
					sharedNetworkInfo["messageLog"][sharedIndex][1])
				sharedIndex += 1
			else:
				if prefs["dispTimeStamps"] == false:
					$messageBox.append_bbcode(localLog[localIndex][1])
				else:
					$messageBox.append_bbcode(get_formatted_time(localLog[localIndex][0]) + 
					sharedNetworkInfo["messageLog"][sharedIndex][1])
				localIndex += 1

remotesync func send_chat(curTime, color, name, newText):
	shared_message(curTime, color, name, newText)

func disc(): # Disconnect but dont close
	# If not server host
	if get_tree().get_network_unique_id() != 1:
		get_tree().network_peer = null
		connectedList.clear()
		$statusBox.clear()
		$messageBox.clear()
		filePopup.set_item_disabled(3, true)
		editPopup.set_item_disabled(0, false)
	else:
		get_tree().network_peer = null
		saveTimer.stop()
		save_network()
		connectedList.clear()
		$statusBox.clear()
		$messageBox.clear()
		filePopup.set_item_disabled(3, true)
		editPopup.set_item_disabled(0, false)

func exit():
	# If not server host
	if get_tree().get_network_unique_id() != 1:
		get_tree().network_peer = null
		get_tree().quit()
	
	else:
		get_tree().network_peer = null
		saveTimer.stop()
		save_network()
		connectedList.clear()
		$statusBox.clear()
		$messageBox.clear()
		get_tree().quit()

func save_prefs():
	var file = File.new()
	file.open("user://preferences.dat", File.WRITE)
	file.store_var(prefs)
	file.close()

func load_prefs():
	var file = File.new()
	if not file.file_exists("user://preferences.dat"):
		save_prefs()
	file.open("user://preferences.dat", File.READ)
	prefs = file.get_var()
	file.close()
	
	$userSettingsPopup/usernameInput.text = prefs["userName"]
	$userSettingsPopup/userColor.text = prefs["userColor"]

func create_user_info(userName, password):
	userInfo["userName"] = userName
	userInfo['userPass'] = password
	userInfo["userCredits"] = 100
	return(userInfo)

func checkNetwork(networkName): # Check if save already exists before overwriting
	var file = File.new()
	if file.file_exists(networkInfo["netSavePath"]):
		$overwriteSave/warningLabel.text = "File " + networkName + ".dat already exists. Overwrite?"
		$overwriteSave.visible = true
	else:
		networkInfo["userList"][prefs["userName"]] = create_user_info(prefs["userName"], userPass)
		save_network()
		create_network()

func load_localLog():
	var logPath = prefs["localLogLoc"] + sharedNetworkInfo["networkName"] + ".dat"
	print("loading local log at: " + str(prefs["localLogLoc"]))
	var file = File.new()
	if file.file_exists(logPath):
		file.open(prefs["localLogLoc"], File.READ)
		localLog = file.get_var()
		file.close()
	else:
		file.close()
		save_localLog()

func save_localLog():
	var logPath = prefs["localLogLoc"] + sharedNetworkInfo["networkName"] + ".dat"
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

func autosaveNetwork(interval):
	saveTimer = Timer.new()
	add_child(saveTimer)
	saveTimer.wait_time = interval
	saveTimer.connect("timeout", self, "_autosave_timeout")
	saveTimer.start()

func _autosave_timeout():
	print("autosave network")
	save_network()

remote func net_login(userName, password):
	var senderID = get_tree().get_rpc_sender_id()
	var currentList = connectedList.values()
	print(userName + " connected with pass: " + str(password))
	sharedNetworkInfo["networkName"] = networkInfo["networkName"]
	sharedNetworkInfo["messageLog"] = networkInfo["messageLog"]
	
	if get_tree().get_network_unique_id() == 1: # Checking that only run by server
		if currentList.has(userName): # Checking if username is already connected
			rpc_id(get_tree().get_rpc_sender_id(), "user_already_logged")
		
		elif networkInfo["userList"].has(userName): # Checking if the user has logged in before
			if networkInfo["userList"][userName]["userPass"] == password: # Returning user, checking userPass
				rpc_id(get_tree().get_rpc_sender_id(), "login_success", sharedNetworkInfo)
			else:
				rpc_id(get_tree().get_rpc_sender_id(), "login_fail")
			
		elif password == networkInfo["netPass"]: # First time login, checking network pass
			networkInfo["userList"][userName] = create_user_info(userName, password)
			rpc_id(get_tree().get_rpc_sender_id(), "login_success", sharedNetworkInfo)
		
		else:
			rpc_id(get_tree().get_rpc_sender_id(), "login_fail")

remote func login_success(netInfo):
	sharedNetworkInfo = netInfo
	shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Login succesful")
	rpc_id(1,"add_connectedList", get_tree().get_network_unique_id(), prefs["userName"])
	load_localLog()
	sync_messages()

remote func login_fail():
	shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "Invalid login, disconnected")
	get_tree().network_peer = null

remote func user_already_logged():
	shared_message(OS.get_datetime(), prefs["sysColor"], prefs["sysName"], "User name already in use, connection refused")
	get_tree().network_peer = null

remote func server_message(message):
	shared_message(OS.get_datetime(), "gray", "SERVER", message)

remote func get_credits(userName):
	if networkInfo["userList"].has(userName):
		var creditMessage = userName + "'s credits: '" + str(networkInfo["userList"][userName]["userCredits"])
		rpc_id(get_tree().get_rpc_sender_id(), "server_message", creditMessage)
	else:
		rpc_id(get_tree().get_rpc_sender_id(), "server_message", "Unknown user")

func get_formatted_time(dateTime):
	var formattedTime = str(dateTime["hour"]) + ":" + str(dateTime["minute"]) + ":" + str(dateTime["second"])
	return(formattedTime)
