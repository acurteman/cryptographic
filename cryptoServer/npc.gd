extends Node

var actionTimer
var alias
var aliases = [
	"Guapo","Bootsie","DirtyHarry","Mistress","Dingo","Sunshine","Cotton","BigBird",
	"Pinkie","Elf","Button","Beautiful","Sweetums","Sassafras","Peep","Ghoulie","Azkaban",
	"Dolly","Winnie","MiniMe","Pookie","RedHot","Tootsie","Gordo","Starbuck","Dorito",
	"Gams","Buckeye","Bean","Sherlock","Blimpie","Hubby","MissPiggy","Snickerdoodle","LilMama",
	"Fellow","Goose","Bumpkin","Bubbles","DietSoda","DumDum","GummiBear","Darling","Itchy",
	"Dottie","Lover","HotPepper","Sport","Jackrabbit","Goon","Seigward","BrodoFaggins","Superman",
	"YourMom","xXx_l33tH4x0r_69_xXx","Neo","Trump",""]
var attack
var creditMult
var credits = 100
var doxxed = false
var npcID
var lives = 0
var main
var maxCredits = 100
var maxWait = 30
var minWait = 15
var username
var usernames = [
	"Kasey","Hardy","Mariah","Bingo","Prancer","Wiggles","Paddy","Duffy",
	"Jewels","Snuffles","Oscar","Bobbie","Snowy","Misty","Jack","Mitch","Jolly","Sweetie",
	"Ember","Tinkerbell","Bambi","Budda","Dobie","Taylor","Tucker","Astro","Bob","Nakita",
	"Libby","Kirby","Rambler","Yin", "Elliot","Salty","Ruby","Cookie","Bandit","Linus",
	"Grace","Dickens","Beanie","Bradley","Cali","Skinny","Cooper","Beau","Rexy","Bessie","Pablo","Lucky"]

func _ready():
	# Create reference to main server scene
	main = get_node("/root/main")
	
	# Generate NPC info
	gen_id()
	gen_alias()
	gen_stats()
	gen_username()
	
	# Start action timer
	start_action_timer()

func _action_timeout():
# Called when the action timer goes off. Resets the timer with a new random time,
# and calls the action function to perform a new action
	actionTimer.wait_time = main.rng.randi_range(minWait, maxWait)
	actionTimer.start()
	action()

func action():
# Called by server when it is time for the NPC to make an action
# or when the action timer goes off
	# Selecting a target user
	var targetID = 0
	var targetList = main.connectedList.keys()
	var actionRoll 
	
	# Shuffle the target list, then pick the first element until target is not an NPC
	while targetID <= 0:
		targetList.shuffle()
		targetID = targetList[0]
	
	# Randomly select which action to perform
	actionRoll = main.rng.randi_range(0, 100)
	
	# Select which action to make based on actionRoll
	if actionRoll < 95:
		hackWallet(targetID)
	else:
		stealID(targetID)

func gen_alias():
# Called when the NPC is initialized, generates an alias
	alias = aliases[main.rng.randi_range(0, len(aliases)-1)]
	alias = main.check_alias(alias, npcID)

func gen_id():
# Generates a unique id number for the NPC
	var uniqueID = false
	var newID
	
	# Loop until a unique number is found
	while not uniqueID:
		newID = main.rng.randi_range(-1, -1000)
		
		if main.connectedList.has(newID):
			pass
		else:
			uniqueID = true
	
	npcID = newID

func gen_stats():
# Called when the NPC is initialized, generates the NPC stats and credits
# Stats are generated based on currently connected user stats
	var avgAtt = 0
	var avgCM = 0
	var avgCredits = 0
	
	# Calculating average stats for all connected users, and setting
	# NPC's starting stats to the average, or close enough...
	for userAlias in main.sharedNetworkInfo["connectedUsers"]:
		var userID = main.aliasToID[userAlias]
		var userName = main.connectedList[userID]
		
		# Exclude bots from average stats
		if userID > 0:
			avgAtt += main.userList[userName]["attack"]
			avgCM += main.userList[userName]["creditMult"]
			avgCredits += main.sharedNetworkInfo["userMaxCreds"][userAlias]
	
	attack = avgAtt / main.numUsers
	creditMult = avgCM / main.numUsers
	avgCredits = avgCredits / main.numUsers
	
	# Give the NPC a random amount of credits, between 0 and the current user average
	credits = int(round(main.rng.randi_range(0, avgCredits)))
	
	# Giving the NPC a random amount of lives betweeon 1 and 3
	lives = main.rng.randi_range(1, 3)
	
	# Setting random values for min and max wait time for action timer
	minWait = main.rng.randi_range(10, 20)
	maxWait = main.rng.randi_range(21, 40)

