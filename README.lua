local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remote = ReplicatedStorage.Remotes:WaitForChild("M1")

local CamShake = ReplicatedStorage.Remotes.CameraEffect.Shake


local Ragdoll = require(ReplicatedStorage.Modules:WaitForChild("Ragdoll"))
local StunModule = require(ReplicatedStorage.Modules:WaitForChild("StunModule"))
local VoxBreaker = require(ReplicatedStorage.Modules:WaitForChild("VoxBreaker"))
local Knockback = require(ReplicatedStorage.Modules:WaitForChild("Knockback"))
local Killer = require(ReplicatedStorage.Modules:WaitForChild("KillRegister"))
local Awk = require(ReplicatedStorage.Modules:WaitForChild("GiveAwk"))
local Iframes = require(ReplicatedStorage.Modules:WaitForChild("Iframes"))
local Pax = require(ReplicatedStorage.Modules:WaitForChild("Parts"))
local Grab = require(ReplicatedStorage.Modules:WaitForChild("Grab"))
local Cast = require(ReplicatedStorage.Modules:WaitForChild("Cast"))
local GetUp = require(ReplicatedStorage.Modules.MainModule:WaitForChild("GetUp"))
local reaction = require(ReplicatedStorage.Modules:WaitForChild("Reaction"))

local Impact = require(script:WaitForChild("Impact"))
local Glow = require(script:WaitForChild("Glow"))
local After = require(script:WaitForChild("AfterImage"))
local M1Trail = require(script:WaitForChild("M1Trail"))
local Shock = require(script:WaitForChild("Shock"))
local Shock1 = require(script:WaitForChild("Shock1"))
local CombatAssets = require(script:WaitForChild("Animation"))


local DAMAGE = 4
local SPECIAL_DAMAGE = 6
local HITBOX_SIZE = Vector3.new(5, 12, 5)

local reactionAnimObj = ReplicatedStorage.Animations:WaitForChild("HitReaction")
local uppercutAnimObj = ReplicatedStorage.Animations:WaitForChild("Upper")
local downslamAnimObj = ReplicatedStorage.Animations:WaitForChild("DownSlam")


local function PlayAnimation(character, animObj)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local track = animator:LoadAnimation(animObj)
	track:Play()

	track.Stopped:Connect(function()
		track:Destroy()
	end)

	return track
end


local function PlayReactionAnimation(enemyHumanoid)
	local animator = enemyHumanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local track = animator:LoadAnimation(reactionAnimObj)
	track:Play()

	track.Stopped:Connect(function()
		track:Destroy()
	end)
end


