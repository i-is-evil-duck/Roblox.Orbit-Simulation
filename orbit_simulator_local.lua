-- Solar System Orbit Simulator for Roblox
-- Put this in StarterPlayerScripts as a LocalScript

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local timeSpeed = 1
local paused = false

local AU_IN_KM = 149597870.7
local SCALE_POWER = 0.5
local SCALE_FACTOR = 10
local MOON_SCALE = 3.0

local function getScaledDistance(a, e, theta)
	local r = a * (1 - e^2) / (1 + e * math.cos(theta))
	return r ^ SCALE_POWER * SCALE_FACTOR
end

local function solveKepler(M, e)
	local E = M
	for i = 1, 100 do
		local dE = (M - E + e * math.sin(E)) / (1 - e * math.cos(E))
		E = E + dE
		if math.abs(dE) < 1e-6 then break end
	end
	return E
end

local function trueAnomalyFromMean(M, e)
	local E = solveKepler(M, e)
	return 2 * math.atan(math.sqrt(1 + e) * math.sin(E / 2) / (math.sqrt(1 - e) * math.cos(E / 2)))
end

local sun = Instance.new("Part")
sun.Name = "Sun"
sun.Shape = Enum.PartType.Ball
sun.Size = Vector3.new(4, 4, 4)
sun.Anchored = true
sun.CanCollide = false
sun.Position = Vector3.new(0, 0, 0)
sun.Color = Color3.new(1, 0.85, 0)
sun.Material = Enum.Material.Neon
sun.Parent = workspace

local sunLight = Instance.new("PointLight")
sunLight.Name = "SunLight"
sunLight.Color = Color3.new(1, 0.95, 0.8)
sunLight.Range = 150
sunLight.Brightness = 2
sunLight.Parent = sun

local planetsData = {
	{name = "Mercury", color = Color3.new(0.5, 0.5, 0.5), size = 0.5, a = 0.387, e = 0.206, period = 87.97, meanAnomaly = 174.8, axialTilt = 0.03, rotationPeriod = 58.6, inclination = 7.0},
	{name = "Venus", color = Color3.new(1, 0.6, 0.2), size = 0.9, a = 0.723, e = 0.007, period = 224.7, meanAnomaly = 50.1, axialTilt = 177.4, rotationPeriod = -243, inclination = 3.4},
	{name = "Earth", color = Color3.new(0.2, 0.5, 1), size = 1.0, a = 1.0, e = 0.017, period = 365.25, meanAnomaly = 358.6, axialTilt = 23.4, rotationPeriod = 1, inclination = 0},
	{name = "Mars", color = Color3.new(1, 0.3, 0.1), size = 0.7, a = 1.524, e = 0.093, period = 687, meanAnomaly = 19.4, axialTilt = 25.2, rotationPeriod = 1.03, inclination = 1.85},
	{name = "Jupiter", color = Color3.new(1, 0.65, 0), size = 2.8, a = 3.2, e = 0.049, period = 4333, meanAnomaly = 20.0, axialTilt = 3.1, rotationPeriod = 0.41, inclination = 1.3},
	{name = "Saturn", color = Color3.new(1, 0.9, 0.4), size = 2.4, a = 4.5, e = 0.057, period = 10759, meanAnomaly = 317.0, axialTilt = 26.7, rotationPeriod = 0.45, inclination = 2.49, rings = true},
	{name = "Uranus", color = Color3.new(0.4, 0.9, 0.9), size = 1.8, a = 6.5, e = 0.046, period = 30687, meanAnomaly = 96.9, axialTilt = 97.8, rotationPeriod = -0.72, inclination = 0.77},
	{name = "Neptune", color = Color3.new(0.2, 0.2, 0.8), size = 1.7, a = 8.0, e = 0.010, period = 60190, meanAnomaly = 273.2, axialTilt = 28.3, rotationPeriod = 0.67, inclination = 1.77},
}