func gen_username():
# Called when the NPC is initialized, generates a username
	var uniqueName = false
	
	# Loop until a unique name is chosen
	while not uniqueName:
		username = usernames[main.rng.randi_range(0, len(usernames)-1)] + "bot" + str(main.rng.randi_range(0,100))
		
		# Check against all player usernames, regardless if connected
		if main.userList.has(username):
			pass
		# Check against all connected players, including bots
		elif main.connectedList.has(username):
			pass
		else:
			uniqueName = true

func hackWallet(targetID):
# NPC version of hackWallet, functions same as player action. Attempts to steal
# credits from target user
	
	print("NPC hacking wallet")
	
	# Check if attack is successful
	if npc_attack_outcome(targetID):
		var defUname = main.connectedList[targetID]
		
		# Determine how much is stolen, random between 5-10%
		var hackPct = main.rng.randf_range(0.05, 0.1)
		var hackAmount = int(round(main.userList[defUname]["currentCredits"] * hackPct))
		
		# Subtract funds and notify defender
		main.hack_loss(targetID, hackAmount)
		
		# Increase credits and check for new credit max
		credits += hackAmount
		if credits > maxCredits:
			maxCredits = credits
			main.sharedNetworkInfo["userMaxCreds"][alias] = maxCredits
			main.rpc("update_sharedNetworkInfo", main.sharedNetworkInfo.duplicate())

func lose_life(userID):
# Called when a user hacks an NPC, which causes the NPC to lose 1 life.
# If an NPC has 0 lives, and has been doxxed, it will "die", leaving the server
# and awarding all its credits to the user who killed it

	if lives > 0:
		lives -= 1
	elif doxxed == true:
		main.npc_killed(userID, credits)
		seppuku()

func npc_attack_outcome(targetID):
# Called when the npc makes an attack on a player
# Functions the same as attack_outcome
# Calculates whether an attack is succesfull based on users attack and defense stats, 
# firewall status, and ddos protection. Returns true if successful, false if you suck 
	var outcome = false
	var defUname = main.connectedList[targetID]
	var def = main.userList[defUname]["defense"]
	
	# Calculate if attack succeeds
	if main.rng.randf_range(0, def + attack) <= attack:
		# Attack success, check for further defenses
		
		# Check ddos level
		if main.userList[defUname]["ddosLevel"] > main.networkInfo["ddosThreshold"]:
			pass
			
		# Check for firewall
		elif main.userList[defUname]["firewallLevel"] > 0:
			main.firewall_breach(targetID)
			
		# Else attack successfull
		else:
			outcome = true
			
			# If defender had active traceRoute
			if main.userList[defUname]["traceRoute"] > 0:
				main.activate_traceRoute(targetID, npcID)
			
			# Increase defenders ddos level
			main.userList[defUname]["ddosLevel"] += 5
	
	#print("NPC attack: " + str(outcome))
	return outcome

func stealID(targetID):
# Called when an NPC attempts to swap aliases with a player
	print("NPC stealing ID")
	
	if npc_attack_outcome(targetID):
		var targetAlias = main.IDtoAlais[targetID]
		var oldAlias = alias
		
		# Briefly changing the defenders alias to ERROR, 
		# to avoid having two users with the same name momentarily
		main.change_alias("ERROR", targetID)
		
		# Swapping user aliases
		main.change_alias(targetAlias, npcID)
		main.change_alias(oldAlias, targetID)

func start_action_timer():
# Starts a new action timer, which will be set for a random time and trigger
# athe NPC to make an action and reset when it goes off
	actionTimer = Timer.new()
	add_child(actionTimer)
	actionTimer.wait_time =  main.rng.randi_range(minWait, maxWait)
	actionTimer.one_shot = true
	actionTimer.connect("timeout", self, "_action_timeout")
	actionTimer.start()

func seppuku():
# Remove node
# Called when the NPC has been doxxed and reduced to 0 lives
	actionTimer.stop()
	main.user_left(npcID)
	queue_free()
