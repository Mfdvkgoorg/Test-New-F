local RunService = game:GetService("RunService")
local Animation = {}
local connections = {}

local function ClearAllAnimations()
	for _, c in ipairs(connections) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(connections)
end

function Animation.Apply(theme, root)
	ClearAllAnimations()

	if not theme or not root or not getgenv().ShineEnabled or not theme.ShineEnabled or not theme.Shine then
		return
	end

	local ShineConfig = theme.Shine
	local Speed = ShineConfig.Speed or 0.5
	local RotationSpeed = ShineConfig.RotationSpeed or 25
	local ColorSequence = ShineConfig.ColorSequence
	
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("UIGradient") then
			local t = 0
			local conn
			conn = RunService.RenderStepped:Connect(function(dt)
				local t = obj:GetAttribute("old_t") or 0
				t += dt * Speed
                obj:SetAttribute("old_t", t)
				
                -- local r = tick() * (theme.RotationSpeed * 0.1 or 0.4)
                -- obj.Offset = Vector2.new(0.5 + math.sin(r) * 0.5, 0.5 + math.cos(r) * 0.5)
					
				obj.Rotation = (t * RotationSpeed) % 360
				obj.Color = ColorSequence
			end)
			table.insert(connections, conn)
		end

		if obj:IsA("UIStroke") then
            local grad = obj:FindFirstChild("BorderEffect")
            if not grad then
                grad = Instance.new("UIGradient")
                grad.Name = "BorderEffect"
                grad.Parent = obj
            end
            
            local darkColor = theme.ElementBorder or Color3.fromRGB(30, 30, 30)
            local shineColor = theme.Accent or Color3.fromRGB(255, 255, 255)
            
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, darkColor),
                ColorSequenceKeypoint.new(0.4, darkColor),
                ColorSequenceKeypoint.new(0.5, shineColor),
                ColorSequenceKeypoint.new(0.6, darkColor),
                ColorSequenceKeypoint.new(1, darkColor)
            })
            
            local conn
            conn = RunService.RenderStepped:Connect(function(dt)
                local rot = grad:GetAttribute("Rot") or 0
                rot = (rot + (dt * (Speed * 300))) % 360
                grad:SetAttribute("Rot", rot)
                grad.Rotation = rot
            end)
            table.insert(connections, conn)
        end
	end
end

return Animation