remote.OnServerEvent:Connect(function(player, comboStep, attackType)

	local character = player.Character
	if not character then
		print("FAIL char")
		return
	end

	if character:GetAttribute("DashLocked")
		or character:GetAttribute("SkillLocked")
		or character:GetAttribute("BlockActive")
		or character:GetAttribute("M1Active") then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		
		return
	end

	StunModule.Apply(character, 0.2)
	M1Trail.Start(character, comboStep, attackType)
	CamShake:FireClient(player, 0.5)

	local punchAnims = CombatAssets.GetPunchAnims(character)

	local animTrack

	if attackType == "Uppercut" then
		animTrack = PlayAnimation(character, uppercutAnimObj)

	elseif attackType == "Downslam" then
		animTrack = PlayAnimation(character, downslamAnimObj)

	else
		local index = math.clamp(comboStep, 1, #punchAnims)
		animTrack = PlayAnimation(character, punchAnims[index])
	end


	local hitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, -2)
	
	if comboStep == 4 then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then

			local forward = root.CFrame.LookVector * 2
			local cf = CFrame.new(root.Position + Vector3.new(0, 1.5, 0) + forward)

			local voxels = VoxBreaker:CreateHitbox(
				Vector3.new(8, 8, 10), 
				cf,
				Enum.PartType.Block,
				2,
				30
			)

			for _, v in ipairs(voxels) do
				v.Anchored = false
				v.AssemblyLinearVelocity = Vector3.new(
					math.random(-35, 35),
					math.random(20, 45),
					math.random(-35, 35)
				)
			end
		end
	end

	local params = OverlapParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local parts = Workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, params)

	local hitHumanoids = {}

	for _, part in ipairs(parts) do
		local enemyChar = part.Parent
		local enemyHumanoid = enemyChar and enemyChar:FindFirstChild("Humanoid")
		local enemyRoot = enemyChar and enemyChar:FindFirstChild("HumanoidRootPart")

		if enemyHumanoid and enemyRoot and not hitHumanoids[enemyHumanoid] then

			if enemyChar:GetAttribute("Iframes") == true then
				continue
			end

			local isBlocking = enemyChar:GetAttribute("BlockActive") == true
			local isSpecial = (attackType == "Uppercut" or attackType == "Downslam")

			if isBlocking then
				if not isSpecial then
					local enemyLook = enemyRoot.CFrame.LookVector
					local directionToAttacker = (character.HumanoidRootPart.Position - enemyRoot.Position).Unit
					local dot = enemyLook:Dot(directionToAttacker)

					if dot > 0 then
						reaction.Start(enemyChar, 1)
						continue
					end
				end
			end

			hitHumanoids[enemyHumanoid] = true
			enemyHumanoid:SetAttribute("LastAttacker", player.UserId)

			local hitCount = character:GetAttribute("ComboStep") or 4
			hitCount += 1

			if hitCount > 4 then
				PlayReactionAnimation(enemyHumanoid)
				hitCount = 1
			end

			character:SetAttribute("ComboStep", hitCount)
			PlayReactionAnimation(enemyHumanoid)
			After.Start(enemyChar) 
			Cast.Cancel(enemyChar)
			


			if attackType == "Uppercut" then
				enemyHumanoid:TakeDamage(SPECIAL_DAMAGE)
				print("WORK upper fx")
				Knockback.Apply(enemyChar, Vector3.new(0,1,0), 30, 0.3)
				Ragdoll.Start(enemyChar, 0.8)
				Glow.Start(enemyChar)
				StunModule.Apply(enemyChar, 0.8)
				Iframes.Enable(enemyChar, 0.5)
				Shock1.Play(enemyChar, 1, 0, 0)
				task.delay(0.8, function()
					GetUp.SafeGetUp(enemyChar)
				end)
				
				
				
				local attacking = true

			elseif attackType == "Downslam" then
				local character = player.Character
				if not character then return end

				local root = character:FindFirstChild("HumanoidRootPart")
				if not root then return end

				local target
				local closestDist = 10

				for _, obj in pairs(workspace:GetDescendants()) do
					if obj:IsA("Model") and obj ~= character then
						local hum = obj:FindFirstChildOfClass("Humanoid")
						local hrp = obj:FindFirstChild("HumanoidRootPart")

						if hum and hrp and hum.Health > 0 then
							local dist = (hrp.Position - root.Position).Magnitude
							if dist < closestDist then
								closestDist = dist
								target = obj
							end
						end
					end
				end

				if target then
					local tRoot = target:FindFirstChild("HumanoidRootPart")
					local tHum = target:FindFirstChildOfClass("Humanoid")

					if tRoot and tHum then

						local attacking = true

						while attacking do
							if not root or not tRoot then break end
							if tHum.Health <= 0 then break end

							local dir = (tRoot.Position - root.Position)
							local dist = dir.Magnitude

							if dist <= 3 then
								attacking = false
								break
							end

							root.Velocity = dir.Unit * 90
							task.wait()
						end

						root.Velocity = Vector3.zero

						enemyChar = target
						enemyHumanoid = tHum
					end
				end

				if enemyHumanoid then
					enemyHumanoid:TakeDamage(SPECIAL_DAMAGE)
				end

				CamShake:FireClient(player, 2)
				Knockback.Apply(enemyChar, Vector3.new(0,-1,0), 50, 0.1)
				Ragdoll.Start(enemyChar, 2)
				Glow.Start(enemyChar)
				StunModule.Apply(enemyChar, 2)
				Iframes.Enable(enemyChar, 0.5)
				Shock1.Play(enemyChar, 1, 0, 0)

				local hrp = enemyChar:FindFirstChild("HumanoidRootPart")

				if hrp then
					Pax.Spawn({
						Count = 15,
						Origin = hrp.Position - Vector3.new(0, 3, 0),
						Speed = 15,
						LifeTime = 5,
						Spread = Vector3.new(12, 2, 12),
						Size = Vector3.new(1, 1, 1),
						Parent = workspace
					})
				end

				task.delay(2, function()
					GetUp.SafeGetUp(enemyChar)
				end)

				
			

			elseif comboStep == 4 then
				local cf = CFrame.new(rootPart.Position.X, rootPart.Position.Y - 4, rootPart.Position.Z)

				local voxels = VoxBreaker:CreateHitbox(Vector3.new(4, 4.9, 4.7), cf, Enum.PartType.Block, 2, 30)

				for _, v in ipairs(voxels) do
					v.Anchored = false
					v.AssemblyLinearVelocity = Vector3.new(
						math.random(-25, 25),
						math.random(15, 35),
						math.random(-25, 25)
					)
				end
				Impact.Start(enemyChar)

				local root = character:FindFirstChild("HumanoidRootPart")
				if not root then return end

				local direction = root.CFrame.LookVector

				local isReversal = character:GetAttribute("IsReversal")

				local chance

				if isReversal then
					chance = 0 
				else
					chance = math.random(1,100)
				end


				if character:GetAttribute("Character") == "Wesker" then


					Grab.Grab(character, enemyChar, "Left Arm", "Head")
					Ragdoll.Start(enemyChar, 0.3)
					CamShake:FireClient(player, 3)

					task.delay(0.3, function()

						Grab.Release(enemyChar)


						if chance <= 3 then
							StunModule.Apply(enemyChar, 1)
							Iframes.Enable(enemyChar, 0.5)

							enemyHumanoid:TakeDamage(DAMAGE * 1.5)
						else
							Knockback.Apply(enemyChar, direction, 45, 0.3)
							Ragdoll.Start(enemyChar, 1)

							StunModule.Apply(enemyChar, 1)
							Iframes.Enable(enemyChar, 0.7)

							enemyHumanoid:TakeDamage(DAMAGE)
							task.delay(0.3, function()
								GetUp.SafeGetUp(enemyChar)
							end)
							
						end
					end)

				else
				
					if chance <= 3 then
						StunModule.Apply(enemyChar, 1)
						Iframes.Enable(enemyChar, 0.5)

						enemyHumanoid:TakeDamage(DAMAGE * 1.5)
					else
						Knockback.Apply(enemyChar, direction, 45, 0.3)
						Ragdoll.Start(enemyChar, 1)

						StunModule.Apply(enemyChar, 1)
						Iframes.Enable(enemyChar, 0.7)

						enemyHumanoid:TakeDamage(DAMAGE)
							local hitbox = VoxBreaker.CreateMoveableHitbox(
								5,
								10,
								Vector3.new(6, 6, 6),
								enemyRoot.CFrame,
								Enum.PartType.Block
							)
							hitbox:Start()
							hitbox:WeldTo(enemyRoot)

							hitbox.Touched:Connect(function()
								local cf = enemyRoot.CFrame

								local voxels = VoxBreaker:CreateHitbox(
									Vector3.new(3, 3, 3), 
									cf,
									Enum.PartType.Block,
									2,
									15
								)
								for _, v in ipairs(voxels) do
									v.Anchored = false
									v.AssemblyLinearVelocity = Vector3.new(
										math.random(-15, 15),
										math.random(10, 25),
										math.random(-15, 15)
									)
								end
							end)

							task.delay(1, function()
								hitbox:Stop()
								hitbox:Destroy()
								GetUp.SafeGetUp(enemyChar)
							end)
					end
				end

			else
			    enemyHumanoid:TakeDamage(DAMAGE)
				Awk.GiveUlt(player,1)
				StunModule.Apply(enemyChar,1)
				if character:GetAttribute("Character") == "Wesker" then
					local root = character:FindFirstChild("HumanoidRootPart")
					if root then
						local forwardOffset = root.CFrame.LookVector * 3
						Shock.Play(character, 1, 0, forwardOffset)
					end
				end
			end
		end
	end
end)