local moonsData = {
	{name = "Moon", color = Color3.new(0.9, 0.9, 0.9), size = 0.3, a = 384400, e = 0.055, period = 27.3, meanAnomaly = 51.6, parent = "Earth", rotationPeriod = 27.3, inclination = 5.1},
	{name = "Io", color = Color3.new(1, 0.9, 0.3), size = 0.15, a = 421700, e = 0.004, period = 1.77, meanAnomaly = 257.8, parent = "Jupiter", rotationPeriod = 1.77, inclination = 0.04},
	{name = "Europa", color = Color3.new(0.8, 0.85, 0.95), size = 0.13, a = 671034, e = 0.009, period = 3.55, meanAnomaly = 128.3, parent = "Jupiter", rotationPeriod = 3.55, inclination = 0.47},
	{name = "Ganymede", color = Color3.new(0.6, 0.6, 0.6), size = 0.22, a = 1070412, e = 0.001, period = 7.15, meanAnomaly = 0.8, parent = "Jupiter", rotationPeriod = 7.15, inclination = 0.18},
	{name = "Callisto", color = Color3.new(0.4, 0.4, 0.45), size = 0.2, a = 1882709, e = 0.007, period = 16.69, meanAnomaly = 24.3, parent = "Jupiter", rotationPeriod = 16.69, inclination = 0.19},
	{name = "Titan", color = Color3.new(1, 0.8, 0.4), size = 0.22, a = 1221870, e = 0.029, period = 15.95, meanAnomaly = 194.8, parent = "Saturn", rotationPeriod = 15.95, inclination = 0.33},
}

local planets = {}
local moons = {}
local rings = {}

for _, data in ipairs(planetsData) do
	local planet = Instance.new("Part")
	planet.Name = data.name
	planet.Shape = Enum.PartType.Ball
	planet.Size = Vector3.new(data.size, data.size, data.size)
	planet.Anchored = true
	planet.CanCollide = false
	planet.Material = Enum.Material.SmoothPlastic
	planet.Color = data.color
	planet.Transparency = 0
	planet.Parent = workspace

	local theta = trueAnomalyFromMean(math.rad(data.meanAnomaly), data.e)
	local r = getScaledDistance(data.a, data.e, theta)
	local inclination = math.rad(data.inclination)
	local x = r * math.cos(theta)
	local z = r * math.sin(theta)
	local y = r * math.sin(inclination) * math.sin(theta)
	planet.Position = Vector3.new(x, y, z)

	local axisLine = Instance.new("Part")
	axisLine.Name = data.name .. "Axis"
	axisLine.Shape = Enum.PartType.Cylinder
	axisLine.Size = Vector3.new(data.size * 0.05, data.size * 6, data.size * 0.05)
	axisLine.Anchored = true
	axisLine.CanCollide = false
	axisLine.Material = Enum.Material.SmoothPlastic
	axisLine.Color = Color3.new(1, 1, 1)
	axisLine.Transparency = 0.5
	axisLine.Parent = workspace

	if data.rings then
		local ring = Instance.new("Part")
		ring.Name = data.name .. "Ring"
		ring.Shape = Enum.PartType.Block
		ring.Size = Vector3.new(data.size * 4, 0.01, data.size * 4)
		ring.Anchored = true
		ring.CanCollide = false
		ring.CFrame = CFrame.new(x, y, z)
		ring.Transparency = 0
		ring.Material = Enum.Material.SmoothPlastic
		ring.Parent = workspace
		rings[data.name] = ring
	end

	local labelGui = Instance.new("BillboardGui")
	labelGui.Size = UDim2.new(0, 100, 0, 30)
	labelGui.StudsOffset = Vector3.new(0, data.size + 0.5, 0)
	labelGui.Adornee = planet
	labelGui.Parent = planet

	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.new(1, 0, 1, 0)
	labelText.BackgroundTransparency = 1
	labelText.Text = data.name
	labelText.TextColor3 = Color3.new(1, 1, 1)
	labelText.TextScaled = true
	labelText.Font = Enum.Font.SourceSansBold
	labelText.Parent = labelGui

	table.insert(planets, {
		entity = planet,
		data = data,
		theta = theta,
		rotationAngle = 0,
		axialTilt = math.rad(data.axialTilt),
		ring = rings[data.name],
		axisLine = axisLine
	})
end

