--================== SERVICES ==================--
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

--================== MONSTER SETUP ==================--
local monsterModel = script.Parent
local monster = monsterModel:WaitForChild("HumanoidRootPart")
monster.Anchored = true

local humanoid = monsterModel:WaitForChild("Humanoid")

--================== SOUNDS ==================--
local soundHelicopter = monsterModel:WaitForChild("helicopter")


--================== AI CONFIG ==================--
local MAX_HEALTH = 100
local WALK_SPEED = 8
local CHASE_SPEED = 15 
local SIGHT_DISTANCE = 60
local DAMAGE = 5
local ATTACK_COOLDOWN = 1.5
local TURN_SPEED = 0.5
local CHASE_SPIN_SPEED = 15 -- How fast the monster spins while chasing (radians per second)

local AIState = { Patrolling = "Patrolling", Chasing = "Chasing", Turning = "Turning" }
local currentState = AIState.Patrolling
local playerTarget = nil
local attackDebounce = {}
local isTurning = false
local aiConnection = nil
local chaseSpinAngle = 0 -- The current angle of the spin during a chase
local hasSpottedPlayerThisSession = false -- Flag to ensure the spot sound only plays once.

--================== FUNCTIONS ==================--

local function turn()
	if isTurning then return end
	isTurning = true
	local randomAngle = math.rad(math.random(90, 270))
	local goalCFrame = monster.CFrame * CFrame.Angles(0, randomAngle, 0)
	local tween = TweenService:Create(monster, TweenInfo.new(TURN_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = goalCFrame})
	tween:Play()
	tween.Completed:Wait()
	isTurning = false
	currentState = AIState.Patrolling
end

local function mazeMonster(speed, deltaTime)
	if isTurning then return end
	local rayOrigin = monster.Position
	local rayDirection = monster.CFrame.LookVector * (monster.Size.Z / 2 + 2)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {monsterModel}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if result then
		currentState = AIState.Turning
	else
		local moveVector = monster.CFrame.LookVector * speed * deltaTime
		monsterModel:SetPrimaryPartCFrame(monster.CFrame + moveVector)
	end
end

local function chase(deltaTime)
	if isTurning then return end
	if not playerTarget or not playerTarget.Character or not playerTarget.Character:FindFirstChild("HumanoidRootPart") then
		currentState = AIState.Patrolling
		playerTarget = nil
		return
	end
	local targetRoot = playerTarget.Character.HumanoidRootPart
	if (monster.Position - targetRoot.Position).Magnitude > SIGHT_DISTANCE * 1.5 then
		print("Monster lost the player.")
		currentState = AIState.Patrolling
		playerTarget = nil
		return
	end

	local targetPosition = targetRoot.Position

	-- Raycast to check for walls directly in front
	local directionToTarget = (targetPosition - monster.Position).Unit
	local rayOrigin = monster.Position
	local rayDirection = directionToTarget * (monster.Size.Z / 2 + 2)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {monsterModel, playerTarget.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if result then
		-- A wall is in the way, switch to turning to try and get around it
		currentState = AIState.Turning
	else
		-- Path is clear, so move towards the player and spin

		-- 1. Calculate the movement
		local moveVector = directionToTarget * CHASE_SPEED * deltaTime
		local newPosition = monster.Position + moveVector

		-- 2. Calculate the spin
		chaseSpinAngle = chaseSpinAngle + CHASE_SPIN_SPEED * deltaTime
		local spinCFrame = CFrame.Angles(0, chaseSpinAngle, 0)

		-- 3. Combine movement and spin
		local lookAtPosition = Vector3.new(targetPosition.X, newPosition.Y, targetPosition.Z)
		local newCFrame = CFrame.lookAt(newPosition, lookAtPosition) * spinCFrame

		monsterModel:SetPrimaryPartCFrame(newCFrame)
	end
end

local function findTarget()
	local closestPlayer = nil
	local minDistance = SIGHT_DISTANCE
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local rootPart = player.Character.HumanoidRootPart
			local distance = (monster.Position - rootPart.Position).Magnitude
			if distance < minDistance then
				local rayOrigin = monster.Position
				local rayDirection = (rootPart.Position - rayOrigin).Unit * distance
				local raycastParams = RaycastParams.new()
				raycastParams.FilterDescendantsInstances = {monsterModel, player.Character}
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
				if not result then
					minDistance = distance
					closestPlayer = player
				end
			end
		end
	end
	return closestPlayer
end

local function aiLoop(deltaTime)
	local target = findTarget()

	if target then
		if currentState ~= AIState.Chasing then
			if not soundHelicopter.IsPlaying then
				print("Monster has spotted " .. target.Name)
				soundHelicopter:Play()
			end
		end
		currentState = AIState.Chasing
		playerTarget = target
	else
		if currentState == AIState.Chasing then
			print("Monster lost its target.")
			chaseSpinAngle = 0 -- Reset spin angle when patrol resumes
			soundHelicopter:Stop()
		end
		currentState = AIState.Patrolling
		playerTarget = nil
	end

	if currentState == AIState.Patrolling then
		mazeMonster(WALK_SPEED, deltaTime)
	elseif currentState == AIState.Chasing then
		chase(deltaTime)
	elseif currentState == AIState.Turning then
		turn()
	end
end


--================== DAMAGE & DEATH ==================--
monster.Touched:Connect(function(hit)
	-- Find the character model from the part that was hit
	local character = hit.Parent
	-- Find the humanoid within that character
	local humanoidTouched = character:FindFirstChildOfClass("Humanoid")

	-- Check if a humanoid was found and if it's not on cooldown
	if humanoidTouched and not attackDebounce[humanoidTouched] then
		attackDebounce[humanoidTouched] = true
		humanoidTouched:TakeDamage(DAMAGE)
		print("Monster damaged " .. character.Name)
		task.wait(ATTACK_COOLDOWN)
		attackDebounce[humanoidTouched] = nil
	end
end)

humanoid.Died:Connect(function()
	print("Monster has been defeated!")

	if aiConnection then
		aiConnection:Disconnect()
		aiConnection = nil
	end

	-- Make sure to stop all sounds on death
	soundHelicopter:Stop()

	for _, part in ipairs(monsterModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Velocity = Vector3.new(math.random(-20, 20), math.random(20, 40), math.random(-20, 20))
		end
	end

	Debris:AddItem(monsterModel, 5)
end)

--================== INIT ==================--
humanoid.MaxHealth = MAX_HEALTH
humanoid.Health = MAX_HEALTH
humanoid.PlatformStand = true
print("Simple Monster AI Initialized.")
aiConnection = RunService.Heartbeat:Connect(aiLoop)