for _, moonData in ipairs(moonsData) do
	local parentPlanet = nil
	for _, p in ipairs(planets) do
		if p.data.name == moonData.parent then
			parentPlanet = p
			break
		end
	end

	if parentPlanet then
		local moon = Instance.new("Part")
		moon.Name = moonData.name
		moon.Shape = Enum.PartType.Ball
		moon.Size = Vector3.new(moonData.size, moonData.size, moonData.size)
		moon.Anchored = true
		moon.CanCollide = false
		moon.Material = Enum.Material.SmoothPlastic
		moon.Color = moonData.color
		moon.Transparency = 0
		moon.Parent = workspace

		local moonA = moonData.a / AU_IN_KM
		local theta = trueAnomalyFromMean(math.rad(moonData.meanAnomaly), moonData.e)
		local r = getScaledDistance(moonA, moonData.e, theta) * MOON_SCALE
		local x = r * math.cos(theta)
		local z = r * math.sin(theta)
		moon.Position = parentPlanet.entity.Position + Vector3.new(x, 0, z)

		local labelGui = Instance.new("BillboardGui")
		labelGui.Size = UDim2.new(0, 80, 0, 24)
		labelGui.StudsOffset = Vector3.new(0, moonData.size + 0.3, 0)
		labelGui.Adornee = moon
		labelGui.Parent = moon

		local labelText = Instance.new("TextLabel")
		labelText.Size = UDim2.new(1, 0, 1, 0)
		labelText.BackgroundTransparency = 1
		labelText.Text = moonData.name
		labelText.TextColor3 = Color3.new(0.8, 0.8, 0.8)
		labelText.TextScaled = true
		labelText.Font = Enum.Font.SourceSans
		labelText.Parent = labelGui

		table.insert(moons, {
			entity = moon,
			data = moonData,
			parent = parentPlanet,
			theta = theta,
			moonA = moonA
		})
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SolarSystemUI"
screenGui.Parent = playerGui

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 100, 0, 30)
fpsLabel.Position = UDim2.new(0, 10, 0, 10)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS: 60"
fpsLabel.TextColor3 = Color3.new(1, 1, 1)
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Font = Enum.Font.SourceSansBold
fpsLabel.TextSize = 20
fpsLabel.Parent = screenGui

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0, 200, 0, 30)
speedLabel.Position = UDim2.new(0, 10, 0, 40)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed: 0.5x"
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Font = Enum.Font.SourceSansBold
speedLabel.TextSize = 24
speedLabel.Parent = screenGui

local controlsLabel = Instance.new("TextLabel")
controlsLabel.Size = UDim2.new(0, 500, 0, 30)
controlsLabel.Position = UDim2.new(0.5, -250, 0, 10)
controlsLabel.BackgroundTransparency = 1
controlsLabel.Text = "Controls: Mouse drag rotate | Scroll zoom | +/- speed | Space pause"
controlsLabel.TextColor3 = Color3.new(0.6, 0.6, 0.6)
controlsLabel.TextScaled = true
controlsLabel.Font = Enum.Font.SourceSans
controlsLabel.Parent = screenGui

-- Keyboard controls for speed
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode.Name
		if key == "Equals" or key == "Plus" then
			timeSpeed = math.min(timeSpeed * 1.5, 5000)
		elseif key == "Minus" then
			timeSpeed = math.max(timeSpeed / 1.5, 1)
		elseif key == "Space" then
			paused = not paused
		end
	end
end)

local lastTime = tick()
local frameCount = 0
local fps = 60

RunService.Heartbeat:Connect(function(deltaTime)
	frameCount = frameCount + 1
	if tick() - lastTime >= 1 then
		fps = frameCount
		frameCount = 0
		lastTime = tick()
		fpsLabel.Text = "FPS: " .. fps
	end

	speedLabel.Text = "Speed: " .. string.format("%.1f", timeSpeed) .. "x" .. (paused and " (PAUSED)" or "")

	if paused then return end

	local dt = timeSpeed * 0.001

	for _, p in ipairs(planets) do
		local data = p.data
		p.theta = p.theta + (2 * math.pi / data.period) * dt

		local r = getScaledDistance(data.a, data.e, p.theta)
		local x = r * math.cos(p.theta)
		local z = r * math.sin(p.theta)
		local y = r * math.sin(p.axialTilt) * math.sin(p.theta)

		p.entity.Position = Vector3.new(x, y, z)

		p.rotationAngle = p.rotationAngle + (360 / data.rotationPeriod) * dt
		p.entity.CFrame = CFrame.new(Vector3.new(x, y, z)) * CFrame.Angles(p.axialTilt, math.rad(p.rotationAngle), 0)

		if p.axisLine then
			p.axisLine.CFrame = CFrame.new(x, y, z) * CFrame.Angles(p.axialTilt, math.rad(p.rotationAngle), 0)
		end

		if p.ring then
			p.ring.CFrame = CFrame.new(x, y, z) * CFrame.Angles(p.axialTilt, math.rad(p.rotationAngle), 0)
		end
	end

	for _, m in ipairs(moons) do
		local data = m.data
		m.theta = m.theta + (2 * math.pi / data.period) * dt * 30

		local r = getScaledDistance(m.moonA, data.e, m.theta) * MOON_SCALE
		local x = r * math.cos(m.theta)
		local z = r * math.sin(m.theta)
		local inclination = math.rad(data.inclination or 0)
		local y = r * math.sin(inclination) * math.sin(m.theta)

		m.entity.Position = m.parent.entity.Position + Vector3.new(x, y, z)
	end
end)

print("Solar System Simulator loaded!")
